#import <os/lock.h>
#import "Core/ASMSpotiCore.h"
#import "ASMSpotiRedesign.h"

// Written from the constructors, read by the configuration provider on whatever thread it asks from;
// the lock only guards the swap of the immutable table.
static os_unfair_lock asm_spotipw_flagsLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary<NSString *, id> *asm_spotipw_flags;

static id forcedNow(NSString *key) {
    os_unfair_lock_lock(&asm_spotipw_flagsLock);
    id value = asm_spotipw_flags[key];
    os_unfair_lock_unlock(&asm_spotipw_flagsLock);
    return value;
}

void ASMSpotiRedesignForceFlags(NSString *owner, NSDictionary<NSString *, id> *flags) {
    if (!flags.count) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMSpotiRegisterFlagForcer(YES, ^id(NSString *key) { return ASMSpotiRedesignedUI() ? forcedNow(key) : nil; },
                             ^id(NSString *key) { return ASMSpotiRedesignedUIStored() ? forcedNow(key) : nil; });
    });
    os_unfair_lock_lock(&asm_spotipw_flagsLock);
    NSMutableDictionary *all = [asm_spotipw_flags mutableCopy] ?: [NSMutableDictionary dictionary];
    [all addEntriesFromDictionary:flags];
    asm_spotipw_flags = [all copy];
    os_unfair_lock_unlock(&asm_spotipw_flagsLock);
    if (!ASMSpotiRedesignedUI()) return;
    ASMSpotiLog(@"redesign %@: forcing %lu flags", owner, (unsigned long)flags.count);
    [flags enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        id override = ASMSpotiFlagOverride(key);
        if (override) ASMSpotiLog(@"redesign %@: flag %@ forced %@ over the All flags override %@", owner, key, value, override);
    }];
}

NSDictionary *ASMSpotiRedesignSnapshot(void) {
    os_unfair_lock_lock(&asm_spotipw_flagsLock);
    NSDictionary *flags = [asm_spotipw_flags copy] ?: @{};
    os_unfair_lock_unlock(&asm_spotipw_flagsLock);
    return flags;
}
