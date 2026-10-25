#import "Settings/ASMVitrineModPage.h"
#import "Playlist.h"

UIViewController *ASMVitrinePlaylistSettingsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Playlists" intro:nil sections:@[
        ASMVitrineSection(@"Header", @[
            ASMVitrineOptionRow(@"Artwork background", nil, ASMVitrineKeyPlaylistBackdrop),
        ]),
        ASMVitrineSection(@"Hide in the playlist header", @[
            ASMVitrineHideRow(@"Cover artwork", nil, ASMVitrineHidePlaylistArtwork),
            ASMVitrineHideRow(@"Description", nil, ASMVitrineHidePlaylistDescription),
            ASMVitrineHideRow(@"Creator and collaborators", nil, ASMVitrineHidePlaylistCreator),
            ASMVitrineHideRow(@"Length and saves", nil, ASMVitrineHidePlaylistLength),
        ]),
        ASMVitrineSection(@"Hide playlist buttons", @[
            ASMVitrineHideRow(@"Video", nil, ASMVitrineHidePlaylistVideo),
            ASMVitrineHideRow(@"Add to library", nil, ASMVitrineHidePlaylistAddTo),
            ASMVitrineHideRow(@"Download", nil, ASMVitrineHidePlaylistDownload),
            ASMVitrineHideRow(@"Share", nil, ASMVitrineHidePlaylistShare),
            ASMVitrineHideRow(@"More", nil, ASMVitrineHidePlaylistMore),
        ]),
        ASMVitrineSection(@"Hide above the tracks", @[
            ASMVitrineHideRow(@"Curation pills", nil, ASMVitrineHidePlaylistPills),
            ASMVitrineHideRow(@"Find and sort bar", nil, ASMVitrineHidePlaylistFind),
        ]),
    ] footer:nil];
}
