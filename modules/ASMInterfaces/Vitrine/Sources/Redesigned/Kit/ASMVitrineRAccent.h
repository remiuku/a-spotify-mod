// The redesign's accent color in place of Spotify's green (ASMVitrineRAccent.x), chosen apart from the native
// look's and stored under its own key; unset is #37F200, negative keeps Spotify's own green.
#import <UIKit/UIKit.h>

#define ASMVitrineRKeyAccent @"asm.interface.vitrine.redesign.accent"   // 0xRRGGBB
// The last color picked, kept while a preset is in place so Custom brings it back.
#define ASMVitrineRKeyAccentCustom @"asm.interface.vitrine.redesign.accent.custom"
// The redesign's own green until another is picked; Spotify's is a pick of its own, stored as -1.
#define ASMVitrineRDefaultAccent 0x37F200

UIColor *ASMVitrineRAccentColor(void);   // nil while Spotify's own green is kept
NSInteger ASMVitrineRAccentRGB(void);    // the color in effect, 0xRRGGBB, Spotify's green included

// Plain checkmark (ASMVitrineRPlainCheck.x): a saved song's circled tick as a plain checkmark in the accent. Off until switched
// on, read at launch.
#define ASMVitrineRKeyPlainCheck @"asm.interface.vitrine.redesign.plainCheck"
BOOL ASMVitrineRPlainCheckOn(void);
// The plain checkmark's view, a template image: Follow the cover (Player/PlayerCoverAccent.x) sets its tint.
#define ASMVitrineRPlainCheckIdentifier @"asm.interface.vitrine.plainCheck"

@class ASMVitrineModRow;
NSArray<ASMVitrineModRow *> *ASMVitrineRAppearanceRows(void);   // the accent color, for the Appearance page
