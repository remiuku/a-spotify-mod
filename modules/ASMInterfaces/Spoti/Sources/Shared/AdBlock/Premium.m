// Spoof Premium: the UCS response, which carries the account's product state and its remote
// config, rewritten as it arrives. The attributes and the flag rules are EeveeSpotify's. Offline,
// audio quality and the social session attributes are left alone: the server still decides those,
// and a spoofed one only shows UI the request behind it will fail.
//
// UcsResponse: 1 ResolveResponse { 1 ResolveConfiguration { 3 repeated AssignedValue } },
//   3 AccountAttributesResponse { 1 repeated entry { 1 key, 2 AccountAttribute { 2 bool, 4 string } } }
// AssignedValue: 1 { 1 scope, 2 name }, 3 BoolValue { 1 }, 4 IntValue { 1 }, 5 EnumValue { 1 }
// A customize body is CustomizeMessage { 1 UcsResponse }; bootstrap wraps that in 2 { 1 { 1 { it } } }.
#import "Core/ASMSpotiCore.h"
#import "AdBlock.h"
#import "Protobuf.h"

#pragma mark - account attributes

// A string goes in as one, a number as a bool.
static NSDictionary<NSString *, id> *forcedAttributes(void) {
    NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
    iso.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSString *yearOn = [iso stringFromDate:[NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitYear value:1 toDate:NSDate.date options:0]];
    return @{
        @"ads": @NO,
        @"ab-ad-player-targeting": @"0",
        @"allow-advertising-id-transmission": @NO,
        @"restrict-advertising-id-transmission": @YES,
        @"can_use_superbird": @YES,
        @"enable-crossfade-product-state": @"1",
        @"enable-gapless-product-state": @"1",
        @"catalogue": @"premium",
        @"financial-product": @"pr:premium,tc:0",
        @"is-eligible-premium-unboxing": @YES,
        @"name": @"Spotify Premium",
        @"nft-disabled": @"1",
        @"on-demand": @YES,
        @"payments-initial-campaign": @"default",
        @"player-license": @"premium",
        @"player-license-v2": @"premium",
        @"product-expiry": yearOn,
        @"shuffle-eligible": @YES,
        @"streaming-rules": @"",
        @"subscription-enddate": yearOn,
        @"type": @"premium",
        @"unrestricted": @YES,
        @"high-bitrate": @YES,
        @"loudness-levels": @"1:-5.0,0.0,3.0:-2.0",
        @"pick-and-shuffle": @NO,
        @"mixing-tools": @"EDIT",
        @"your-library-tags": @YES,
        @"libspotify": @YES,
        @"mobile": @YES,
    };
}

// Attributes that would have the client validate the state against the server, or offer a trial.
static NSString *const strippedAttributes[] = {
    @"payment-state", @"last-premium-activation-date", @"on-demand-trial", @"on-demand-trial-in-progress",
    @"smart-shuffle", @"at-signal", @"feature-set-id-masked", @"strider-key", @"is-eligible-for-trial",
    @"is-eligible-for-upsell", @"upsell-state", @"ad-session-persistence", @"ad-formats-preroll-video",
};

static BOOL stripped(NSString *key) {
    if ([key hasPrefix:@"is-premium-eligible"]) return YES;
    for (size_t i = 0; i < sizeof(strippedAttributes) / sizeof(strippedAttributes[0]); i++) {
        if ([key isEqualToString:strippedAttributes[i]]) return YES;
    }
    return NO;
}

static ASMSpotiPBField *attributeEntry(NSString *key, id value) {
    ASMSpotiPBField *attribute = [value isKindOfClass:NSString.class] ? ASMSpotiPBString(4, value) : ASMSpotiPBVarint(2, [value boolValue]);
    return ASMSpotiPBBytes(1, ASMSpotiPBSerialize(@[ASMSpotiPBString(1, key), ASMSpotiPBBytes(2, ASMSpotiPBSerialize(@[attribute]))]));
}

