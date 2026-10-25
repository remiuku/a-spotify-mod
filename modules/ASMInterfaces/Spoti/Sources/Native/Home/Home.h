// Home: the gradient behind the top of the page (HomeGradient.x), off until it is asked for, and
// the settings that shape it (HomeGradientChoices.m, the Gradient page in HomeSettings.m).
#import <UIKit/UIKit.h>

#define ASMSpotiKeyHomeGradient @"asm.interface.spotipw.homeGradient"

// Parts of Home to hide, one switch each (HomeDeclutter.x). An unset switch is off.
#define ASMSpotiHideHomeShortcuts @"asm.interface.spotipw.hide.homeShortcuts"
#define ASMSpotiHideHomePills @"asm.interface.spotipw.hide.homePills"
#define ASMSpotiHideHomePromo @"asm.interface.spotipw.hide.homePromo"
#define ASMSpotiHideHomePreviews @"asm.interface.spotipw.hide.homePreviews"
#define ASMSpotiHideHomeDJ @"asm.interface.spotipw.hide.homeDJ"

// Every setting the gradient is shaped by. One entry per setting in HomeGradientChoices.m holds the
// names the Gradient page offers, the key it is stored under and the one it falls back to, so a
// name and what it does cannot drift apart.
typedef NS_ENUM(NSInteger, ASMSpotiHomeChoice) {
    ASMSpotiHomeChoiceTint,       // which colour it fades
    ASMSpotiHomeChoiceStrength,   // how far up or down that colour is taken
    ASMSpotiHomeChoiceHeight,     // how far down the page it reaches
    ASMSpotiHomeChoiceCount,
};

NSArray<NSString *> *ASMSpotiHomeChoiceNames(ASMSpotiHomeChoice choice);
NSString *ASMSpotiHomeChoiceKey(ASMSpotiHomeChoice choice);
NSInteger ASMSpotiHomeChoiceDefault(ASMSpotiHomeChoice choice);
// The index set for `choice`: its own default while nothing is set, or while what is set is a name
// this build no longer offers.
NSInteger ASMSpotiHomeChoiceValue(ASMSpotiHomeChoice choice);

UIViewController *ASMSpotiHomeSettingsPage(void);
UIViewController *ASMSpotiHomeGradientPage(void);
