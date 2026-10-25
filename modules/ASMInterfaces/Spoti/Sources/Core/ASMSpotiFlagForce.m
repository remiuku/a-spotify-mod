#import <os/lock.h>
#import "ASMSpotiFlagForce.h"
#import "ASMSpotiPrefs.h"

@interface ASMSpotiFlagForcerEntry : NSObject
@property (nonatomic) BOOL beatsOverride;
@property (nonatomic, copy) ASMSpotiFlagForcer atLaunch, locked;
@end

@implementation ASMSpotiFlagForcerEntry
@end

// Swapped whole under the lock, so a reader walks an immutable array.
static os_unfair_lock asm_spotipw_lock = OS_UNFAIR_LOCK_INIT;
static NSArray<ASMSpotiFlagForcerEntry *> *asm_spotipw_forcers;

void ASMSpotiRegisterFlagForcer(BOOL beatsOverride, ASMSpotiFlagForcer atLaunch, ASMSpotiFlagForcer locked) {
    if (!atLaunch) return;
    ASMSpotiFlagForcerEntry *entry = [ASMSpotiFlagForcerEntry new];
    entry.beatsOverride = beatsOverride;
    entry.atLaunch = atLaunch;
    entry.locked = locked;
    os_unfair_lock_lock(&asm_spotipw_lock);
    asm_spotipw_forcers = [(asm_spotipw_forcers ?: @[]) arrayByAddingObject:entry];
    os_unfair_lock_unlock(&asm_spotipw_lock);
}

static NSArray<ASMSpotiFlagForcerEntry *> *forcers(void) {
    os_unfair_lock_lock(&asm_spotipw_lock);
    NSArray *list = asm_spotipw_forcers;
    os_unfair_lock_unlock(&asm_spotipw_lock);
    return list;
}

id ASMSpotiForcedFlagValue(NSString *key) {
    if (!key) return nil;
    NSArray<ASMSpotiFlagForcerEntry *> *list = forcers();
    for (ASMSpotiFlagForcerEntry *entry in list) {
        if (!entry.beatsOverride) continue;
        id value = entry.atLaunch(key);
        if (value) return value;
    }
    id value = ASMSpotiFlagOverride(key);
    if (value) return value;
    for (ASMSpotiFlagForcerEntry *entry in list) {
        if (entry.beatsOverride) continue;
        value = entry.atLaunch(key);
        if (value) return value;
    }
    return nil;
}

id ASMSpotiLockedFlagValue(NSString *key, BOOL *beatsOverride) {
    if (beatsOverride) *beatsOverride = NO;
    if (!key) return nil;
    NSArray<ASMSpotiFlagForcerEntry *> *list = forcers();
    for (int pass = 0; pass < 2; pass++) {
        BOOL first = pass == 0;
        for (ASMSpotiFlagForcerEntry *entry in list) {
            if (entry.beatsOverride != first || !entry.locked) continue;
            id value = entry.locked(key);
            if (!value) continue;
            if (beatsOverride) *beatsOverride = first;
            return value;
        }
    }
    return nil;
}
