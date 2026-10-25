// The areas the native look's tweaks stripped and Repaint.x keeps transparent when Spotify repaints
// them, each set by the tweak that owns it.
#import <UIKit/UIKit.h>

extern __weak UIView *asm_spotipw_lyricsCardRoot;    // Native/Player/LyricsCard.x
extern __weak UIView *asm_spotipw_lyricsPageRoot;    // Native/Lyrics/LyricsPage.x
extern __weak UIView *asm_spotipw_homeRoot;          // Native/Home/HomeGradient.x, the base surface only
extern __weak UIView *asm_spotipw_npvBackdropRoot;   // Native/Player/Player.x, the plane behind the player
