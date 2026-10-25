// The pages of Mod Settings that bring the layers together: what each look offers is its own
// (Shared/, Native/, Redesigned/), and which of it a page shows is decided here, from the stored
// Redesigned UI switch, so a page opened after flipping it shows what the restart will bring.
#import <UIKit/UIKit.h>

@class ASMVitrineModRow;

// Redesigned UI, the one switch between the two looks, and what its ⓘ reads out.
void ASMVitrineSetRedesignedUI(BOOL on);
extern NSString *const ASMVitrineRedesignedUIInfo;
// Below iOS 26: what turning the redesign on risks there, for the switch's alert and the tour.
NSString *ASMVitrineRedesignUntestedWarning(void);

// Redesigned UI as a glowing switch with its ⓘ, offering to restart Spotify when flipped; below iOS 26 it
// warns first. It leads Mod Settings' main page.
ASMVitrineModRow *ASMVitrineRedesignedUIRow(void);
UIViewController *ASMVitrineAppearancePage(void);   // the stored look's accent and AMOLED, the font and the app icon
UIViewController *ASMVitrinePlayerSettingsPage(void);
UIViewController *ASMVitrineLyricsSettingsPage(void);   // with Sing (Shared/Sing) on it
UIViewController *ASMVitrineNavbarPage(void);       // the tab editor of whichever look is stored
