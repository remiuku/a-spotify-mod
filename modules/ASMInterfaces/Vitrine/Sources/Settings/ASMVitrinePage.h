// The base of every page of the mod's, pushable onto Spotify's own navigation stack.
#import <UIKit/UIKit.h>

@interface ASMVitrinePage : UITableViewController
@end

// Registers ASMVitrinePage as one of Spotify's pages; called once, from the settings hook's %ctor.
void ASMVitrineRegisterPages(void);
// Pushes the page if it can go on Spotify's stack, presents it otherwise.
void ASMVitrineShowPage(UIViewController *owner, UIViewController *page);
// Mod Settings, pushed onto the selected tab's stack; `source` is any view on the tab bar.
void ASMVitrineOpenModSettings(UIView *source);
