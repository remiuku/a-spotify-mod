// The redesign's Albums page: Apple Music's animated covers on album pages, whether their downloads run in Low
// Data Mode, and what the redesign takes off the page.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Album.h"

UIViewController *ASMVitrineRAlbumSettingsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Albums" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineNotedSection(@"Apple Music", @[
            ASMVitrineSwitchRow(@"Animated covers", @"At the top of an album that has one, about 5 MB each", ASMVitrineRKeyAlbumMotion),
            ASMVitrineOptionRow(@"Download in Low Data Mode", nil, ASMVitrineKeyMotionLowData),
        ], @"Only the album's name is sent to Apple Music. A cover stays still in Low Power Mode."),
        ASMVitrineSection(@"Hide on an album's page", @[
            ASMVitrineSwitchRow(@"Repeated track artists", @"The artist under a track when it is the album's own", ASMVitrineRKeyAlbumHideTrackArtists),
        ]),
        ASMVitrineNotedSection(@"Hide under an album's tracks", @[
            ASMVitrineSwitchRow(@"More by the artist", nil, ASMVitrineRKeyAlbumHideMoreBy),
            ASMVitrineSwitchRow(@"Related music videos", nil, ASMVitrineRKeyAlbumHideVideos),
            ASMVitrineSwitchRow(@"Concerts", nil, ASMVitrineRKeyAlbumHideConcerts),
            ASMVitrineSwitchRow(@"Merch", nil, ASMVitrineRKeyAlbumHideMerch),
            ASMVitrineSwitchRow(@"You might also like", nil, ASMVitrineRKeyAlbumHideYouMightLike),
            ASMVitrineSwitchRow(@"Everything else", @"Any other section Spotify sends", ASMVitrineRKeyAlbumHideOther),
        ], @"Sections are told apart by their English names. With Spotify in another language, Everything else "
           @"covers them all."),
    ] footer:nil];
}
