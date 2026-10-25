// The native look's appearance: the AMOLED background (Amoled.x), the accent colour in place of
// Spotify's green (Accent.x), the soft top edge (EdgeEffect.x) and Repaint.x, which keeps what the
// native tweaks stripped transparent when Spotify repaints it. The switches are off until asked for.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyAmoled @"asm.interface.spotipw.amoled"
#define ASMSpotiKeyAccent @"asm.interface.spotipw.accent"   // 0xRRGGBB; unset or negative keeps Spotify's own green

UIColor *ASMSpotiAccentColor(void);   // nil while Spotify's own green is kept
NSString *ASMSpotiAccentLabel(void);  // "#RRGGBB", or the name of Spotify's own
void ASMSpotiPickAccent(void);        // the system colour picker over the top of the app, stored on the way out

@class ASMSpotiModRow;
NSArray<ASMSpotiModRow *> *ASMSpotiNativeAppearanceRows(void);   // AMOLED and the accent colour, for the Appearance card
