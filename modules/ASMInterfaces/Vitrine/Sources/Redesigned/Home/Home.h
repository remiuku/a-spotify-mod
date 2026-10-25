// The Home redesign: Spotify's Home page kept, with its controllers, lists and cards, decluttered to a
// music app on black and restyled from the Kit. Its settings are the Home page of Mod Settings (HomeSettings.m).
//
//     HomeSections.x   an allow list of the feed's sections: the shortcuts grid, the DJ and the shelves of
//                      cards stay unless switched off; video and playlist previews and the song suggestions
//                      stay only when switched on; episode cards and any new kind collapse. The DJ loses its
//                      heading, and the flags the redesign forces on Home
//     HomeShelves.m    a shelf's identity from its heading, the shelves seen lately and which are hidden
//     HomeFeed.swift   every section's shelf identity from Spotify's model of the feed, built or not
//     HomeSettings.m   the Home page of Mod Settings: Top picks, what stays on Home, one switch per shelf
//     HomeHeader.x     a large title where the filter pills were, the avatar at the trailing edge, no scrim
//     HomeHeadings.x   the shelves' headings in the Music app's size, drawn over Spotify's
//     HomeCards.x      the Encore button every card is: shortcut tiles (HomeTiles.m), continuous corners on the
//                      shelf covers, the DJ card at the card radius without its talking transcript
//     HomeTiles.m      a shortcut tile's picture run across the tile, blurred behind its title
//     HomeTopPicks.x   Top picks: the shelf nearest the top drawn large and moved above the shortcuts, each card
//                      the cover over a footer in its color
//     HomePerf.x       FLEX builds: the frames of each scroll of Home and the time the hooks above took
//
// Every hook installs only while Redesigned UI is on (ASMVitrineRedesignedUI).
// Threading: main thread only.
#import <UIKit/UIKit.h>

// The Home look (the first row of the Home page): Top picks and the color behind it, the tinted glass shortcut
// pills with their bold names, the title's glass pill with the filter menu and the page's color. Off, none of
// those hooks install and Home has the plain shortcuts and title. On until switched off; read at launch
// (ASMVitrineRHomeLook).
#define ASMVitrineRKeyHomeLook @"asm.interface.vitrine.redesign.home.look"
BOOL ASMVitrineRHomeLook(void);
// Top picks (HomeTopPicks.x): the shelf nearest the top drawn large above the shortcuts. On until switched off.
#define ASMVitrineRKeyHomeTopPicks @"asm.interface.vitrine.redesign.home.topPicks"
// The shelf Top picks draws, by its identity (ASMVitrineRHomeShelfIdentity); unset, the first shelf.
#define ASMVitrineRKeyHomeTopPicksFrom @"asm.interface.vitrine.redesign.home.topPicksFrom"
// The footer of a large card in its cover's color. On until switched off; off, the footer is the plain surface.
#define ASMVitrineRKeyHomeTopPicksColour @"asm.interface.vitrine.redesign.home.topPicksColour"
// Parts of Home hidden when set (HomeSections.x): the shortcuts grid and the DJ.
#define ASMVitrineRKeyHomeHideShortcuts @"asm.interface.vitrine.redesign.home.hide.shortcuts"
#define ASMVitrineRKeyHomeHideDJ @"asm.interface.vitrine.redesign.home.hide.dj"
// Parts of Home the redesign drops unless these are set: Spotify's carousel of songs to try and rate
// (Home_ContentEvaluationListElementKit) and its video and playlist previews (Discovery_MediumDensityCardKit,
// Discovery_PreviewElement).
#define ASMVitrineRKeyHomeSongSuggestions @"asm.interface.vitrine.redesign.home.songSuggestions"
#define ASMVitrineRKeyHomePreviews @"asm.interface.vitrine.redesign.home.previews"
// A shelf hidden when set: this prefix and the shelf's identity (ASMVitrineRHomeShelfHideKey).
#define ASMVitrineRKeyHomeShelfHidePrefix @"asm.interface.vitrine.redesign.home.hide.shelf."
// The shelves seen lately: identity -> the date it was last on Home (HomeShelves.m).
#define ASMVitrineRKeyHomeShelvesSeen @"asm.interface.vitrine.redesign.home.shelvesSeen"

@class ASMVitrineModRow;
ASMVitrineModRow *ASMVitrineRHomeTopPicksRow(void);
UIViewController *ASMVitrineRHomeSettingsPage(void);   // for Mod Settings (App/ModSettings.x)

