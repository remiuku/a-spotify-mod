// The redesign's Artists page: Apple Music's logo in place of the name on an artist's page, and what the redesign
// takes off the page.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Artist.h"

UIViewController *ASMVitrineRArtistSettingsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Artists" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineNotedSection(@"Apple Music", @[
            ASMVitrineSwitchRow(@"Artist logos", @"In place of the name on an artist's page", ASMVitrineRKeyArtistLogo),
        ], @"Only the artist's name is sent to Apple Music."),
        ASMVitrineSection(@"Hide on an artist's page", @[
            ASMVitrineSwitchRow(@"Videos", @"In the Music list, and in the Video tab", ASMVitrineRKeyArtistHideVideos),
            ASMVitrineSwitchRow(@"Music, Video and Merch tabs", @"Without them the Music list is the page", ASMVitrineRKeyArtistHideTabs),
            ASMVitrineHideRow(@"Artist pick", nil, ASMVitrineRKeyArtistHidePick),
            ASMVitrineHideRow(@"Release countdown", @"The pre-save of an upcoming release", ASMVitrineRKeyArtistHideCountdown),
            ASMVitrineHideRow(@"About", nil, ASMVitrineRKeyArtistHideAbout),
        ]),
    ] footer:nil];
}
