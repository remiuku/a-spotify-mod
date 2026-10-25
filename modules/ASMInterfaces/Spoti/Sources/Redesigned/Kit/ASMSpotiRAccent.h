// The redesign's accent colour in place of Spotify's green (ASMSpotiRAccent.x), chosen apart from the native
// look's and stored under its own key; unset is #37F200, negative keeps Spotify's own green.
#import <UIKit/UIKit.h>

#define ASMSpotiRKeyAccent @"asm.interface.spotipw.redesign.accent"   // 0xRRGGBB

UIColor *ASMSpotiRAccentColor(void);   // nil while Spotify's own green is kept
NSString *ASMSpotiRAccentLabel(void);  // "#RRGGBB", or the name of Spotify's own
void ASMSpotiRPickAccent(void);        // the system colour picker over the top of the app, stored on the way out

@class ASMSpotiModRow;
NSArray<ASMSpotiModRow *> *ASMSpotiRAppearanceRows(void);   // the accent colour, for the Appearance card
