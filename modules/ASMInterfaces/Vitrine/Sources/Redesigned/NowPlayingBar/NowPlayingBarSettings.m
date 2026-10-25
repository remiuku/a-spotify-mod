// The now playing bar's rows of the redesign, the Mini player section of the Player page
// (Redesigned/Player/PlayerSettings.m puts them there).
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Redesigned/Navbar/Navbar.h"
#import "NowPlayingBar.h"

NSArray<ASMVitrineModRow *> *ASMVitrineRNowPlayingBarRows(void) {
    // The tab bar reads the switch as each scroll goes; a bar minimized when it goes off grows back at once.
    ASMVitrineModRow *minimize = ASMVitrineSwitchRow(@"Apple Music style", @"Between two tabs as a page scrolls down", ASMVitrineRKeyNavbarMinimize);
    minimize.changed = ^(BOOL on) {
        if (!on) ASMVitrineRSetTabBarMinimized(NO, NO);
        ASMVitrineRRefreshTabBar();
    };
    ASMVitrineModRow *inlineConnect = ASMVitrineOptionRow(@"Device button", @"Kept on the bar between the tabs", ASMVitrineRKeyBarInlineConnect);
    inlineConnect.waitsOn = ASMVitrineRKeyNavbarMinimize;
    return @[
        minimize,
        inlineConnect,
        ASMVitrineHideRow(@"Hide the device button", @"On the full now playing bar", ASMVitrineRHideBarConnect),
        // Spotify's own flag for the bar's save button, forced off: Spotify leaves the button out.
        ASMVitrineKillRow(@"Hide the like button", @"ios-feature-nowplayingbar.add_button"),
    ];
}
