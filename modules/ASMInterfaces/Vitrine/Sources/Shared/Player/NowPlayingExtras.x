// NowPlayingExtras.h says what this is and why it stores nothing of Spotify's.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/Player/NowPlayingExtras.h"

// Read on whatever thread Spotify sets the info from, written on the main one.
static NSObject *asm_vitrine_lock;
static NSMutableDictionary<NSString *, NSDictionary *> *asm_vitrine_extras;   // by owner
static NSMutableDictionary<NSString *, NSString *> *asm_vitrine_titles;       // by owner
static double asm_vitrine_elapsed, asm_vitrine_rate;
static CFAbsoluteTime asm_vitrine_clockAt;

// `stale` are an owner's old keys: the info the getter gives back can still carry them, and the hook puts
// back only the extras that are current.
static void resend(NSArray *stale) {
    MPNowPlayingInfoCenter *center = MPNowPlayingInfoCenter.defaultCenter;
    NSMutableDictionary *info = [center.nowPlayingInfo mutableCopy];
    if (!info) return;
    [info removeObjectsForKeys:stale];
    @synchronized (asm_vitrine_lock) {
        if (asm_vitrine_clockAt > 0) info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(asm_vitrine_elapsed + asm_vitrine_rate * (CFAbsoluteTimeGetCurrent() - asm_vitrine_clockAt));
    }
    center.nowPlayingInfo = info;
}

void ASMVitrineNowPlayingSetExtras(NSString *owner, NSDictionary *extras, NSString *title) {
    NSDictionary *old;
    @synchronized (asm_vitrine_lock) {
        old = asm_vitrine_extras[owner];
        asm_vitrine_extras[owner] = extras.count ? extras : nil;
        asm_vitrine_titles[owner] = extras.count ? title : nil;
    }
    if (extras.count) {
        resend(old.allKeys ?: @[]);
        return;
    }
    // Cleared, they are taken off if they are still on: the next track can have the same title, and then
    // the last track's artwork or ISRC rode on its info.
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    for (id key in old) {
        if (![info[key] isEqual:old[key]]) continue;
        resend(old.allKeys);
        return;
    }
}

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    NSMutableDictionary *added = nil;
    @synchronized (asm_vitrine_lock) {
        if (info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) {
            asm_vitrine_elapsed = [info[MPNowPlayingInfoPropertyElapsedPlaybackTime] doubleValue];
            // A rate left out runs at 1, as LockScreenLyrics.x reads it.
            NSNumber *rate = info[MPNowPlayingInfoPropertyPlaybackRate];
            asm_vitrine_rate = rate ? rate.doubleValue : 1;
            asm_vitrine_clockAt = CFAbsoluteTimeGetCurrent();
        }
        id title = info[MPMediaItemPropertyTitle];
        for (NSString *owner in asm_vitrine_extras) {
            if (![title isEqual:asm_vitrine_titles[owner]]) continue;
            if (!added) added = [NSMutableDictionary dictionary];
            [added addEntriesFromDictionary:asm_vitrine_extras[owner]];
        }
    }
    if (!added) {
        %orig;
        return;
    }
    NSMutableDictionary *withExtras = [info mutableCopy];
    [withExtras addEntriesFromDictionary:added];
    %orig(withExtras);
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    asm_vitrine_lock = [NSObject new];
    asm_vitrine_extras = [NSMutableDictionary dictionary];
    asm_vitrine_titles = [NSMutableDictionary dictionary];
    %init;
}
