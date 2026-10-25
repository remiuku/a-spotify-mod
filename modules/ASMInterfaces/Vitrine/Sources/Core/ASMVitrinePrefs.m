#import "ASMVitrinePrefs.h"

BOOL ASMVitrineFlag(NSString *key, BOOL fallback) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    id value = [store objectForKey:key];
    if (value) return [value boolValue];
    return fallback && ![store boolForKey:ASMVitrineKeyStock];
}

BOOL ASMVitrineEnabled(NSString *key) {
    return ASMVitrineFlag(key, YES);
}

BOOL ASMVitrineHidden(NSString *key) {
    return ASMVitrineFlag(key, NO);
}

void ASMVitrineSetEnabled(NSString *key, BOOL on) {
    [NSUserDefaults.standardUserDefaults setBool:on forKey:key];
}

NSInteger ASMVitrineInt(NSString *key, NSInteger fallback) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value integerValue] : fallback;
}

void ASMVitrineSetInt(NSString *key, NSInteger value) {
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:key];
}

NSString *const ASMVitrineFlagOverridePrefix = @"asm.interface.vitrine.flag.";

id ASMVitrineFlagOverride(NSString *key) {
    return [NSUserDefaults.standardUserDefaults objectForKey:[ASMVitrineFlagOverridePrefix stringByAppendingString:key]];
}

void ASMVitrineSetFlagOverride(NSString *key, id value) {
    key = [ASMVitrineFlagOverridePrefix stringByAppendingString:key];
    if (value) [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}

void ASMVitrineMigrateKey(NSString *from, NSString *to) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    id value = [store objectForKey:from];
    if (!value || [store objectForKey:to]) return;
    [store setObject:value forKey:to];
    [store removeObjectForKey:from];
}

void ASMVitrineRestartSpotify(void) {
    [NSUserDefaults.standardUserDefaults synchronize];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}
