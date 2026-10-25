#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "AdBlock.h"
#import "Shared/Privacy/Privacy.h"

NSString *const ASMVitrineFakePremiumWarning = @"This is the part of EeveeSpotify Spotify's takedown went after, and it has not been tested here. It can end in a forced logout or worse for the account. A Premium account gains nothing from it.";

// Every switch here forces a flag Spotify ships on to off, so the titles name the blocking: on stops
// the thing, off is Spotify's own value. Hide ads and Hide upsells already force the first two
// sections off, which locks those rows.
static UIViewController *adFlagsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Ad and upsell flags" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineNotedSection(@"Ads", @[
            ASMVitrineKillRow(@"Block the ad when the app opens", @"ios-feature-adonappopen.enabled"),
            ASMVitrineKillRow(@"Block its CTA card", @"ios-feature-adonappopen.cta_card_enabled"),
        ], @"Locked while Hide ads is on."),
        ASMVitrineNotedSection(@"Upsells", @[
            ASMVitrineKillRow(@"Hide the shuffle toggle upsell", @"ios-feature-shuffletoggleupsell.is_enabled_pt2"),
            ASMVitrineKillRow(@"Hide the shuffle upsell in the video player", @"ios-feature-nowplaying-modes.video_first_shuffle_upsell_enabled"),
        ], @"Locked while Hide upsells is on."),
        ASMVitrineSection(@"Reduce interventions", @[
            ASMVitrineFlagRow(@"Reduce interventions", @"ios-messaging-reduceinterventions-impl.enabled"),
        ]),
        ASMVitrineSection(@"Tooltips", @[
            ASMVitrineKillRow(@"Hide the smart shuffle helper", @"ios-messaging-reduceinterventions-impl.enable_message_smart_shuffle_helper_tooltip"),
            ASMVitrineKillRow(@"Hide the data saver tip", @"ios-feature-nowplayingbar.data_saver_tooltip"),
            ASMVitrineKillRow(@"Hide the player suggestions upsell", @"ios-messaging-reduceinterventions-impl.enable_message_reinvent_free_n_p_v_suggestions_upsell"),
            ASMVitrineKillRow(@"Hide the AI playlist creation tip", @"ios-messaging-reduceinterventions-impl.enable_message_your_library_ai_playlist_creation_tooltip"),
            ASMVitrineKillRow(@"Hide the watch feed explorer tip", @"ios-messaging-reduceinterventions-impl.enable_message_watch_feed_entity_explorer_tooltip"),
            ASMVitrineKillRow(@"Hide the account switching tip", @"ios-messaging-reduceinterventions-impl.enable_message_account_switching_tooltip"),
            ASMVitrineKillRow(@"Hide the concert notifications tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_concert_notifications_tooltip"),
            ASMVitrineKillRow(@"Hide the live event tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_event_entity_safe_tooltip"),
            ASMVitrineKillRow(@"Hide the live event venue tip", @"ios-messaging-reduceinterventions-impl.enable_message_live_events_event_entity_venuename_header_tooltip"),
            ASMVitrineKillRow(@"Hide the Puffin nudge", @"ios-messaging-reduceinterventions-impl.enable_message_puffin_nudge_end_optimization"),
        ]),
    ] footer:nil];
}

// The switches first and what they have stopped last, so the counters bury no setting.
UIViewController *ASMVitrineAdsSettingsPage(void) {
    NSMutableArray<ASMVitrineModRow *> *counts = [NSMutableArray array];
    for (NSString *label in ASMVitrineAdBlockLabels()) {
        [counts addObject:ASMVitrineStatRow(label, ^NSString *{
            NSUInteger checked = ASMVitrineAdBlockChecked(label);
            return checked == NSNotFound ? @(ASMVitrineAdBlockCount(label)).stringValue
                : [NSString stringWithFormat:@"%lu of %lu", (unsigned long)ASMVitrineAdBlockCount(label), (unsigned long)checked];
        })];
    }
    [counts addObject:ASMVitrineStatRow(@"Total", ^NSString *{
        return @(ASMVitrineAdBlockCount(nil)).stringValue;
    })];
    [counts addObject:ASMVitrineActionRow(@"Reset the counters", nil, ^{ ASMVitrineResetAdBlock(); })];

    ASMVitrineModRow *fakePremium = ASMVitrineOptionRow(@"Spoof Premium", nil, ASMVitrineKeyFakePremium);
    fakePremium.warning = ASMVitrineFakePremiumWarning;

    // The redesign's Search keeps only its category cards, so the video carousel switch is the native look's.
    NSMutableArray<ASMVitrineModRow *> *ads = [NSMutableArray arrayWithObjects:
        ASMVitrineWithSymbol(ASMVitrineOptionRow(@"Hide ads", nil, ASMVitrineKeyHideAds), @"speaker.slash"),
        ASMVitrineWithSymbol(ASMVitrineOptionRow(@"Hide upsells", nil, ASMVitrineKeyHideUpsells), @"hand.raised"), nil];
    if (!ASMVitrineRedesignedUIStored()) [ads addObject:ASMVitrineWithSymbol(ASMVitrineOptionRow(@"Hide the video carousel in Search", nil, ASMVitrineKeyHideSearchVideos), @"play.rectangle.on.rectangle")];
    [ads addObject:ASMVitrineWithSymbol(ASMVitrinePageRow(@"Ad and upsell flags", ^UIViewController *{ return adFlagsPage(); }), @"flag")];

    return [[ASMVitrineModPage alloc] initWithTitle:@"Premium, ads & privacy" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineNotedSection(@"Ads", ads, @"Audio ads between songs need Spoof Premium."),
        ASMVitrineNotedSection(@"Premium", @[
            ASMVitrineWithSymbol(fakePremium, @"crown"),
        ], @"Free accounts only."),
        ASMVitrinePrivacySection(),
        ASMVitrineNotedSection(@"Ads blocked so far", counts,
                       @"\"3 of 214\" is 3 stopped of 214 checked. 0 of 0 means Spotify never asked, so that part does nothing on this version."),
        ASMVitrinePrivacyCountersSection(),
    ] footer:nil];
}
