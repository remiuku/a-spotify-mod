#import "Redesigned/Home/Home.h"
#import "Shared/Fonts/Fonts.h"
#import "Redesigned/Album/Album.h"
#import "Redesigned/Artist/Artist.h"
#import "Redesigned/Kit/ASMVitrineRAccent.h"
#import "Redesigned/Lyrics/LyricsLook.h"
#import "Core/ASMHost.h"
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Redesigned/Lyrics/ASMVitrineRKaraokeView.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/Player/Player.h"
#import "Shared/Lyrics/Lyrics.h"
__attribute__((visibility("default"))) UIView *ASMVitrineCreateLyricsView(void) { return [ASMVitrineRKaraokeView new]; }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateLyricsSettings(void) {
    NSArray *sections = @[ASMVitrineSection(nil,@[ASMVitrineRLyricsTextSizesRow(), ASMVitrineLyricsWordTimingRow(), ASMVitrineLyricsRomanisedRow(), ASMVitrineLyricsDelayRow()])];
    return ASMVitrineRLyricsSettingsPage(@"Vitrine lyrics",@"Uses the sources and timing configured in a spotify mod.",sections);
}
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreatePlayerSettings(void) { return ASMVitrineRPlayerSettingsPage(@[]); }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateTabSettings(void) { return ASMVitrineRNavbarSettingsPage(); }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateAppearanceSettings(void) { return [[ASMVitrineModPage alloc] initWithTitle:@"Vitrine appearance" intro:nil sections:@[ASMVitrineSection(nil,ASMVitrineRAppearanceRows()), ASMVitrineSection(nil,ASMVitrineAppFontRows())] footer:ASMVitrineRestartNote]; }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateHomeSettings(void) { return ASMVitrineRHomeSettingsPage(); }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateAlbumSettings(void) { return ASMVitrineRAlbumSettingsPage(); }
__attribute__((visibility("default"))) UIViewController *ASMVitrineCreateArtistSettings(void) { return ASMVitrineRArtistSettingsPage(); }
