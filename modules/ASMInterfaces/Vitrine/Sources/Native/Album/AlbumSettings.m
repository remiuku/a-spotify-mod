#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Album.h"

UIViewController *ASMVitrineAlbumSettingsPage(void) {
    NSArray<ASMVitrineModSection *> *sections = @[
        ASMVitrineSection(@"Header", @[
            ASMVitrineOptionRow(@"Artwork background", nil, ASMVitrineKeyAlbumBackdrop),
        ]),
        ASMVitrineSection(@"Hide in the header", @[
            ASMVitrineHideRow(@"Explore (video deck)", nil, ASMVitrineHideAlbumExplore),
            ASMVitrineHideRow(@"Add to library", nil, ASMVitrineHideAlbumAddTo),
            ASMVitrineHideRow(@"Download", nil, ASMVitrineHideAlbumDownload),
            ASMVitrineHideRow(@"More options", nil, ASMVitrineHideAlbumMore),
        ]),
        ASMVitrineNotedSection(@"Hide on the page", @[
            ASMVitrineHideRow(@"More by the artist", nil, ASMVitrineHideAlbumMoreBy),
            ASMVitrineHideRow(@"Related music videos", nil, ASMVitrineHideAlbumVideos),
            ASMVitrineHideRow(@"Concerts", nil, ASMVitrineHideAlbumConcerts),
            ASMVitrineHideRow(@"Merch", nil, ASMVitrineHideAlbumMerch),
            ASMVitrineHideRow(@"You might also like", nil, ASMVitrineHideAlbumYouMightLike),
        ], @"Works only with Spotify in English."),
    ];
    return [[ASMVitrineModPage alloc] initWithTitle:@"Album" intro:nil sections:sections footer:nil];
}
