#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Artist.h"

UIViewController *ASMVitrineArtistSettingsPage(void) {
    NSArray<ASMVitrineModSection *> *sections = @[
        ASMVitrineSection(@"Photo", @[
            ASMVitrineOptionRow(@"Fade into a blur", nil, ASMVitrineKeyArtistPhotoFade),
        ]),
        ASMVitrineSection(@"Hide in the header", @[
            ASMVitrineHideRow(@"Explore (video deck)", nil, ASMVitrineHideArtistExplore),
            ASMVitrineHideRow(@"Follow", nil, ASMVitrineHideArtistFollow),
            ASMVitrineHideRow(@"More options", nil, ASMVitrineHideArtistMore),
            ASMVitrineHideRow(@"Shuffle", nil, ASMVitrineHideArtistShuffle),
            ASMVitrineHideRow(@"Verified badge", nil, ASMVitrineHideArtistVerified),
            ASMVitrineHideRow(@"Monthly listeners", nil, ASMVitrineHideArtistListeners),
        ]),
        ASMVitrineSection(@"Tabs", @[
            ASMVitrineHideRow(@"Hide the tab bar", nil, ASMVitrineHideArtistTabBar),
        ]),
        ASMVitrineNotedSection(@"Hide on the page", @[
            ASMVitrineHideRow(@"Songs you liked", nil, ASMVitrineHideArtistLikedSongs),
            ASMVitrineHideRow(@"Popular", nil, ASMVitrineHideArtistPopular),
            ASMVitrineHideRow(@"Artist pick", nil, ASMVitrineHideArtistPick),
            ASMVitrineHideRow(@"Popular releases", nil, ASMVitrineHideArtistReleases),
            ASMVitrineHideRow(@"Featuring", nil, ASMVitrineHideArtistFeaturing),
            ASMVitrineHideRow(@"Music videos", nil, ASMVitrineHideArtistVideos),
            ASMVitrineHideRow(@"About", nil, ASMVitrineHideArtistAbout),
            ASMVitrineHideRow(@"Artist playlists", nil, ASMVitrineHideArtistPlaylists),
            ASMVitrineHideRow(@"Fans also like", nil, ASMVitrineHideArtistFansAlsoLike),
            ASMVitrineHideRow(@"Appears on", nil, ASMVitrineHideArtistAppearsOn),
            ASMVitrineHideRow(@"Discovered on", nil, ASMVitrineHideArtistDiscoveredOn),
        ], @"Works only with Spotify in English."),
        ASMVitrineSection(@"Spotify's own", @[
            ASMVitrineFlagRow(@"Share button in the header", @"ios-creator-impl.share_in_action_row_enabled_artist"),
            ASMVitrineFlagRow(@"More options in the navigation bar", @"ios-creator-impl.context_menu_in_navigation_bar_enabled_artist"),
            ASMVitrineFlagRow(@"Top collaborators", @"ios-creator-impl.is_top_collaborators_enabled"),
            ASMVitrineFlagRow(@"Artist facts", @"ios-creator-impl.is_artist_facts_enabled"),
        ]),
    ];
    return [[ASMVitrineModPage alloc] initWithTitle:@"Artist" intro:nil sections:sections footer:nil];
}
