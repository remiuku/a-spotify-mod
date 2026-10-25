// Spotify's own list look, for every page of the mod's: a 13pt white title over an 11pt grey
// subtitle on #121212, 38pt uppercase section headers, green switches.
#import <UIKit/UIKit.h>

UIColor *ASMSpotiGrey(void);
UIColor *ASMSpotiGreen(void);
UIColor *ASMSpotiRed(void);
UIColor *ASMSpotiPageBackground(void);
UIColor *ASMSpotiCardBackground(void);
UIFont *ASMSpotiTitleFont(void);
UIFont *ASMSpotiSubtitleFont(void);
// Takes the 13pt and 11pt fonts off Spotify's own settings list, once, so the pages match it.
void ASMSpotiAdoptFonts(UIView *list, UIView *exclude);

UIImageView *ASMSpotiSymbolView(NSString *name, CGFloat size, UIImageSymbolWeight weight, CGFloat box);
// A symbol on a rounded grey square, the leading icon of a row that opens a page.
UIImage *ASMSpotiTileImage(NSString *symbol);
// A grey note in a wrapper view, for a table header or footer; ASMSpotiFitNote sizes it to its text.
UIView *ASMSpotiNote(NSString *text);
void ASMSpotiFitNote(UITableView *table, UIView *wrapper, CGFloat top, CGFloat bottom);
// The now playing bar and the tab bar float over the content, so a page insets itself under them.
void ASMSpotiInsetForBars(UITableView *table);

extern const CGFloat ASMSpotiSectionHeaderHeight;
extern const CGFloat ASMSpotiSectionGap;   // above a section with no header, so its card does not touch the one before
void ASMSpotiFillCell(UITableViewCell *cell, NSString *title, NSString *subtitle, UIColor *color, NSString *symbolName);
UIView *ASMSpotiSectionHeader(UITableView *table, NSString *title);
UIView *ASMSpotiSectionFooter(UITableView *table, NSString *text);
CGFloat ASMSpotiSectionFooterHeight(UITableView *table, NSString *text);
UITableViewCell *ASMSpotiDequeueCell(UITableView *table, NSString *identifier);

void ASMSpotiOpenURL(NSString *url);
extern NSString *const ASMSpotiSiteURL;
extern NSString *const ASMSpotiRepoURL;
// The controller on top of the key window, through whatever is presented over it.
UIViewController *ASMSpotiTopController(void);
