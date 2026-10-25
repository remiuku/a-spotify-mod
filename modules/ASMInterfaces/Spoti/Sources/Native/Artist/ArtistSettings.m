#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Artist.h"

UIViewController *ASMSpotiArtistSettingsPage(void) {
    NSArray<ASMSpotiModSection *> *sections = @[
        ASMSpotiSection(@"Photo", @[
            ASMSpotiOptionRow(@"Fade into a blur", nil, ASMSpotiKeyArtistPhotoFade),
        ]),
        ASMSpotiSection(@"Hide in the header", @[
            ASMSpotiHideRow(@"Explore (video deck)", nil, ASMSpotiHideArtistExplore),
            ASMSpotiHideRow(@"Follow", nil, ASMSpotiHideArtistFollow),
            ASMSpotiHideRow(@"More options", nil, ASMSpotiHideArtistMore),
            ASMSpotiHideRow(@"Shuffle", nil, ASMSpotiHideArtistShuffle),
            ASMSpotiHideRow(@"Verified badge", nil, ASMSpotiHideArtistVerified),
            ASMSpotiHideRow(@"Monthly listeners", nil, ASMSpotiHideArtistListeners),
        ]),
        ASMSpotiSection(@"Tabs", @[
            ASMSpotiHideRow(@"Hide the tab bar", nil, ASMSpotiHideArtistTabBar),
        ]),
        ASMSpotiNotedSection(@"Hide on the page", @[
            ASMSpotiHideRow(@"Songs you liked", nil, ASMSpotiHideArtistLikedSongs),
            ASMSpotiHideRow(@"Popular", nil, ASMSpotiHideArtistPopular),
            ASMSpotiHideRow(@"Artist pick", nil, ASMSpotiHideArtistPick),
            ASMSpotiHideRow(@"Popular releases", nil, ASMSpotiHideArtistReleases),
            ASMSpotiHideRow(@"Featuring", nil, ASMSpotiHideArtistFeaturing),
            ASMSpotiHideRow(@"Music videos", nil, ASMSpotiHideArtistVideos),
            ASMSpotiHideRow(@"About", nil, ASMSpotiHideArtistAbout),
            ASMSpotiHideRow(@"Artist playlists", nil, ASMSpotiHideArtistPlaylists),
            ASMSpotiHideRow(@"Fans also like", nil, ASMSpotiHideArtistFansAlsoLike),
            ASMSpotiHideRow(@"Appears on", nil, ASMSpotiHideArtistAppearsOn),
            ASMSpotiHideRow(@"Discovered on", nil, ASMSpotiHideArtistDiscoveredOn),
        ], @"Works only with Spotify in English."),
        ASMSpotiSection(@"Spotify's own", @[
            ASMSpotiFlagRow(@"Share button in the header", @"ios-creator-impl.share_in_action_row_enabled_artist"),
            ASMSpotiFlagRow(@"More options in the navigation bar", @"ios-creator-impl.context_menu_in_navigation_bar_enabled_artist"),
            ASMSpotiFlagRow(@"Top collaborators", @"ios-creator-impl.is_top_collaborators_enabled"),
            ASMSpotiFlagRow(@"Artist facts", @"ios-creator-impl.is_artist_facts_enabled"),
        ]),
    ];
    return [[ASMSpotiModPage alloc] initWithTitle:@"Artist" intro:nil sections:sections footer:nil];
}
