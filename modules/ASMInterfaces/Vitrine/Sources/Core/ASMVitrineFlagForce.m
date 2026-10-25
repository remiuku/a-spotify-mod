#import <os/lock.h>
#import "ASMVitrineFlagForce.h"
#import "ASMVitrineLog.h"
#import "ASMVitrinePrefs.h"

@interface ASMVitrineFlagForcerEntry : NSObject
@property (nonatomic) BOOL beatsOverride;
@property (nonatomic, copy) ASMVitrineFlagForcer atLaunch, locked;
@end

@implementation ASMVitrineFlagForcerEntry
@end

// Swapped whole under the lock, so a reader walks an immutable array.
static os_unfair_lock asm_vitrine_lock = OS_UNFAIR_LOCK_INIT;
static NSArray<ASMVitrineFlagForcerEntry *> *asm_vitrine_forcers;

void ASMVitrineRegisterFlagForcer(BOOL beatsOverride, ASMVitrineFlagForcer atLaunch, ASMVitrineFlagForcer locked) {
    if (!atLaunch) return;
    ASMVitrineFlagForcerEntry *entry = [ASMVitrineFlagForcerEntry new];
    entry.beatsOverride = beatsOverride;
    entry.atLaunch = atLaunch;
    entry.locked = locked;
    os_unfair_lock_lock(&asm_vitrine_lock);
    asm_vitrine_forcers = [(asm_vitrine_forcers ?: @[]) arrayByAddingObject:entry];
    os_unfair_lock_unlock(&asm_vitrine_lock);
}

static NSArray<ASMVitrineFlagForcerEntry *> *forcers(void) {
    os_unfair_lock_lock(&asm_vitrine_lock);
    NSArray *list = asm_vitrine_forcers;
    os_unfair_lock_unlock(&asm_vitrine_lock);
    return list;
}

// The All flags overrides as they were at launch, the prefix taken off: Spotify asks for its flags
// once each, many as it starts, and one dictionary read from these costs a fraction of a defaults lookup each
// (harness/launch). An override set later shows after a restart, as every flag does.
static NSDictionary<NSString *, id> *overridesAtLaunch(void) {
    static NSDictionary<NSString *, id> *overrides;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary<NSString *, id> *found = [NSMutableDictionary dictionary];
        [NSUserDefaults.standardUserDefaults.dictionaryRepresentation enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            if ([key hasPrefix:ASMVitrineFlagOverridePrefix]) found[[key substringFromIndex:ASMVitrineFlagOverridePrefix.length]] = value;
        }];
        overrides = [found copy];
    });
    return overrides;
}

// The overrides Spotify has asked for, with the answer it got. Only an override's key takes the lock,
// so the reads of every other flag cost what they did.
static os_unfair_lock asm_vitrine_askedLock = OS_UNFAIR_LOCK_INIT;
static NSMutableDictionary<NSString *, id> *asm_vitrine_asked;
static BOOL asm_vitrine_reported;

static void noteAsked(NSString *key, id override, id answer) {
    os_unfair_lock_lock(&asm_vitrine_askedLock);
    BOOL first = !asm_vitrine_asked[key];
    if (first) {
        if (!asm_vitrine_asked) asm_vitrine_asked = [NSMutableDictionary dictionary];
        asm_vitrine_asked[[key copy]] = answer;
    }
    BOOL late = first && asm_vitrine_reported;
    os_unfair_lock_unlock(&asm_vitrine_askedLock);
    if (!late) return;
    if ([answer isEqual:override]) ASMVitrineLog(@"flags: Spotify asked for %@ only now, and got the override %@", key, answer);
    else ASMVitrineLog(@"flags: Spotify asked for %@ only now, and got %@ from another switch, not the override %@", key, answer, override);
}

id ASMVitrineForcedFlagValue(NSString *key) {
    if (!key) return nil;
    NSArray<ASMVitrineFlagForcerEntry *> *list = forcers();
    id value = nil;
    for (ASMVitrineFlagForcerEntry *entry in list) {
        if (!entry.beatsOverride) continue;
        value = entry.atLaunch(key);
        if (value) break;
    }
    id override = overridesAtLaunch()[key];
    if (override) noteAsked(key, override, value ?: override);
    if (value) return value;
    if (override) return override;
    for (ASMVitrineFlagForcerEntry *entry in list) {
        if (entry.beatsOverride) continue;
        value = entry.atLaunch(key);
        if (value) return value;
    }
    return nil;
}

id ASMVitrineLockedFlagValue(NSString *key, BOOL *beatsOverride) {
    if (beatsOverride) *beatsOverride = NO;
    if (!key) return nil;
    NSArray<ASMVitrineFlagForcerEntry *> *list = forcers();
    for (int pass = 0; pass < 2; pass++) {
        BOOL first = pass == 0;
        for (ASMVitrineFlagForcerEntry *entry in list) {
            if (entry.beatsOverride != first || !entry.locked) continue;
            id value = entry.locked(key);
            if (!value) continue;
            if (beatsOverride) *beatsOverride = first;
            return value;
        }
    }
    return nil;
}

NSString *ASMVitrineFlagOverrideReport(void) {
    NSDictionary<NSString *, id> *overrides = overridesAtLaunch();
    os_unfair_lock_lock(&asm_vitrine_askedLock);
    NSDictionary<NSString *, id> *asked = [asm_vitrine_asked copy];
    asm_vitrine_reported = YES;
    os_unfair_lock_unlock(&asm_vitrine_askedLock);
    NSUInteger forced = 0;
    NSMutableArray<NSString *> *beaten = [NSMutableArray array], *notAsked = [NSMutableArray array];
    for (NSString *key in [overrides.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        id answer = asked[key];
        if (!answer) [notAsked addObject:key];
        else if ([answer isEqual:overrides[key]]) forced++;
        else [beaten addObject:[NSString stringWithFormat:@"%@ (%@, not %@)", key, answer, overrides[key]]];
    }
    NSMutableString *text = [NSMutableString stringWithFormat:@"%lu overrides stored, %lu asked for and forced",
                             (unsigned long)overrides.count, (unsigned long)forced];
    if (beaten.count) [text appendFormat:@", %lu answered by another switch: %@", (unsigned long)beaten.count, [beaten componentsJoinedByString:@", "]];
    [text appendFormat:@", %lu not asked for yet", (unsigned long)notAsked.count];
    if (notAsked.count) [text appendFormat:@": %@", [notAsked componentsJoinedByString:@", "]];
    return text;
}
