// The look of every page of the mod's, in the dark appearance: cards of #1C1C1E on black, 13pt titles over 11pt
// gray subtitles in Spotify's typeface, 11pt uppercase section headers and notes, a white symbol on a colored
// rounded square leading a row, white chevrons, switches in the look's accent color. The text follows Dynamic
// Type through the accessibility sizes, and the app font of Shared/Fonts.
#import <UIKit/UIKit.h>

UIColor *ASMVitrineGrey(void);   // the secondary label's gray
UIColor *ASMVitrineGreen(void);
UIColor *ASMVitrineOnAccent(void); // black or white text on the accent
UIColor *ASMVitrineAccentMark(void); // a visible accent mark on a dark card
UIColor *ASMVitrineRed(void);
UIColor *ASMVitrinePageBackground(void);
UIColor *ASMVitrineCardBackground(void);
UIFont *ASMVitrineTitleFont(void);      // a row's title and value, 13pt
UIFont *ASMVitrineSubtitleFont(void);   // subtitles, section headers, footers and notes, 11pt
// Both grow through the accessibility sizes with no cap. A control beside a row's title, or text inside a
// drawing of fixed size, caps its copy so the title keeps its room.
UIFont *ASMVitrineCappedFont(UIFont *font, CGFloat largest);
BOOL ASMVitrineAccessibilityTextSize(void);   // an accessibility size, where a row's value goes under its title
// A slider row's text, laid out by hand: the title with its value at the trailing edge, or at the accessibility
// sizes the title wrapped across the row with the value under it, then the subtitle when it has one. The
// layout returns the y under the text; the height is the same text measured at the same width.
CGFloat ASMVitrineSliderTextHeight(NSString *title, NSString *subtitle, CGFloat width);
CGFloat ASMVitrineLayOutSliderText(UILabel *title, UILabel *value, UILabel *subtitle, CGFloat x, CGFloat y, CGFloat width);
// Takes the 13pt title font off Spotify's own settings list, once, for the Mod Settings row the mod adds to it
// (App/ModSettings.x), which reads as one of Spotify's rows; ASMVitrineSpotifyListFont hands it out.
void ASMVitrineAdoptFonts(UIView *list, UIView *exclude);
UIFont *ASMVitrineSpotifyListFont(void);

UIImageView *ASMVitrineSymbolView(NSString *name, CGFloat size, UIImageSymbolWeight weight, CGFloat box);
// A white symbol on a rounded square of `color`, the leading icon of a row; ASMVitrineTileImage's square is gray.
UIImage *ASMVitrineTileImageTinted(NSString *symbol, UIColor *color);
UIImage *ASMVitrineTileImage(NSString *symbol);
// The chevron of a row that opens a page, in the tertiary label's gray.
UIImageView *ASMVitrineChevronView(void);
// The separator inset of a row led by a tile, so the hairline starts under the title as in Settings.
extern const CGFloat ASMVitrineTileRowInset;
// A gray note in a wrapper view, for a table header or footer; ASMVitrineFitNote sizes it to its text.
UIView *ASMVitrineNote(NSString *text);
void ASMVitrineFitNote(UITableView *table, UIView *wrapper, CGFloat top, CGFloat bottom);
// The now playing bar and the tab bar float over the content, so a page insets itself under them.
void ASMVitrineInsetForBars(UITableView *table);

CGFloat ASMVitrineSectionHeaderHeight(void);   // grows with the header's text
extern const CGFloat ASMVitrineSectionGap;   // above a section with no header, so its card does not touch the one before
void ASMVitrineFillCell(UITableViewCell *cell, NSString *title, NSString *subtitle, UIColor *color, NSString *symbolName);
UIView *ASMVitrineSectionHeader(UITableView *table, NSString *title);
UIView *ASMVitrineSectionFooter(UITableView *table, NSString *text);
CGFloat ASMVitrineSectionFooterHeight(UITableView *table, NSString *text);
UITableViewCell *ASMVitrineDequeueCell(UITableView *table, NSString *identifier);

void ASMVitrineOpenURL(NSString *url);
extern NSString *const ASMVitrineRepoURL;
// The controller on top of the key window, through whatever is presented over it.
UIViewController *ASMVitrineTopController(void);
