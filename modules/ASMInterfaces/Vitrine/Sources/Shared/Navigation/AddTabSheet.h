// "Add a Tab", the same for either look: a sheet with the tab's name, the page it opens and the icon on
// it, each picked rather than typed (Choose a Link, Choose an Icon). The sheet stores nothing; the look's
// own editor keeps what it hands back in that look's list.
#import <UIKit/UIKit.h>

// The keys of a preset and of the tab handed back.
extern NSString *const ASMVitrineTabTitle;     // NSString
extern NSString *const ASMVitrineTabURI;       // NSString, a spotify: URI
extern NSString *const ASMVitrineTabIcon;      // NSString, an Encore glyph or an SF Symbol
extern NSString *const ASMVitrineTabIconSet;   // ASMVitrineTabIconSetSymbols (TabIcons.h) for an SF Symbol, absent for Encore

// `presets` carry Encore icons; those Spotify's router has nowhere to send are left out. `add` is given
// the tab when Add is tapped, then the sheet goes; Cancel hands back nothing.
void ASMVitrinePresentAddTabSheet(UIViewController *owner, NSArray<NSDictionary *> *presets, void (^add)(NSDictionary *tab));
// The same sheet as Edit Tab, over `tab` (the keys above): Save hands the tab back as it now is, and a Remove
// Tab row under the rest runs `remove` once an action sheet has asked.
void ASMVitrinePresentEditTabSheet(UIViewController *owner, NSArray<NSDictionary *> *presets, NSDictionary *tab,
                           void (^save)(NSDictionary *tab), void (^remove)(void));