// HomeShelves.m. A shelf's identity is what its heading says, read off its labels after the shelf is laid out:
// the small line over the title when there is one ("More like …", for any artist), else the title ("Recents",
// an artist's name). nil while the shelf has no heading to read. Language-bound, as the headings are.
NSString *ASMVitrineRHomeShelfIdentity(UIView *shelf);
// The identity a heading of these two lines gives: "More like …" for "More like" over "Chief Keef", else the title.
NSString *ASMVitrineRHomeShelfIdentityFrom(NSString *small, NSString *title);
NSString *ASMVitrineRHomeShelfTitle(UIView *shelf);        // the heading's title alone ("Chief Keef" under "More like")
void ASMVitrineRHomeNoteShelf(NSString *identity);         // seen on Home now
NSArray<NSString *> *ASMVitrineRHomeShelvesSeen(void);     // seen within 30 days, in the order first seen
NSString *ASMVitrineRHomeShelfHideKey(NSString *identity);
BOOL ASMVitrineRHomeShelfHidden(NSString *identity);
NSString *ASMVitrineRHomeTopPicksFrom(void);               // the identity stored under ASMVitrineRKeyHomeTopPicksFrom, nil for the first shelf

// Whether HomeSections.x has collapsed the section in this cell.
BOOL ASMVitrineRHomeSectionCollapsed(UIView *cell);
// Has the page's list measure the section around `view` again, on the next turn of the run loop: for a shelf
// whose heading came in after the list sized it (HomeSections.x).
void ASMVitrineRHomeMeasureAgain(UIView *view);

// Styles a shortcut tile (id=Shortcut.Card.Home) and keeps its picture in step with its cover (HomeTiles.m).
void ASMVitrineRHomeStyleTile(UIView *tile);
// Takes a tile's styling off a button Spotify has reused for something else (a shelf card), which would wear the
// tile's surface and rim otherwise.
void ASMVitrineRHomeUnstyleTile(UIView *button);
// A tile's corner radius: 14, measured off the reference's 48pt pills (41px at 3px/pt), continuous.
extern const CGFloat ASMVitrineRHomeTileRadius;

// The surface color a cover gives a tile or a card (Kit/ASMVitrineRPalette.h, +tintForImage:), kept by the image while it
// lives: from the cache at once, else worked out off the main thread. nil when the image has no bitmap to read.
// Main thread, calls back on it.
void ASMVitrineRHomeTintForCover(UIImage *image, void (^completion)(UIColor *color));

// Styles a shelf card (id=Components.UI.HomeCard) drawn large by Top picks (HomeTopPicks.x): a footer in the
// cover's color under the cover. NO, and the card left as Spotify's, for one at Spotify's own size.
BOOL ASMVitrineRHomeStyleLargeCard(UIView *card);

// Whether `view` is in the shelf Top picks draws large (HomeTopPicks.x), whose heading goes (HomeHeadings.x).
BOOL ASMVitrineRHomeInTopPicks(UIView *view);
// Spotify's "Show all" of the shelf Top picks draws, while the shelf is on screen and offers one, and the shelf's
// title with it: the header's menu offers it (HomeHeader.x), the heading it sits in being gone.
UIControl *ASMVitrineRHomeTopPicksShowAll(NSString **title);
// The page's color from the first large card's cover (HomeHeader.x draws it behind the title, fading to black);
// nil for none.
void ASMVitrineRHomeSetPageTint(UIColor *color);

// FLEX builds only (HomePerf.x): a hook takes the time as it starts and hands it back as it ends; outside
// a FLEX build Begin returns 0 and End does nothing.
typedef NS_ENUM(NSUInteger, ASMVitrineRHomeProbe) {
    ASMVitrineRHomeProbeSections,
    ASMVitrineRHomeProbeHeader,
    ASMVitrineRHomeProbeHeadings,
    ASMVitrineRHomeProbeCards,
    ASMVitrineRHomeProbeTiles,
    // The hooks of the Home look (HomeCards.x, HomeTopPicks.x, HomeTiles.m).
    ASMVitrineRHomeProbeLabels,          // UILabel setText:/setAttributedText: hook, every call
    ASMVitrineRHomeProbeLabelsMatched,   // ... the ones under a Home card or tile, which mark the button
    ASMVitrineRHomeProbeFrames,          // the playing indicator's setHidden: hook (a tile's pass asked for again)
    ASMVitrineRHomeProbeListAttrs,       // the page list's layoutAttributesForElementsInRect:/ForItem: hooks
    ASMVitrineRHomeProbeShelfLayout,     // the shelf's layoutSubviews hook (TouchCancellingCollectionView)
    ASMVitrineRHomeProbeLargeCard,       // ASMVitrineRHomeStyleLargeCard
    ASMVitrineRHomeProbeTint,            // ASMVitrineRHomeTintForCover asks (cache misses go off the main thread)
    ASMVitrineRHomeProbeFeed,            // the walk of the feed's model for the shelves' headings (HomeFeed.swift)
    ASMVitrineRHomeProbeCount,
};
CFTimeInterval ASMVitrineRHomeProbeBegin(void);
void ASMVitrineRHomeProbeEnd(ASMVitrineRHomeProbe probe, CFTimeInterval began);
