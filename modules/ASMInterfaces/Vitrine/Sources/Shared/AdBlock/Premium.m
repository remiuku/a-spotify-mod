// Spoof Premium: the UCS response, which carries the account's product state and its remote
// config, rewritten as it arrives. The attributes and the flag rules are EeveeSpotify's. Offline,
// audio quality and the social session attributes are left alone: the server still decides those,
// and a spoofed one only shows UI the request behind it will fail.
//
// UcsResponse: 1 ResolveResponse { 1 ResolveConfiguration { 3 repeated AssignedValue } },
//   3 AccountAttributesResponse { 1 repeated entry { 1 key, 2 AccountAttribute { 2 bool, 4 string } } }
// AssignedValue: 1 { 1 scope, 2 name }, 3 BoolValue { 1 }, 4 IntValue { 1 }, 5 EnumValue { 1 }
// A customize body is CustomizeMessage { 1 UcsResponse }; bootstrap wraps that in 2 { 1 { 1 { it } } }.
#import "Core/ASMVitrineCore.h"
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

static ASMVitrinePBField *attributeEntry(NSString *key, id value) {
    ASMVitrinePBField *attribute = [value isKindOfClass:NSString.class] ? ASMVitrinePBString(4, value) : ASMVitrinePBVarint(2, [value boolValue]);
    return ASMVitrinePBBytes(1, ASMVitrinePBSerialize(@[ASMVitrinePBString(1, key), ASMVitrinePBBytes(2, ASMVitrinePBSerialize(@[attribute]))]));
}

