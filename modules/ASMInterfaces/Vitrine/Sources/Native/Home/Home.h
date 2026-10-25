// Home: the gradient behind the top of the page (HomeGradient.x), off until it is asked for, and
// the settings that shape it (HomeGradientChoices.m, the Gradient page in HomeSettings.m).
#import <UIKit/UIKit.h>

#define ASMVitrineKeyHomeGradient @"asm.interface.vitrine.homeGradient"

// Parts of Home to hide, one switch each (HomeDeclutter.x). An unset switch is off.
#define ASMVitrineHideHomeShortcuts @"asm.interface.vitrine.hide.homeShortcuts"
#define ASMVitrineHideHomePills @"asm.interface.vitrine.hide.homePills"
#define ASMVitrineHideHomePromo @"asm.interface.vitrine.hide.homePromo"
#define ASMVitrineHideHomePreviews @"asm.interface.vitrine.hide.homePreviews"
#define ASMVitrineHideHomeDJ @"asm.interface.vitrine.hide.homeDJ"

// Every setting the gradient is shaped by. One entry per setting in HomeGradientChoices.m holds the
// names the Gradient page offers, the key it is stored under and the one it falls back to, so a
// name and what it does cannot drift apart.
typedef NS_ENUM(NSInteger, ASMVitrineHomeChoice) {
    ASMVitrineHomeChoiceTint,       // which color it fades
    ASMVitrineHomeChoiceStrength,   // how far up or down that color is taken
    ASMVitrineHomeChoiceHeight,     // how far down the page it reaches
    ASMVitrineHomeChoiceCount,
};

NSArray<NSString *> *ASMVitrineHomeChoiceNames(ASMVitrineHomeChoice choice);
NSString *ASMVitrineHomeChoiceKey(ASMVitrineHomeChoice choice);
NSInteger ASMVitrineHomeChoiceDefault(ASMVitrineHomeChoice choice);
// The index set for `choice`: its own default while nothing is set, or while what is set is a name
// this build no longer offers.
NSInteger ASMVitrineHomeChoiceValue(ASMVitrineHomeChoice choice);

UIViewController *ASMVitrineHomeSettingsPage(void);
UIViewController *ASMVitrineHomeGradientPage(void);
