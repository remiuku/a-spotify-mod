#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Album.h"

UIViewController *ASMSpotiAlbumSettingsPage(void) {
    NSArray<ASMSpotiModSection *> *sections = @[
        ASMSpotiSection(@"Header", @[
            ASMSpotiOptionRow(@"Artwork background", nil, ASMSpotiKeyAlbumBackdrop),
        ]),
        ASMSpotiSection(@"Hide in the header", @[
            ASMSpotiHideRow(@"Explore (video deck)", nil, ASMSpotiHideAlbumExplore),
            ASMSpotiHideRow(@"Add to library", nil, ASMSpotiHideAlbumAddTo),
            ASMSpotiHideRow(@"Download", nil, ASMSpotiHideAlbumDownload),
            ASMSpotiHideRow(@"More options", nil, ASMSpotiHideAlbumMore),
        ]),
        ASMSpotiNotedSection(@"Hide on the page", @[
            ASMSpotiHideRow(@"More by the artist", nil, ASMSpotiHideAlbumMoreBy),
            ASMSpotiHideRow(@"Related music videos", nil, ASMSpotiHideAlbumVideos),
            ASMSpotiHideRow(@"Concerts", nil, ASMSpotiHideAlbumConcerts),
            ASMSpotiHideRow(@"Merch", nil, ASMSpotiHideAlbumMerch),
            ASMSpotiHideRow(@"You might also like", nil, ASMSpotiHideAlbumYouMightLike),
        ], @"Works only with Spotify in English."),
    ];
    return [[ASMSpotiModPage alloc] initWithTitle:@"Album" intro:nil sections:sections footer:nil];
}
