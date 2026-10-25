// EeveeSpotify's layers, ported, at the top of the Premium, ads & privacy page. Three switches, each off until asked for. Hide ads
// keeps the ad services from starting (AdServices.x), takes ad components out of Home and Search
// before they render (AdHubs.x, Feeds.m) and answers the requests behind them empty (AdNetwork.x).
// Hide upsells drops the Premium prompts (AdPopups.x, AdServices.x) and forces the flags that show
// them off (AdBlock.m, through Flags.x). Spoof Premium rewrites the product state and remote
// config as they arrive (Premium.m), crossfade and automix included (Crossfade.x), and keeps the
// session alive when the server disagrees (AdNetwork.x). The two Search switches force their flags
// off (AdBlock.m, through Flags.x).
#import <UIKit/UIKit.h>

#define ASMSpotiKeyHideAds @"asm.interface.spotipw.adblock.ads"
#define ASMSpotiKeyHideUpsells @"asm.interface.spotipw.adblock.upsells"
#define ASMSpotiKeyFakePremium @"asm.interface.spotipw.adblock.premium"
#define ASMSpotiKeyHideSearchVideos @"asm.interface.spotipw.adblock.searchVideos"
#define ASMSpotiKeyHideSocialProof @"asm.interface.spotipw.adblock.socialProof"

// What a switch turning Spoof Premium on is told first.
extern NSString *const ASMSpotiFakePremiumWarning;

// A flag the ads or upsells switch forces off while it is on. Flags.x asks, and the row for it locks.
BOOL ASMSpotiAdBlockForcesFlagOff(NSString *key);

// What the hooks stopped, by kind, for the counts under the switches (nil label for all of them).
void ASMSpotiAdBlockCountOne(NSString *label);
NSArray<NSString *> *ASMSpotiAdBlockLabels(void);
NSUInteger ASMSpotiAdBlockCount(NSString *label);
void ASMSpotiResetAdBlock(void);

// Premium.m: the body of v1/customize, or the bootstrap message that wraps one, rewritten to a
// Premium account's. nil when the bytes do not parse.
NSData *ASMSpotiPatchCustomize(NSData *body);
NSData *ASMSpotiPatchBootstrap(NSData *body);

// Feeds.m: a browsita, casita or scrollsita feed with its ad sections taken out; nil when there
// were none, or the bytes were not the shape expected.
NSData *ASMSpotiStripFeed(NSData *body);

// The Premium, ads & privacy page: these switches, the ad flags they lock, telemetry, the counters.
UIViewController *ASMSpotiAdsSettingsPage(void);
