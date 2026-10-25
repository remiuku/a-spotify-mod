// The native look's navbar: Spotify's own tab bar composed (Navbar.x, hooked from TabBarHooks.x): an
// ordered list of entries, each a dictionary. An entry with a URI is a tab of the mod's own; one without names
// one of Spotify's, by the label under its icon. No list at all is Spotify's order, all shown.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyNavbar @"asm.interface.spotipw.navbar"

extern NSString *const ASMSpotiNavbarID;      // NSString, the entry's identity
extern NSString *const ASMSpotiNavbarTitle;   // NSString, the name in the settings list and under the icon
extern NSString *const ASMSpotiNavbarURI;     // NSString, the mod's own tabs only: what a tap opens
extern NSString *const ASMSpotiNavbarIcon;    // NSString, an SPTEncoreIcon class method such as "podcasts"
extern NSString *const ASMSpotiNavbarHidden;  // NSNumber
NSArray<NSDictionary *> *ASMSpotiNavbarLayout(void);
void ASMSpotiSetNavbarLayout(NSArray<NSDictionary *> *layout);
// Spotify's own tabs in Spotify's order, as Navbar.x last saw them on the bar.
NSArray<NSString *> *ASMSpotiNavbarStock(void);
void ASMSpotiSetNavbarStock(NSArray<NSString *> *stock);

// Navbar.x, called from the tab bar's layout passes in TabBarHooks.x.
void ASMSpotiComposeTabBar(UIView *tabBar);
void ASMSpotiLogTabBarRow(UIView *tabBar);
// Lays the bar out again after the Navbar page changes something, so it does not wait for a touch.
void ASMSpotiRefreshTabBar(void);

UIViewController *ASMSpotiNavbarSettingsPage(void);   // the tab editor, in Mod Settings
UIViewController *ASMSpotiNavbarEditorPage(void);     // the tab editor alone, for the welcome tour
