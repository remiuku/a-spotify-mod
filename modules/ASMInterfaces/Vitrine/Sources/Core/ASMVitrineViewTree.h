// Walking and reading Spotify's view trees.
#import <UIKit/UIKit.h>

void ASMVitrineForEachView(UIView *view, void (^fn)(UIView *));
CGRect ASMVitrineFrameIn(UIView *view, UIView *target);
// Whether `view` sits under `root`, stopping at a visual effect view on the way up.
BOOL ASMVitrineIsInside(UIView *view, UIView *root);
// Whether no view from `view` up to (not including) `root` is hidden.
BOOL ASMVitrineShownUnder(UIView *view, UIView *root);
// The first wide stack view under `host` with at least two arranged children: a player row, or
// the row of items in the tab bar.
UIStackView *ASMVitrineRowIn(UIView *host);
// Whether any view under `root` has `marker` in its class name.
BOOL ASMVitrineHasClass(UIView *root, NSString *marker);

// Artwork, glyphs, text and thin lines (progress bar) keep their color, everything else goes clear.
BOOL ASMVitrineKeepsColor(UIView *view);
void ASMVitrineStripBackgrounds(UIView *view);
BOOL ASMVitrineIsVisibleColor(CGColorRef color);
BOOL ASMVitrineIsLightColor(CGColorRef color);
// Spotify's base surface: the neutral #121212 it paints its pages with, or the black AMOLED turns
// that into.
BOOL ASMVitrineIsBaseSurface(CGColorRef color);
// A painted, card-sized view: the now playing bar's card, for one.
BOOL ASMVitrineLooksLikeCard(UIView *view, CGColorRef color);
