#import "Settings/ASMSpotiModPage.h"
#import "Playlist.h"

UIViewController *ASMSpotiPlaylistSettingsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Playlists" intro:nil sections:@[
        ASMSpotiSection(@"Header", @[
            ASMSpotiOptionRow(@"Artwork background", nil, ASMSpotiKeyPlaylistBackdrop),
        ]),
        ASMSpotiSection(@"Hide in the playlist header", @[
            ASMSpotiHideRow(@"Cover artwork", nil, ASMSpotiHidePlaylistArtwork),
            ASMSpotiHideRow(@"Description", nil, ASMSpotiHidePlaylistDescription),
            ASMSpotiHideRow(@"Creator and collaborators", nil, ASMSpotiHidePlaylistCreator),
            ASMSpotiHideRow(@"Length and saves", nil, ASMSpotiHidePlaylistLength),
        ]),
        ASMSpotiSection(@"Hide playlist buttons", @[
            ASMSpotiHideRow(@"Video", nil, ASMSpotiHidePlaylistVideo),
            ASMSpotiHideRow(@"Add to library", nil, ASMSpotiHidePlaylistAddTo),
            ASMSpotiHideRow(@"Download", nil, ASMSpotiHidePlaylistDownload),
            ASMSpotiHideRow(@"Share", nil, ASMSpotiHidePlaylistShare),
            ASMSpotiHideRow(@"More", nil, ASMSpotiHidePlaylistMore),
        ]),
        ASMSpotiSection(@"Hide above the tracks", @[
            ASMSpotiHideRow(@"Curation pills", nil, ASMSpotiHidePlaylistPills),
            ASMSpotiHideRow(@"Find and sort bar", nil, ASMSpotiHidePlaylistFind),
        ]),
    ] footer:nil];
}
