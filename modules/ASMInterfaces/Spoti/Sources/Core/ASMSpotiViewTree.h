// Walking and reading Spotify's view trees.
#import <UIKit/UIKit.h>

void ASMSpotiForEachView(UIView *view, void (^fn)(UIView *));
CGRect ASMSpotiFrameIn(UIView *view, UIView *target);
// Whether `view` sits under `root`, stopping at a visual effect view on the way up.
BOOL ASMSpotiIsInside(UIView *view, UIView *root);
// The first wide stack view under `host` with at least two arranged children: a player row, or
// the row of items in the tab bar.
UIStackView *ASMSpotiRowIn(UIView *host);
// Whether any view under `root` has `marker` in its class name.
BOOL ASMSpotiHasClass(UIView *root, NSString *marker);

// Artwork, glyphs, text and thin lines (progress bar) keep their colour, everything else goes clear.
BOOL ASMSpotiKeepsColor(UIView *view);
void ASMSpotiStripBackgrounds(UIView *view);
BOOL ASMSpotiIsVisibleColor(CGColorRef color);
BOOL ASMSpotiIsLightColor(CGColorRef color);
// Spotify's base surface: the neutral #121212 it paints its pages with, or the black AMOLED turns
// that into.
BOOL ASMSpotiIsBaseSurface(CGColorRef color);
// A painted, card-sized view: the now playing bar's card, for one.
BOOL ASMSpotiLooksLikeCard(UIView *view, CGColorRef color);
