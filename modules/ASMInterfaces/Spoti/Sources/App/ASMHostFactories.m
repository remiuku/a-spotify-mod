#import "Redesigned/Kit/ASMSpotiRAccent.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Core/ASMHost.h"
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Redesigned/Lyrics/ASMSpotiRKaraokeView.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/Player/Player.h"
#import "Shared/Lyrics/Lyrics.h"
__attribute__((visibility("default"))) UIView *ASMSpotiCreateLyricsView(void) { return [ASMSpotiRKaraokeView new]; }
__attribute__((visibility("default"))) UIViewController *ASMSpotiCreateLyricsSettings(void) {
    NSArray *sections = @[ASMSpotiSection(nil,@[ASMSpotiRLyricsTextSizesRow(), ASMSpotiLyricsWordTimingRow()])];
    return [[ASMSpotiModPage alloc] initWithTitle:@"spoti.pw lyrics" intro:@"Uses the sources and timing configured in a spotify mod." sections:sections footer:nil];
}
__attribute__((visibility("default"))) UIViewController *ASMSpotiCreatePlayerSettings(void) { return ASMSpotiRNowPlayingBarSettingsPage(); }
__attribute__((visibility("default"))) UIViewController *ASMSpotiCreateTabSettings(void) { return ASMSpotiRNavbarSettingsPage(); }
__attribute__((visibility("default"))) UIViewController *ASMSpotiCreateAppearanceSettings(void) { return [[ASMSpotiModPage alloc] initWithTitle:@"Spoti appearance" intro:nil sections:@[ASMSpotiSection(nil,ASMSpotiRAppearanceRows())] footer:ASMSpotiRestartNote]; }
