// The native look's appearance: the AMOLED background (Amoled.x), the accent color in place of
// Spotify's green (Accent.x), the soft top edge (EdgeEffect.x) and Repaint.x, which keeps what the
// native tweaks stripped transparent when Spotify repaints it. The switches are off until asked for.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyAmoled @"asm.interface.vitrine.amoled"
#define ASMVitrineKeyAccent @"asm.interface.vitrine.accent"   // 0xRRGGBB; unset or negative keeps Spotify's own green
// The last color picked, kept while a preset is in place so Custom brings it back.
#define ASMVitrineKeyAccentCustom @"asm.interface.vitrine.accent.custom"

UIColor *ASMVitrineAccentColor(void);   // nil while Spotify's own green is kept
NSInteger ASMVitrineAccentRGB(void);    // the color in effect, 0xRRGGBB, Spotify's green included

@class ASMVitrineModRow;
NSArray<ASMVitrineModRow *> *ASMVitrineNativeAppearanceRows(void);   // AMOLED and the accent color, for the Appearance page
