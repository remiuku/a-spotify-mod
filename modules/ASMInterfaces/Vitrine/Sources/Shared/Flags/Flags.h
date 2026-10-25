// Flags: Spotify's remote-config flags. Flags.x forces an override into the configuration
// provider; ASMVitrineFlagList.m is the table of every flag, generated from the IPA by
// scripts/extract-flags.py; FlagsPage.m is the searchable All flags page and FlagPages.m the Labs
// page. Flags that change a part of the app sit on that part's own page.
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ASMVitrineFlagType) { ASMVitrineFlagUnknown, ASMVitrineFlagBool, ASMVitrineFlagInt, ASMVitrineFlagEnum };
typedef struct { const char *key; ASMVitrineFlagType type; long value, lower, upper; } ASMVitrineFlagDef;
extern const ASMVitrineFlagDef ASMVitrineFlagTable[];
extern const NSUInteger ASMVitrineFlagCount;

UIViewController *ASMVitrineAllFlagsPage(void);
UIViewController *ASMVitrineLabsPage(void);
