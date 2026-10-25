#import "ASMSpotiPrefs.h"

BOOL ASMSpotiFlag(NSString *key, BOOL fallback) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    id value = [store objectForKey:key];
    if (value) return [value boolValue];
    return fallback && ![store boolForKey:ASMSpotiKeyStock];
}

BOOL ASMSpotiEnabled(NSString *key) {
    return ASMSpotiFlag(key, YES);
}

BOOL ASMSpotiHidden(NSString *key) {
    return ASMSpotiFlag(key, NO);
}

void ASMSpotiSetEnabled(NSString *key, BOOL on) {
    [NSUserDefaults.standardUserDefaults setBool:on forKey:key];
}

NSInteger ASMSpotiInt(NSString *key, NSInteger fallback) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value integerValue] : fallback;
}

void ASMSpotiSetInt(NSString *key, NSInteger value) {
    [NSUserDefaults.standardUserDefaults setInteger:value forKey:key];
}

NSString *const ASMSpotiFlagOverridePrefix = @"asm.interface.spotipw.flag.";

id ASMSpotiFlagOverride(NSString *key) {
    return [NSUserDefaults.standardUserDefaults objectForKey:[ASMSpotiFlagOverridePrefix stringByAppendingString:key]];
}

void ASMSpotiSetFlagOverride(NSString *key, id value) {
    key = [ASMSpotiFlagOverridePrefix stringByAppendingString:key];
    if (value) [NSUserDefaults.standardUserDefaults setObject:value forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}

void ASMSpotiMigrateKey(NSString *from, NSString *to) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    id value = [store objectForKey:from];
    if (!value || [store objectForKey:to]) return;
    [store setObject:value forKey:to];
    [store removeObjectForKey:from];
}

void ASMSpotiRestartSpotify(void) {
    [NSUserDefaults.standardUserDefaults synchronize];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}
