// The native player's settings: Spotify's own player screen and the parts of it to hide, and the queue
// and devices flags. The Player page that holds them is App/Pages.m's.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "NowPlaying.h"

NSArray<ASMSpotiModSection *> *ASMSpotiNativePlayerScreenSections(void) {
    return @[
        ASMSpotiSection(@"Player screen", @[
            ASMSpotiOptionRow(@"Artwork background", nil, ASMSpotiKeyPlayerBackdrop),
            ASMSpotiOptionRow(@"Glass header buttons", nil, ASMSpotiKeyPlayer),
            ASMSpotiKillRow(@"Disable Canvas", @"ios-feature-canvas.canvas_enabled"),
            ASMSpotiFlagRow(@"Sheet style player", @"ios-feature-nowplaying.sheet_style_npv"),
            ASMSpotiFlagRow(@"Redesigned header", @"ios-feature-nowplaying.new_redesign_header_with_context_menu_enabled"),
            ASMSpotiFlagRow(@"New progress slider", @"ios-feature-encoreexperiments.new_npv_slider_enabled"),
            ASMSpotiFlagRow(@"Expand the sticky header on tap", @"ios-feature-nowplaying.expand_sticky_header_on_tap"),
        ]),
        ASMSpotiSection(@"Hide cards below the player", @[
            ASMSpotiHideRow(@"Lyrics", nil, ASMSpotiHideLyricsCard),
            ASMSpotiHideRow(@"About the artist", nil, ASMSpotiHideAboutArtist),
            ASMSpotiHideRow(@"Related videos", nil, ASMSpotiHideRelatedVideos),
            ASMSpotiHideRow(@"SongDNA", nil, ASMSpotiHideSongDNA),
            ASMSpotiHideRow(@"Live events", nil, ASMSpotiHideLiveEvents),
            ASMSpotiHideRow(@"Explore the artist", nil, ASMSpotiHideExploreArtist),
            ASMSpotiHideRow(@"Credits", nil, ASMSpotiHideCredits),
            ASMSpotiHideRow(@"Merch", nil, ASMSpotiHideMerch),
            ASMSpotiHideRow(@"Recommendations", nil, ASMSpotiHideRecommendations),
        ]),
        ASMSpotiSection(@"Hide on the player", @[
            ASMSpotiHideRow(@"Lyrics preview", nil, ASMSpotiHideLyricsInline),
            ASMSpotiHideRow(@"Shuffle", nil, ASMSpotiHideShuffle),
            ASMSpotiHideRow(@"Repeat", nil, ASMSpotiHideRepeat),
            ASMSpotiHideRow(@"Add to playlist", nil, ASMSpotiHideAddTo),
            ASMSpotiHideRow(@"Queue", nil, ASMSpotiHideQueue),
            ASMSpotiHideRow(@"Share", nil, ASMSpotiHideShare),
            ASMSpotiHideRow(@"Connect to a device", nil, ASMSpotiHideConnect),
        ]),
    ];
}

ASMSpotiModRow *ASMSpotiGlassLyricsRow(void) {
    return ASMSpotiOptionRow(@"Glass lyrics", nil, ASMSpotiKeyLyricsCard);
}

UIViewController *ASMSpotiQueueSettingsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Queue & devices" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiSection(@"Bottom sheets", @[
            ASMSpotiFlagRow(@"Queue as a bottom sheet", @"ios-feature-nowplaying.bottom_sheet_queue_enabled"),
            ASMSpotiFlagRow(@"Connect as a bottom sheet", @"ios-feature-nowplaying-elements.enable_connect_bottom_sheet"),
            ASMSpotiFlagRow(@"Connect sheet from the video switcher", @"ios-playbackcontrol-audiovideoswitcher-impl.enable_connect_bottom_sheet"),
        ]),
        ASMSpotiSection(@"Queue", @[
            ASMSpotiFlagRow(@"Queue flip transition", @"ios-feature-nowplaying.queue_flip_transition_enabled"),
            ASMSpotiFlagRow(@"Play next in the context menu", @"ios-feature-queue.is_play_next_context_menu_enabled"),
        ]),
    ] footer:nil];
}