static NSData *patchAttributes(NSData *response) {
    NSMutableArray<ASMVitrinePBField *> *fields = ASMVitrinePBParse(response);
    if (!fields) return nil;
    NSDictionary<NSString *, id> *forced = forcedAttributes();
    NSMutableArray<ASMVitrinePBField *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (ASMVitrinePBField *field in fields) {
        NSString *key = field.number == 1 && field.wire == 2 ? ASMVitrinePBText(ASMVitrinePBFirst(ASMVitrinePBParse(field.payload), 1)) : nil;
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
    return ASMVitrinePBSerialize(out);
}

#pragma mark - remote config

typedef NS_ENUM(NSInteger, ASMVitrineRuleKind) { ASMVitrineRuleRemove, ASMVitrineRuleSet, ASMVitrineRuleForce, ASMVitrineRuleEnum };
// A NULL scope or name matches any. Set changes a value that is there, Force adds it when it is not.
typedef struct { const char *scope, *name; ASMVitrineRuleKind kind; BOOL on; const char *text; } ASMVitrineRule;

static const ASMVitrineRule rules[] = {
    // The ios-feature-settings flags only draw the rows; the player core gates each on its own scope.
    {"ios-feature-settings", "crossfade_enabled", ASMVitrineRuleForce, YES, NULL},
    {"ios-feature-settings", "automix_enabled", ASMVitrineRuleForce, YES, NULL},
    {"core-playback-setup", "crossfade_enabled", ASMVitrineRuleForce, YES, NULL},
    {"core-automix", "automix_enabled", ASMVitrineRuleForce, YES, NULL},
    // The player core's own ad machinery. A Free account's config leaves these out, so the core runs its defaults; a
    // Premium account's sets both off (compared on 2026-10-09: the other core-ads values are the same for both).
    {"core-ads", "enable_state_fetch_system", ASMVitrineRuleForce, NO, NULL},
    {"core-ad-detection", "use_ad_placements_beta", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-settings", "use_playback_settings_crossfade", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-settings", "use_playback_settings_gapless", ASMVitrineRuleForce, NO, NULL},
    {NULL, "enable_common_capping", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_pns_common_capping", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_pick_and_shuffle_common_capping", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_pick_and_shuffle_dynamic_cap", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "pick_and_shuffle_timecap", ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-queue", NULL, ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_free_on_demand_experiment", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_free_on_demand_context_menu_experiment", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_mft_plus_queue", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_mft_plus_extended_queue", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_playback_timeout_service", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playback_timeout_error_ui", ASMVitrineRuleSet, NO, NULL},
    {NULL, "playback_timeout_action", ASMVitrineRuleEnum, NO, "Nothing"},
    {NULL, "is_remove_from_queue_enabled_for_mft_plus", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "is_reordering_for_mft_plus_allowed", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "ad_metadata", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "ad_slots", ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audio_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_display_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_premium_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_premium_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_campaigns", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_promotions", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_upsell", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "is_enabled_pt2", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "linear_upsell_new_style_experiment_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-shuffletoggleupsell", "play_modes_upsell_new_style_experiment_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-jam-freeusershuffleupsellsheetpage-impl", "free_user_shuffle_upsell_sheet_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-jam-freeuserskipupsellpage-impl", "free_user_skip_upsell_sheet_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-jam-freehostedjamsupsell-impl", "free_hosted_jams_upsell_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-reinventfree-contextualupsellpremiumpromo-impl", "is_promo_cta_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-reinventfree-contextualupsellpremiumpromo-impl", "show_time_cap_upsell_with_premium_badge", ASMVitrineRuleForce, NO, NULL},
    {"ios-reinventfree-controllerui-impl", "enable_video_time_cap_upsell", ASMVitrineRuleForce, NO, NULL},
    {"ios-reinventfree-controllerui-impl", "enable_video_time_cap_upsell_on_search", ASMVitrineRuleForce, NO, NULL},
    {"ios-reinventfree-timecappivot-impl", "music_video_upsell_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-settings-mediaqualitypageplugin-impl", "is_gbb_upsell_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-settings-mediaqualitypageplugin-impl", "should_show_pigeon_upsell", ASMVitrineRuleForce, NO, NULL},
    {"ios-system-listeningparties", "preview_ended_upsell_enabled", ASMVitrineRuleForce, NO, NULL},
    {NULL, "enable_now_playing_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_now_playing_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_artist_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_playlist_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_album_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_library_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audiobook_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_banner_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_banner_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_podcast_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_content", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlists", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_sessions", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_stories", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_videos", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artists", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_albums", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_track", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_tracks", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_show", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_shows", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_episode", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_episodes", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobooks", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcasts", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_results", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_banner", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_banners", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_now_playing_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_artist_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_playlist_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_album_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_library_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_audiobook_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_sponsored_ad", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_podcast_sponsored_ads", ASMVitrineRuleSet, NO, NULL},
    {"ios-ad-on-app-open", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-adonappopen", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-adonappopen", "enabled", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adonappopen", "background_refresh_frequency_seconds", ASMVitrineRuleSet, NO, NULL},
    {NULL, "is_ad_on_app_open_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "ad_on_app_open_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "adonappopen_enabled", ASMVitrineRuleSet, NO, NULL},
    {"marquee", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-marquee", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"leavebehindadsbase", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-leavebehindadsbase", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-nowplaying-scroll-impl", "unified_leavebehind_npv_scroll_music_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-nowplaying-scroll-impl", "unified_leavebehind_npv_scroll_podcast_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-embeddedplaylist", "use_unified_leavebehind_fetch", ASMVitrineRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "foreground_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "music_track_change_enabled", ASMVitrineRuleForce, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", "enable_ads_on_podcast", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-instreamads", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-adsembedded-embeddedctaelements-impl", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-adsnowplaying-embeddednpv-impl", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-adsplatform-elementimpl", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-system-adssponsoredcontext", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-adsbase", "enable_ads_connect_state_observer", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adsbase", "enable_minimal_preroll_management", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adsbase", "enable_swift_ads_base_movement_logger", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adsswift", NULL, ASMVitrineRuleRemove, NO, NULL},
    {"ios-feature-adsnowplayingui", "embedded_npv_video_show_with_canvas", ASMVitrineRuleForce, NO, NULL},
    {"ios-feature-adssponsoredcontext", "sponsored_context_mismatch_aderror_enabled", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adssponsoredcontext", "sponsored_playlist_v2_enabled", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adssponsoredcontextnpbattachment", "sponsored_npb_slot_fetch_enabled", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-adsidentitytracking", NULL, ASMVitrineRuleRemove, NO, NULL},
    {NULL, "enable_popups", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_leave_behind_ads_card_element", ASMVitrineRuleSet, NO, NULL},
    {NULL, "music_npv_leavebehinds_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_ads_on_podcast", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_display_element", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_element", ASMVitrineRuleSet, NO, NULL},
    {NULL, "is_promo_cta_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_time_cap_upsell_with_premium_badge", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_time_cap_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_time_cap_upsell_on_search", ASMVitrineRuleSet, NO, NULL},
    {NULL, "music_video_upsell_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "is_gbb_upsell_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "should_show_pigeon_upsell", ASMVitrineRuleSet, NO, NULL},
    {NULL, "disable_suggested_tracks_upsell", ASMVitrineRuleSet, YES, NULL},
    {NULL, "is_enabled_pt2", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_skip_button_during_skippable_ads", ASMVitrineRuleSet, YES, NULL},
    {NULL, "sponsored_playlist_v2_header_dismissible", ASMVitrineRuleSet, YES, NULL},
    {NULL, "use_mock_sponsorship_endpoint", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_popup", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_popups", ASMVitrineRuleSet, NO, NULL},
    {NULL, "show_popup", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_interstitials", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_interstitial", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_overlays", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_overlay", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_promotions_on_home", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_promotions_on_search", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_search_page_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_home_page_ads", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_billboard", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_billboards", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audio_ads_player", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_display_ads_player", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_ads_player", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_audio_ads_player_v2", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_display_ads_player_v2", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_video_ads_player_v2", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_search_results_v2", ASMVitrineRuleSet, NO, NULL},
    {NULL, "enable_sponsored_home_results_v2", ASMVitrineRuleSet, NO, NULL},
    {"ios-feature-search", "prompted_playlist_merchandizing_enabled", ASMVitrineRuleSet, NO, NULL},
    {NULL, "should_nova_scroll_use_scrollsita", ASMVitrineRuleRemove, NO, NULL},
    {"ios-sociallistening-configuration-impl", "premium_gated_start_jam_buttons_enabled", ASMVitrineRuleForce, NO, NULL},
};
static const size_t ruleCount = sizeof(rules) / sizeof(rules[0]);

static BOOL ruleMatches(const ASMVitrineRule *rule, NSString *scope, NSString *name) {
    if (rule->scope && ![scope isEqualToString:@(rule->scope)]) return NO;
    return !rule->name || [name isEqualToString:@(rule->name)];
}

// A false BoolValue is an empty message, as protobuf writes it.
static NSData *boolValue(BOOL on) {
    return on ? ASMVitrinePBSerialize(@[ASMVitrinePBVarint(1, 1)]) : [NSData data];
}

static void setValue(NSMutableArray<ASMVitrinePBField *> *value, ASMVitrinePBField *replacement) {
    [value filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ASMVitrinePBField *field, NSDictionary *bindings) {
        return field.number < 3 || field.number > 5;
    }]];
    [value addObject:replacement];
}

// The configuration as the server sent it, one "scope.name = value" a line, in Caches/Vitrine/live-config.txt: what a
// Free account in this country is told, to set beside a Premium one when ads still play. Names and values only;
// replaced by each fetch.
static void keepLiveConfiguration(NSArray<ASMVitrinePBField *> *fields) {
    NSMutableString *text = [NSMutableString string];
    for (ASMVitrinePBField *field in fields) {
        NSArray<ASMVitrinePBField *> *value = field.number == 3 && field.wire == 2 ? ASMVitrinePBParse(field.payload) : nil;
        NSArray<ASMVitrinePBField *> *parts = ASMVitrinePBFirst(value, 1) ? ASMVitrinePBParse(ASMVitrinePBFirst(value, 1).payload) : nil;
        if (!parts) continue;
        NSString *shown = @"?";
        if (ASMVitrinePBFirst(value, 3)) shown = ASMVitrinePBFirst(ASMVitrinePBParse(ASMVitrinePBFirst(value, 3).payload), 1).varint ? @"true" : @"false";
        else if (ASMVitrinePBFirst(value, 4)) shown = @(ASMVitrinePBFirst(ASMVitrinePBParse(ASMVitrinePBFirst(value, 4).payload), 1).varint).stringValue;
        else if (ASMVitrinePBFirst(value, 5)) shown = ASMVitrinePBText(ASMVitrinePBFirst(ASMVitrinePBParse(ASMVitrinePBFirst(value, 5).payload), 1)) ?: @"";
        [text appendFormat:@"%@.%@ = %@\n", ASMVitrinePBText(ASMVitrinePBFirst(parts, 1)) ?: @"", ASMVitrinePBText(ASMVitrinePBFirst(parts, 2)) ?: @"", shown];
    }
    NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [caches URLByAppendingPathComponent:@"Vitrine" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    [text writeToURL:[folder URLByAppendingPathComponent:@"live-config.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static NSData *patchConfiguration(NSData *configuration) {
    NSMutableArray<ASMVitrinePBField *> *fields = ASMVitrinePBParse(configuration);
    if (!fields) return nil;
    keepLiveConfiguration(fields);
    NSMutableArray<ASMVitrinePBField *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *present = [NSMutableSet set];
    for (ASMVitrinePBField *field in fields) {
        NSMutableArray<ASMVitrinePBField *> *value = field.number == 3 && field.wire == 2 ? ASMVitrinePBParse(field.payload) : nil;
        ASMVitrinePBField *identifier = ASMVitrinePBFirst(value, 1);
        NSArray<ASMVitrinePBField *> *parts = identifier ? ASMVitrinePBParse(identifier.payload) : nil;
        if (!parts) {
            [out addObject:field];
            continue;
        }
        NSString *scope = ASMVitrinePBText(ASMVitrinePBFirst(parts, 1)) ?: @"", *name = ASMVitrinePBText(ASMVitrinePBFirst(parts, 2)) ?: @"";
        BOOL removed = NO;
        for (size_t i = 0; i < ruleCount && !removed; i++) {
            if (!ruleMatches(&rules[i], scope, name)) continue;
            switch (rules[i].kind) {
                case ASMVitrineRuleRemove: removed = YES; break;
                case ASMVitrineRuleSet:
                    // Set changes a boolean that is there; a value of another kind (a count of seconds, say)
                    // under the same name is left as the server sent it rather than turned into a false.
                    if (ASMVitrinePBFirst(value, 3)) setValue(value, ASMVitrinePBBytes(3, boolValue(rules[i].on)));
                    break;
                case ASMVitrineRuleForce: setValue(value, ASMVitrinePBBytes(3, boolValue(rules[i].on))); break;
                case ASMVitrineRuleEnum: setValue(value, ASMVitrinePBBytes(5, ASMVitrinePBSerialize(@[ASMVitrinePBString(1, @(rules[i].text))]))); break;
            }
        }
        if (removed) continue;
        [present addObject:[NSString stringWithFormat:@"%@.%@", scope, name]];
        field.payload = ASMVitrinePBSerialize(value);
        [out addObject:field];
    }
    for (size_t i = 0; i < ruleCount; i++) {
        if (rules[i].kind != ASMVitrineRuleForce || !rules[i].scope || !rules[i].name) continue;
        if ([present containsObject:[NSString stringWithFormat:@"%s.%s", rules[i].scope, rules[i].name]]) continue;
        NSData *identifier = ASMVitrinePBSerialize(@[ASMVitrinePBString(1, @(rules[i].scope)), ASMVitrinePBString(2, @(rules[i].name))]);
        [out addObject:ASMVitrinePBBytes(3, ASMVitrinePBSerialize(@[ASMVitrinePBBytes(1, identifier), ASMVitrinePBBytes(3, boolValue(rules[i].on))]))];
    }
    return ASMVitrinePBSerialize(out);
}

#pragma mark - the response

static NSData *patchUcs(NSData *ucs) {
    NSMutableArray<ASMVitrinePBField *> *fields = ASMVitrinePBParse(ucs);
    if (!fields) return nil;
    ASMVitrinePBField *resolve = ASMVitrinePBFirst(fields, 1);
    if (resolve.wire == 2) {
        NSData *edited = ASMVitrinePBEdit(resolve.payload, @[@1], ^NSData *(NSData *configuration) {
            return patchConfiguration(configuration);
        });
        if (edited) resolve.payload = edited;
    }
    ASMVitrinePBField *attributes = ASMVitrinePBFirst(fields, 3);
    if (!attributes) [fields addObject:(attributes = ASMVitrinePBBytes(3, nil))];
    if (attributes.wire == 2) attributes.payload = patchAttributes(attributes.payload) ?: attributes.payload;
    return ASMVitrinePBSerialize(fields);
}

NSData *ASMVitrinePatchCustomize(NSData *body) {
    return ASMVitrinePBEdit(body, @[@1], ^NSData *(NSData *ucs) { return patchUcs(ucs); });
}

NSData *ASMVitrinePatchBootstrap(NSData *body) {
    return ASMVitrinePBEdit(body, @[@2, @1, @1, @1], ^NSData *(NSData *ucs) { return patchUcs(ucs); });
}
