#pragma once
#import <Foundation/Foundation.h>
#import <math.h>
#import <unistd.h>

// Minimal host adapter for the pinned GPL audio modules. No spoti.pw UI,
// player observers or lyrics hooks are installed by this adapter.
#define SGLog(format, ...) do { \
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"asm.audioDebug"]) \
        NSLog(@"[a spotify mod][audio] " format, ##__VA_ARGS__); \
} while (0)
static inline BOOL SGHidden(NSString *key) {
    return [NSUserDefaults.standardUserDefaults boolForKey:key];
}
static inline void SGSetEnabled(NSString *key, BOOL value) {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:key];
}
