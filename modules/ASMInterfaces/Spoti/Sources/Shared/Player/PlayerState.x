// PlayerState.h names the hooks and why they are the ones.
#import "Core/ASMSpotiCore.h"
#import "PlayerState.h"

NSString *ASMSpotiURIString(id uri) {
    if ([uri isKindOfClass:NSString.class]) return uri;
    if ([uri isKindOfClass:NSURL.class]) return ((NSURL *)uri).absoluteString;
    return nil;
}

static NSHashTable<id<ASMSpotiPlayerStateObserver>> *asm_spotipw_stateObservers;
static SPTPlayerState *asm_spotipw_playerState;
static NSString *asm_spotipw_stateKey;
// Set once the now playing platform has reported; the mod's own observer on the player stands down.
static BOOL asm_spotipw_platformReported = NO;

void ASMSpotiAddPlayerStateObserver(id<ASMSpotiPlayerStateObserver> observer) {
    if (!observer) return;
    if (!asm_spotipw_stateObservers) asm_spotipw_stateObservers = [NSHashTable weakObjectsHashTable];
    [asm_spotipw_stateObservers addObject:observer];
}

SPTPlayerState *ASMSpotiPlayerState(void) {
    return asm_spotipw_playerState;
}

// What an observer is told about; the state object itself is new with every position report.
static NSString *keyOf(SPTPlayerState *state) {
    SPTPlayerOptions *options = [state respondsToSelector:@selector(options)] ? state.options : nil;
    BOOL shuffling = [options respondsToSelector:@selector(shufflingContext)] && options.shufflingContext;
    return [NSString stringWithFormat:@"%@|%@|%d%d%d%d", ASMSpotiURIString(state.track.URI), ASMSpotiURIString(state.contextURI),
            state.isPaused, state.isPlaying, [state respondsToSelector:@selector(isLoading)] && state.isLoading, shuffling];
}

static void publish(SPTPlayerState *state) {
    asm_spotipw_playerState = state;
    NSString *key = keyOf(state);
    if ([key isEqualToString:asm_spotipw_stateKey]) return;
    asm_spotipw_stateKey = key;
    for (id<ASMSpotiPlayerStateObserver> observer in asm_spotipw_stateObservers.allObjects) [observer playerStateDidChange:state];
}

static void report(id state, BOOL platform) {
    if (![state isKindOfClass:objc_getClass("SPTPlayerState")]) return;
    dispatch_block_t apply = ^{
        if (platform) asm_spotipw_platformReported = YES;
        else if (asm_spotipw_platformReported) return;
        publish(state);
    };
    if (NSThread.isMainThread) apply();
    else dispatch_async(dispatch_get_main_queue(), apply);
}

@interface ASMSpotiPlayerObserver : NSObject
@end

@implementation ASMSpotiPlayerObserver
- (void)player:(id)player stateDidChange:(id)state {
    report(state, NO);
}
@end

static ASMSpotiPlayerObserver *asm_spotipw_ownObserver;

%hook _TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation
- (void)player:(id)player stateDidChange:(id)state {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMSpotiLog(@"player state: from %@, a %@, on the main thread %d", [player class], [state class], NSThread.isMainThread);
    });
    report(state, YES);
}
%end

// Observers are added from several threads as the app starts; the first player seen is the one
// watched, the way KaraokeSource.x takes the first player the app asks.
%hook SPTEsperantoPlayer
- (void)addPlayerObserver:(id)observer {
    %orig;
    id player = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            asm_spotipw_ownObserver = [ASMSpotiPlayerObserver new];
            [(id<SPTPlayer>)player addPlayerObserver:asm_spotipw_ownObserver];
            id state = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
            if (state) report(state, NO);
        });
    });
}
%end

%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMSpotiRequireClasses(@[@"_TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation", @"SPTEsperantoPlayer", @"SPTPlayerState"]);
}
