// The native player's settings: Spotify's own player screen and the parts of it to hide, and the queue
// and devices flags. The Player page that holds them is App/Pages.m's.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "NowPlaying.h"

NSArray<ASMVitrineModSection *> *ASMVitrineNativePlayerScreenSections(void) {
    return @[
        ASMVitrineSection(@"Player screen", @[
            ASMVitrineOptionRow(@"Artwork background", nil, ASMVitrineKeyPlayerBackdrop),
            ASMVitrineOptionRow(@"Glass header buttons", nil, ASMVitrineKeyPlayer),
            ASMVitrineKillRow(@"Disable Canvas", @"ios-feature-canvas.canvas_enabled"),
            ASMVitrineFlagRow(@"Sheet style player", @"ios-feature-nowplaying.sheet_style_npv"),
            ASMVitrineFlagRow(@"Redesigned header", @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled"),
            ASMVitrineFlagRow(@"New progress slider", @"ios-feature-encoreexperiments.new_npv_slider_enabled"),
            ASMVitrineFlagRow(@"Expand the sticky header on tap", @"ios-feature-nowplaying.expand_sticky_header_on_tap"),
        ]),
        ASMVitrineSection(@"Hide cards below the player", @[
            ASMVitrineHideRow(@"Lyrics", nil, ASMVitrineHideLyricsCard),
            ASMVitrineHideRow(@"About the artist", nil, ASMVitrineHideAboutArtist),
            ASMVitrineHideRow(@"Related videos", nil, ASMVitrineHideRelatedVideos),
            ASMVitrineHideRow(@"SongDNA", nil, ASMVitrineHideSongDNA),
            ASMVitrineHideRow(@"Live events", nil, ASMVitrineHideLiveEvents),
            ASMVitrineHideRow(@"Explore the artist", nil, ASMVitrineHideExploreArtist),
            ASMVitrineHideRow(@"Credits", nil, ASMVitrineHideCredits),
            ASMVitrineHideRow(@"Merch", nil, ASMVitrineHideMerch),
            ASMVitrineHideRow(@"Recommendations", nil, ASMVitrineHideRecommendations),
        ]),
        ASMVitrineSection(@"Hide on the player", @[
            ASMVitrineHideRow(@"Lyrics preview", nil, ASMVitrineHideLyricsInline),
            ASMVitrineHideRow(@"Shuffle", nil, ASMVitrineHideShuffle),
            ASMVitrineHideRow(@"Repeat", nil, ASMVitrineHideRepeat),
            ASMVitrineHideRow(@"Add to playlist", nil, ASMVitrineHideAddTo),
            ASMVitrineHideRow(@"Queue", nil, ASMVitrineHideQueue),
            ASMVitrineHideRow(@"Share", nil, ASMVitrineHideShare),
            ASMVitrineHideRow(@"Connect to a device", nil, ASMVitrineHideConnect),
        ]),
    ];
}

ASMVitrineModRow *ASMVitrineGlassLyricsRow(void) {
    return ASMVitrineOptionRow(@"Glass lyrics", nil, ASMVitrineKeyLyricsCard);
}

UIViewController *ASMVitrineQueueSettingsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Queue & devices" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineSection(@"Bottom sheets", @[
            ASMVitrineFlagRow(@"Queue as a bottom sheet", @"ios-feature-nowplaying.bottom_sheet_queue_enabled"),
            ASMVitrineFlagRow(@"Connect as a bottom sheet", @"ios-feature-nowplaying-elements.enable_connect_bottom_sheet"),
            ASMVitrineFlagRow(@"Connect sheet from the video switcher", @"ios-playbackcontrol-audiovideoswitcher-impl.enable_connect_bottom_sheet"),
        ]),
        ASMVitrineSection(@"Queue", @[
            ASMVitrineFlagRow(@"Queue flip transition", @"ios-feature-nowplaying.queue_flip_transition_enabled"),
            ASMVitrineFlagRow(@"Play next in the context menu", @"ios-feature-queue.is_play_next_context_menu_enabled"),
        ]),
    ] footer:nil];
}
