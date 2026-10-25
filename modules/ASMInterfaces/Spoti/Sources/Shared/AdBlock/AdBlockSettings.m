#import "Settings/ASMSpotiModPage.h"
#import "AdBlock.h"
#import "Shared/Privacy/Privacy.h"

NSString *const ASMSpotiFakePremiumWarning = @"This is the part of EeveeSpotify Spotify's takedown went after, and it has not been tested here. It can end in a forced logout or worse for the account. A Premium account gains nothing from it.";

// Every switch here forces a flag Spotify ships on to off, so the titles name the blocking: on stops
// the thing, off is Spotify's own value. Hide ads and Hide upsells already force the first two
// sections off, which locks those rows.
static UIViewController *adFlagsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Ad and upsell flags" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiNotedSection(@"Ads", @[
            ASMSpotiKillRow(@"Block the ad when the app opens", @"ios-feature-adonappopen.enabled"),
            ASMSpotiKillRow(@"Block its CTA card", @"ios-feature-adonappopen.cta_card_enabled"),
        ], @"Locked while Hide ads is on."),
        ASMSpotiNotedSection(@"Upsells", @[
            ASMSpotiKillRow(@"Hide the shuffle toggle upsell", @"ios-feature-shuffletoggleupsell.is_enabled_pt2"),
            ASMSpotiKillRow(@"Hide the shuffle upsell in the video player", @"ios-feature-nowplaying-modes.video_first_shuffle_upsell_enabled"),
        ], @"Locked while Hide upsells is on."),
        ASMSpotiSection(@"Reduce interventions", @[
            ASMSpotiFlagRow(@"Reduce interventions", @"ios-messaging-reduceinterventions-impl.enabled"),
        ]),
        ASMSpotiSection(@"Tooltips", @[
            ASMSpotiKillRow(@"Hide the smart shuffle helper", @"ios-messaging-reduceinterventions-impl.enable_message_smart_shuffle_helper_tooltip"),
            ASMSpotiKillRow(@"Hide the data saver tip", @"ios-feature-nowplayingbar.data_saver_tooltip"),
            ASMSpotiKillRow(@"Hide the player suggestions upsell", @"ios-messaging-reduceinterventions-impl.enable_message_reinvent_free_n_p_v_suggestions_upsell"),
            ASMSpotiKillRow(@"Hide the AI playlist creation tip", @"ios-messaging-reduceinterventions-impl.enable_message_your_library_ai_playlist_creation_tooltip"),
            ASMSpotiKillRow(@"Hide the watch feed explorer tip", @"ios-messaging-reduceinterventions-impl.enable_message_watch_feed_entity_explorer_tooltip"),
            ASMSpotiKillRow(@"Hide the account switching tip", @"ios-messaging-reduceinterventions-impl.enable_message_account_switching_tooltip"),
            ASMSpotiKillRow(@"Hide the concert notifications tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_concert_notifications_tooltip"),
            ASMSpotiKillRow(@"Hide the live event tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_event_entity_safe_tooltip"),
            ASMSpotiKillRow(@"Hide the live event venue tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_event_entity_venuename_header_tooltip"),
            ASMSpotiKillRow(@"Hide the Puffin nudge", @"ios-messaging-reduceinterventions-impl.enable_message_puffin_nudge_end_optimization"),
        ]),
    ] footer:nil];
}

// The switches first and what they have stopped last, so the counters bury no setting.
UIViewController *ASMSpotiAdsSettingsPage(void) {
    NSMutableArray<ASMSpotiModRow *> *counts = [NSMutableArray array];
    for (NSString *label in ASMSpotiAdBlockLabels()) {
        [counts addObject:ASMSpotiStatRow(label, ^NSString *{
            return @(ASMSpotiAdBlockCount(label)).stringValue;
        })];
    }
    [counts addObject:ASMSpotiStatRow(@"Total", ^NSString *{
        return @(ASMSpotiAdBlockCount(nil)).stringValue;
    })];
    [counts addObject:ASMSpotiActionRow(@"Reset the counters", nil, ^{ ASMSpotiResetAdBlock(); })];

    ASMSpotiModRow *fakePremium = ASMSpotiOptionRow(@"Spoof Premium", nil, ASMSpotiKeyFakePremium);
    fakePremium.warning = ASMSpotiFakePremiumWarning;

    return [[ASMSpotiModPage alloc] initWithTitle:@"Premium, ads & privacy" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiNotedSection(@"Ads", @[
            ASMSpotiWithSymbol(ASMSpotiOptionRow(@"Hide ads", nil, ASMSpotiKeyHideAds), @"speaker.slash"),
            ASMSpotiWithSymbol(ASMSpotiOptionRow(@"Hide upsells", nil, ASMSpotiKeyHideUpsells), @"hand.raised"),
            ASMSpotiWithSymbol(ASMSpotiOptionRow(@"Hide the video carousel in Search", nil, ASMSpotiKeyHideSearchVideos), @"play.rectangle.on.rectangle"),
            ASMSpotiWithSymbol(ASMSpotiOptionRow(@"Hide social proof in Search", nil, ASMSpotiKeyHideSocialProof), @"person.2"),
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"Ad and upsell flags", ^UIViewController *{ return adFlagsPage(); }), @"flag"),
        ], @"Audio ads between songs need Spoof Premium."),
        ASMSpotiNotedSection(@"Premium", @[
            ASMSpotiWithSymbol(fakePremium, @"crown"),
        ], @"Free accounts only."),
        ASMSpotiPrivacySection(),
        ASMSpotiSection(@"Ads blocked so far", counts),
        ASMSpotiPrivacyCountersSection(),
    ] footer:nil];
}
