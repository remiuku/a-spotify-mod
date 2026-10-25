// The mod's own settings, in Spotify's NSUserDefaults. Every key is declared by the feature that
// owns it, in that feature's header, and starts with "asm.interface.spotipw.": Reset all settings on the Mod
// page sweeps by that prefix and knows no key by name. The accessors here are what the hooks and the
// pages share.
#import <Foundation/Foundation.h>

// Set by the reset, after the sweep: an unset switch then reads off rather than the way the build
// came, so a reset is stock Spotify, for every switch there is and every one added later.
#define ASMSpotiKeyStock @"asm.interface.spotipw.stock"

BOOL ASMSpotiFlag(NSString *key, BOOL fallback);
BOOL ASMSpotiEnabled(NSString *key);   // an unset switch is on
BOOL ASMSpotiHidden(NSString *key);    // an unset switch is off
void ASMSpotiSetEnabled(NSString *key, BOOL on);

// A setting picked from a list, stored as the index into it; the choice rows of
// Settings/ASMSpotiModPage.h write these.
NSInteger ASMSpotiInt(NSString *key, NSInteger fallback);
void ASMSpotiSetInt(NSString *key, NSInteger value);

// Overrides of Spotify's remote-config flags, stored under ASMSpotiFlagOverridePrefix + flag key;
// nil keeps Spotify's value. Shared/Flags reads them, the All flags page and flag rows write them.
extern NSString *const ASMSpotiFlagOverridePrefix;
id ASMSpotiFlagOverride(NSString *key);
void ASMSpotiSetFlagOverride(NSString *key, id value);

// Moves a stored setting to another key, once: nothing happens unless `from` is set and `to` is not.
// A feature that leaves Redesigned/ for Shared/ loses the ".redesign." from its keys this way, so the
// switch someone already flipped is still the one they get.
void ASMSpotiMigrateKey(NSString *from, NSString *to);

// Quits Spotify so the hooks read the switches afresh on the next launch; the writes reach cfprefsd first.
void ASMSpotiRestartSpotify(void);