static NSData *patchAttributes(NSData *response) {
    NSMutableArray<ASMSpotiPBField *> *fields = ASMSpotiPBParse(response);
    if (!fields) return nil;
    NSDictionary<NSString *, id> *forced = forcedAttributes();
    NSMutableArray<ASMSpotiPBField *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (ASMSpotiPBField *field in fields) {
        NSString *key = field.number == 1 && field.wire == 2 ? ASMSpotiPBText(ASMSpotiPBFirst(ASMSpotiPBParse(field.payload), 1)) : nil;
        if (!key || (!forced[key] && !stripped(key))) {
            [out addObject:field];
            continue;
        }
        if (!forced[key]) continue;
        [seen addObject:key];
        [out addObject:attributeEntry(key, forced[key])];
    }
    for (NSString *key in forced) {
        if (![seen containsObject:key]) [out addObject:attributeEntry(key, forced[key])];
    }
    return ASMSpotiPBSerialize(out);
}

#pragma mark - remote config

typedef NS_ENUM(NSInteger, ASMSpotiRuleKind) { ASMSpotiRuleRemove, ASMSpotiRuleSet, ASMSpotiRuleForce, ASMSpotiRuleEnum };
// A NULL scope or name matches any. Set changes a value that is there, Force adds it when it is not.
typedef struct { const char *scope, *name; ASMSpotiRuleKind kind; BOOL on; const char *text; } ASMSpotiRule;

