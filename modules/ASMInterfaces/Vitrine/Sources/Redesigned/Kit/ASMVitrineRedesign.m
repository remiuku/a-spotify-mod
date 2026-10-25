#import <os/lock.h>
#import "Core/ASMVitrineCore.h"
#import "ASMVitrineRedesign.h"

// Written from the constructors, read by the configuration provider on whatever thread it asks from;
// the lock only guards the swap of the immutable table.
static os_unfair_lock asm_vitrine_flagsLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary<NSString *, id> *asm_vitrine_flags;

static id forcedNow(NSString *key) {
    os_unfair_lock_lock(&asm_vitrine_flagsLock);
    id value = asm_vitrine_flags[key];
    os_unfair_lock_unlock(&asm_vitrine_flagsLock);
    return value;
}

void ASMVitrineRedesignForceFlags(NSString *owner, NSDictionary<NSString *, id> *flags) {
    if (!flags.count) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMVitrineRegisterFlagForcer(YES, ^id(NSString *key) { return ASMVitrineRedesignedUI() ? forcedNow(key) : nil; },
                             ^id(NSString *key) { return ASMVitrineRedesignedUIStored() ? forcedNow(key) : nil; });
    });
    os_unfair_lock_lock(&asm_vitrine_flagsLock);
    NSMutableDictionary *all = [asm_vitrine_flags mutableCopy] ?: [NSMutableDictionary dictionary];
    [all addEntriesFromDictionary:flags];
    asm_vitrine_flags = [all copy];
    os_unfair_lock_unlock(&asm_vitrine_flagsLock);
    if (!ASMVitrineRedesignedUI()) return;
    ASMVitrineLog(@"redesign %@: forcing %lu flags", owner, (unsigned long)flags.count);
    [flags enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        id override = ASMVitrineFlagOverride(key);
        if (override) ASMVitrineLog(@"redesign %@: flag %@ forced %@ over the All flags override %@", owner, key, value, override);
    }];
}

NSDictionary *ASMVitrineRedesignSnapshot(void) {
    os_unfair_lock_lock(&asm_vitrine_flagsLock);
    NSDictionary *flags = [asm_vitrine_flags copy] ?: @{};
    os_unfair_lock_unlock(&asm_vitrine_flagsLock);
    return flags;
}
