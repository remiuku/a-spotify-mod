// The native look's navbar: Spotify's own tab bar composed (Navbar.x, hooked from TabBarHooks.x): an
// ordered list of entries, each a dictionary. An entry with a URI is a tab of the mod's own; one without names
// one of Spotify's, by the label under its icon. No list at all is Spotify's order, all shown.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyNavbar @"asm.interface.vitrine.navbar"

extern NSString *const ASMVitrineNavbarID;      // NSString, the entry's identity
extern NSString *const ASMVitrineNavbarTitle;   // NSString, the name in the settings list and under the icon
extern NSString *const ASMVitrineNavbarURI;     // NSString, the mod's own tabs only: what a tap opens
extern NSString *const ASMVitrineNavbarIcon;    // NSString, an SPTEncoreIcon class method such as "podcasts", or an SF Symbol
extern NSString *const ASMVitrineNavbarIconSet; // NSString, ASMVitrineTabIconSetSymbols when the icon is an SF Symbol; none is Encore
extern NSString *const ASMVitrineNavbarHidden;  // NSNumber
NSArray<NSDictionary *> *ASMVitrineNavbarLayout(void);
void ASMVitrineSetNavbarLayout(NSArray<NSDictionary *> *layout);
// The tabs set apart at the trailing end of the bar (Split tabs), by their entries' identities.
NSArray<NSString *> *ASMVitrineNavbarSplit(void);
void ASMVitrineSetNavbarSplit(NSArray<NSString *> *split);
// Spotify's own tabs in Spotify's order, as Navbar.x last saw them on the bar.
NSArray<NSString *> *ASMVitrineNavbarStock(void);
void ASMVitrineSetNavbarStock(NSArray<NSString *> *stock);

// Navbar.x, called from the tab bar's layout passes in TabBarHooks.x.
void ASMVitrineComposeTabBar(UIView *tabBar);
void ASMVitrineLogTabBarRow(UIView *tabBar);
// Lays the bar out again after the Navbar page changes something, so it does not wait for a touch.
void ASMVitrineRefreshTabBar(void);

UIViewController *ASMVitrineNavbarSettingsPage(void);   // the tab editor, in Mod Settings
UIViewController *ASMVitrineNavbarEditorPage(void);     // the tab editor alone, for the welcome tour