static const ASMSpotiRule rules[] = {
    // The ios-feature-settings flags only draw the rows; the player core gates each on its own scope.
    {"ios-feature-settings", "crossfade_enabled", ASMSpotiRuleForce, YES, NULL},
    {"ios-feature-settings", "automix_enabled", ASMSpotiRuleForce, YES, NULL},
    {"core-playback-setup", "crossfade_enabled", ASMSpotiRuleForce, YES, NULL},
    {"core-automix", "automix_enabled", ASMSpotiRuleForce, YES, NULL},
    {"ios-feature-settings", "use_playback_settings_crossfade", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-settings", "use_playback_settings_gapless", ASMSpotiRuleForce, NO, NULL},
    {NULL, "enable_common_capping", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_pns_common_capping", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_pick_and_shuffle_common_capping", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_pick_and_shuffle_dynamic_cap", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "pick_and_shuffle_timecap", ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-queue", NULL, ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_free_on_demand_experiment", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_free_on_demand_context_menu_experiment", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_mft_plus_queue", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_mft_plus_extended_queue", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_playback_timeout_service", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playback_timeout_error_ui", ASMSpotiRuleSet, NO, NULL},
    {NULL, "playback_timeout_action", ASMSpotiRuleEnum, NO, "Nothing"},
    {NULL, "is_remove_from_queue_enabled_for_mft_plus", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "is_reordering_for_mft_plus_allowed", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "ad_metadata", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "ad_slots", ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audio_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_display_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_premium_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_premium_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_campaigns", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_promotions", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_upsell", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "is_enabled_pt2", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "linear_upsell_new_style_experiment_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "play_modes_upsell_new_style_experiment_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-jam-freeusershuffleupsellsheetpage-impl", "free_user_shuffle_upsell_sheet_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-jam-freeuserskipupsellpage-impl", "free_user_skip_upsell_sheet_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-jam-freehostedjamsupsell-impl", "free_hosted_jams_upsell_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-reinventfree-contextualupsellpremiumpromo-impl", "is_promo_cta_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-reinventfree-contextualupsellpremiumpromo-impl", "show_time_cap_upsell_with_premium_badge", ASMSpotiRuleForce, NO, NULL},
    {"ios-reinventfree-controllerui-impl", "enable_video_time_cap_upsell", ASMSpotiRuleForce, NO, NULL},
    {"ios-reinventfree-controllerui-impl", "enable_video_time_cap_upsell_on_search", ASMSpotiRuleForce, NO, NULL},
    {"ios-reinventfree-timecappivot-impl", "music_video_upsell_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-settings-mediaqualitypageplugin-impl", "is_gbb_upsell_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-settings-mediaqualitypageplugin-impl", "should_show_pigeon_upsell", ASMSpotiRuleForce, NO, NULL},
    {"ios-system-listeningparties", "preview_ended_upsell_enabled", ASMSpotiRuleForce, NO, NULL},
    {NULL, "enable_now_playing_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_now_playing_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_artist_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_playlist_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_album_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_library_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audiobook_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_banner_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_banner_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_podcast_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_content", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlists", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_sessions", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_stories", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_videos", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artists", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_albums", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_track", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_tracks", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_show", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_shows", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_episode", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_episodes", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobooks", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcasts", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_results", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_banner", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_banners", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_sponsored_ad", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_sponsored_ads", ASMSpotiRuleSet, NO, NULL},
    {"ios-ad-on-app-open", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-adonappopen", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-adonappopen", "enabled", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adonappopen", "background_refresh_frequency_seconds", ASMSpotiRuleSet, NO, NULL},
    {NULL, "is_ad_on_app_open_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "ad_on_app_open_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "adonappopen_enabled", ASMSpotiRuleSet, NO, NULL},
    {"marquee", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-marquee", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"leavebehindadsbase", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-leavebehindadsbase", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-nowplaying-scroll-impl", "unified_leavebehind_npv_scroll_music_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-nowplaying-scroll-impl", "unified_leavebehind_npv_scroll_podcast_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-embeddedplaylist", "use_unified_leavebehind_fetch", ASMSpotiRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "foreground_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "music_track_change_enabled", ASMSpotiRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "enable_ads_on_podcast", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-instreamads", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-adsembedded-embeddedctaelements-impl", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-adsplatform-elementimpl", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-system-adssponsoredcontext", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-adsbase", "enable_ads_connect_state_observer", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adsbase", "enable_minimal_preroll_management", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adsbase", "enable_swift_ads_base_movement_logger", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adsswift", NULL, ASMSpotiRuleRemove, NO, NULL},
    {"ios-feature-adsnowplayingui", "embedded_npv_video_show_with_canvas", ASMSpotiRuleForce, NO, NULL},
    {"ios-feature-adssponsoredcontext", "sponsored_context_mismatch_aderror_enabled", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adssponsoredcontext", "sponsored_playlist_v2_enabled", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adssponsoredcontextnpbattachment", "sponsored_npb_slot_fetch_enabled", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-adsidentitytracking", NULL, ASMSpotiRuleRemove, NO, NULL},
    {NULL, "enable_popups", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_leave_behind_ads_card_element", ASMSpotiRuleSet, NO, NULL},
    {NULL, "music_npv_leavebehinds_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_ads_on_podcast", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_display_element", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_element", ASMSpotiRuleSet, NO, NULL},
    {NULL, "is_promo_cta_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_time_cap_upsell_with_premium_badge", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_time_cap_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_time_cap_upsell_on_search", ASMSpotiRuleSet, NO, NULL},
    {NULL, "music_video_upsell_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "is_gbb_upsell_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "should_show_pigeon_upsell", ASMSpotiRuleSet, NO, NULL},
    {NULL, "disable_suggested_tracks_upsell", ASMSpotiRuleSet, YES, NULL},
    {NULL, "is_enabled_pt2", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_skip_button_during_skippable_ads", ASMSpotiRuleSet, YES, NULL},
    {NULL, "sponsored_playlist_v2_header_dismissible", ASMSpotiRuleSet, YES, NULL},
    {NULL, "use_mock_sponsorship_endpoint", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_popup", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_popups", ASMSpotiRuleSet, NO, NULL},
    {NULL, "show_popup", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_interstitials", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_interstitial", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_overlays", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_overlay", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_promotions_on_home", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_promotions_on_search", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_search_page_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_home_page_ads", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_billboard", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_billboards", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audio_ads_player", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_display_ads_player", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_ads_player", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_audio_ads_player_v2", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_display_ads_player_v2", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_video_ads_player_v2", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_results_v2", ASMSpotiRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_results_v2", ASMSpotiRuleSet, NO, NULL},
    {"ios-feature-search", "prompted_playlist_merchandizing_enabled", ASMSpotiRuleSet, NO, NULL},
    {NULL, "should_nova_scroll_use_scrollsita", ASMSpotiRuleRemove, NO, NULL},
    {"ios-sociallistening-configuration-impl", "premium_gated_start_jam_buttons_enabled", ASMSpotiRuleForce, NO, NULL},
};
static const size_t ruleCount = sizeof(rules) / sizeof(rules[0]);

static BOOL ruleMatches(const ASMSpotiRule *rule, NSString *scope, NSString *name) {
    if (rule->scope && ![scope isEqualToString:@(rule->scope)]) return NO;
    return !rule->name || [name isEqualToString:@(rule->name)];
}

// A false BoolValue is an empty message, as protobuf writes it.
static NSData *boolValue(BOOL on) {
    return on ? ASMSpotiPBSerialize(@[ASMSpotiPBVarint(1, 1)]) : [NSData data];
}

static void setValue(NSMutableArray<ASMSpotiPBField *> *value, ASMSpotiPBField *replacement) {
    [value filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ASMSpotiPBField *field, NSDictionary *bindings) {
        return field.number < 3 || field.number > 5;
    }]];
    [value addObject:replacement];
}

static NSData *patchConfiguration(NSData *configuration) {
    NSMutableArray<ASMSpotiPBField *> *fields = ASMSpotiPBParse(configuration);
    if (!fields) return nil;
    NSMutableArray<ASMSpotiPBField *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *present = [NSMutableSet set];
    for (ASMSpotiPBField *field in fields) {
        NSMutableArray<ASMSpotiPBField *> *value = field.number == 3 && field.wire == 2 ? ASMSpotiPBParse(field.payload) : nil;
        ASMSpotiPBField *identifier = ASMSpotiPBFirst(value, 1);
        NSArray<ASMSpotiPBField *> *parts = identifier ? ASMSpotiPBParse(identifier.payload) : nil;
        if (!parts) {
            [out addObject:field];
            continue;
        }
        NSString *scope = ASMSpotiPBText(ASMSpotiPBFirst(parts, 1)) ?: @"", *name = ASMSpotiPBText(ASMSpotiPBFirst(parts, 2)) ?: @"";
        BOOL removed = NO;
        for (size_t i = 0; i < ruleCount && !removed; i++) {
            if (!ruleMatches(&rules[i], scope, name)) continue;
            switch (rules[i].kind) {
                case ASMSpotiRuleRemove: removed = YES; break;
                case ASMSpotiRuleSet:
                    // Set changes a boolean that is there; a value of another kind (a count of seconds, say)
                    // under the same name is left as the server sent it rather than turned into a false.
                    if (ASMSpotiPBFirst(value, 3)) setValue(value, ASMSpotiPBBytes(3, boolValue(rules[i].on)));
                    break;
                case ASMSpotiRuleForce: setValue(value, ASMSpotiPBBytes(3, boolValue(rules[i].on))); break;
                case ASMSpotiRuleEnum: setValue(value, ASMSpotiPBBytes(5, ASMSpotiPBSerialize(@[ASMSpotiPBString(1, @(rules[i].text))]))); break;
            }
        }
        if (removed) continue;
        [present addObject:[NSString stringWithFormat:@"%@.%@", scope, name]];
        field.payload = ASMSpotiPBSerialize(value);
        [out addObject:field];
    }
    for (size_t i = 0; i < ruleCount; i++) {
        if (rules[i].kind != ASMSpotiRuleForce || !rules[i].scope || !rules[i].name) continue;
        if ([present containsObject:[NSString stringWithFormat:@"%s.%s", rules[i].scope, rules[i].name]]) continue;
        NSData *identifier = ASMSpotiPBSerialize(@[ASMSpotiPBString(1, @(rules[i].scope)), ASMSpotiPBString(2, @(rules[i].name))]);
        [out addObject:ASMSpotiPBBytes(3, ASMSpotiPBSerialize(@[ASMSpotiPBBytes(1, identifier), ASMSpotiPBBytes(3, boolValue(rules[i].on))]))];
    }
    return ASMSpotiPBSerialize(out);
}

#pragma mark - the response

static NSData *patchUcs(NSData *ucs) {
    NSMutableArray<ASMSpotiPBField *> *fields = ASMSpotiPBParse(ucs);
    if (!fields) return nil;
    ASMSpotiPBField *resolve = ASMSpotiPBFirst(fields, 1);
    if (resolve.wire == 2) {
        NSData *edited = ASMSpotiPBEdit(resolve.payload, @[@1], ^NSData *(NSData *configuration) {
            return patchConfiguration(configuration);
        });
        if (edited) resolve.payload = edited;
    }
    ASMSpotiPBField *attributes = ASMSpotiPBFirst(fields, 3);
    if (!attributes) [fields addObject:(attributes = ASMSpotiPBBytes(3, nil))];
    if (attributes.wire == 2) attributes.payload = patchAttributes(attributes.payload) ?: attributes.payload;
    return ASMSpotiPBSerialize(fields);
}

NSData *ASMSpotiPatchCustomize(NSData *body) {
    return ASMSpotiPBEdit(body, @[@1], ^NSData *(NSData *ucs) { return patchUcs(ucs); });
}

NSData *ASMSpotiPatchBootstrap(NSData *body) {
    return ASMSpotiPBEdit(body, @[@2, @1, @1, @1], ^NSData *(NSData *ucs) { return patchUcs(ucs); });
}
