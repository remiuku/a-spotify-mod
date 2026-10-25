// The redesign's navbar: the glass tab bar (TabBar.x) over Spotify's own, composed from its own list
// (Navbar.x, NavbarLayout.m), which the redesign keeps apart from the native look's: an ordered list of
// entries, each a dictionary. An entry with a URI is a tab of the mod's own; one without names
// one of Spotify's, by the label under its icon. No list at all is Spotify's order, all shown.
#import <UIKit/UIKit.h>

#define ASMVitrineRKeyNavbar @"asm.interface.vitrine.redesign.navbar"
// Icons only on the glass bar. Off unless set; applies as soon as the bar lays out again.
#define ASMVitrineRKeyNavbarHideLabels @"asm.interface.vitrine.redesign.navbar.hideLabels"

extern NSString *const ASMVitrineRNavbarID;      // NSString, the entry's identity
extern NSString *const ASMVitrineRNavbarTitle;   // NSString, the name in the settings list and under the icon
extern NSString *const ASMVitrineRNavbarURI;     // NSString, the mod's own tabs only: what a tap opens
extern NSString *const ASMVitrineRNavbarIcon;    // NSString, an SPTEncoreIcon class method such as "podcasts", or an SF Symbol
extern NSString *const ASMVitrineRNavbarIconSet; // NSString, ASMVitrineTabIconSetSymbols when the icon is an SF Symbol; none is Encore
extern NSString *const ASMVitrineRNavbarHidden;  // NSNumber
NSArray<NSDictionary *> *ASMVitrineRNavbarLayout(void);
void ASMVitrineRSetNavbarLayout(NSArray<NSDictionary *> *layout);
// The tabs set apart at the trailing end of the bar (Split tabs), by their entries' identities.
NSArray<NSString *> *ASMVitrineRNavbarSplit(void);
void ASMVitrineRSetNavbarSplit(NSArray<NSString *> *split);
// Spotify's own tabs in Spotify's order, as Navbar.x last saw them on the bar.
NSArray<NSString *> *ASMVitrineRNavbarStock(void);
void ASMVitrineRSetNavbarStock(NSArray<NSString *> *stock);
// What a tab of the mod's own opens: its URI as typed or pasted, share links made spotify: URIs, and
// the URIs of presets that never opened (spotify:collection:playlists, up to 0.20) moved to the ones
// that replaced them, so a tab saved back then works without being added again.
NSURL *ASMVitrineRNavbarTabURL(NSString *uri);

// Navbar.x, called from the tab bar's layout passes in TabBar.x.
void ASMVitrineRComposeTabBar(UIView *tabBar);
void ASMVitrineRLogTabBarRow(UIView *tabBar);
// Lays the bar out again after the Navbar page changes something, so it does not wait for a touch.
void ASMVitrineRRefreshTabBar(void);
// Whether a tab of the composed row is one of the split tabs at its trailing end, for TabBar.x's second bar.
BOOL ASMVitrineRTabIsApart(UIView *item);
// The tab of the mod's own whose page is on screen, which the glass bar shows selected; nil when none is.
UIView *ASMVitrineRNavbarLitTab(void);
// A tap on one of Spotify's tabs: no tab of the mod's own is lit any more.
void ASMVitrineRNavbarForgetTab(void);

// The glass bar minimizes as a page scrolls down (TabBarMinimize.x): it shrinks to two of its tabs, the
// now playing card coming down between them. On unless switched off; read as each scroll goes.
#define ASMVitrineRKeyNavbarMinimize @"asm.interface.vitrine.redesign.navbar.minimize"
BOOL ASMVitrineRTabBarMinimized(void);
// TabBar.x lays both bars out for it, the now playing bar in the same animation, at once; asked for inside an
// animation, on the main queue's next turn (ASMVitrineRTabBarMinimized changes then too). `animated` NO is a cut, made
// at once.
void ASMVitrineRSetTabBarMinimized(BOOL minimized, BOOL animated);
// The room between the minimized bar's two tabs, `height` high and centered on them, in `host`'s
// coordinates: where the now playing card goes. CGRectNull while the bar is not minimized or not on screen.
CGRect ASMVitrineRTabBarInlineSlot(UIView *host, CGFloat height);

// A tab's glyph as the glass bar draws it, white, filled when `active` (TabBar.x), for the Tab bar page.
UIImage *ASMVitrineRNavbarGlyph(NSDictionary *entry, BOOL active);
// Lets a laid out bar's titles shrink a little before UIKit cuts them short (TabBar.x), for the page's preview too.
void ASMVitrineRShrinkTabTitles(UIView *bar);

UIViewController *ASMVitrineRNavbarSettingsPage(void);   // the tab editor, in Mod Settings
UIViewController *ASMVitrineRNavbarEditorPage(void);     // the tab editor alone, for the welcome tour
