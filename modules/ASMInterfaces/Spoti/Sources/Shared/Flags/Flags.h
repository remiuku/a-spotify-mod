// Flags: Spotify's remote-config flags. Flags.x forces an override into the configuration
// provider; ASMSpotiFlagList.m is the table of every flag, generated from the IPA by
// scripts/extract-flags.py; FlagsPage.m is the searchable All flags page and FlagPages.m the Labs
// page. Flags that change a part of the app sit on that part's own page.
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ASMSpotiFlagType) { ASMSpotiFlagUnknown, ASMSpotiFlagBool, ASMSpotiFlagInt, ASMSpotiFlagEnum };
typedef struct { const char *key; ASMSpotiFlagType type; long value, lower, upper; } ASMSpotiFlagDef;
extern const ASMSpotiFlagDef ASMSpotiFlagTable[];
extern const NSUInteger ASMSpotiFlagCount;

UIViewController *ASMSpotiAllFlagsPage(void);
UIViewController *ASMSpotiLabsPage(void);
