// PlayerState.h names the hooks and why they are the ones.
#import "Core/ASMVitrineCore.h"
#import "PlayerState.h"

NSString *ASMVitrineURIString(id uri) {
    if ([uri isKindOfClass:NSString.class]) return uri;
    if ([uri isKindOfClass:NSURL.class]) return ((NSURL *)uri).absoluteString;
    return nil;
}

static NSHashTable<id<ASMVitrinePlayerStateObserver>> *asm_vitrine_stateObservers;
static SPTPlayerState *asm_vitrine_playerState;
static NSString *asm_vitrine_stateKey;
// Set once the now playing platform has reported; the mod's own observer on the player stands down.
static BOOL asm_vitrine_platformReported = NO;

void ASMVitrineAddPlayerStateObserver(id<ASMVitrinePlayerStateObserver> observer) {
    if (!observer) return;
    if (!asm_vitrine_stateObservers) asm_vitrine_stateObservers = [NSHashTable weakObjectsHashTable];
    [asm_vitrine_stateObservers addObject:observer];
}

SPTPlayerState *ASMVitrinePlayerState(void) {
    return asm_vitrine_playerState;
}

// What an observer is told about; the state object itself is new with every position report.
static NSString *keyOf(SPTPlayerState *state) {
    SPTPlayerOptions *options = [state respondsToSelector:@selector(options)] ? state.options : nil;
    BOOL shuffling = [options respondsToSelector:@selector(shufflingContext)] && options.shufflingContext;
    return [NSString stringWithFormat:@"%@|%@|%d%d%d%d", ASMVitrineURIString(state.track.URI), ASMVitrineURIString(state.contextURI),
            state.isPaused, state.isPlaying, [state respondsToSelector:@selector(isLoading)] && state.isLoading, shuffling];
}

static void publish(SPTPlayerState *state) {
    asm_vitrine_playerState = state;
    for (id<ASMVitrinePlayerStateObserver> observer in asm_vitrine_stateObservers.allObjects) {
        if ([observer respondsToSelector:@selector(playerStateDidReport:)]) [observer playerStateDidReport:state];
    }
    NSString *key = keyOf(state);
    if ([key isEqualToString:asm_vitrine_stateKey]) return;
    asm_vitrine_stateKey = key;
    for (id<ASMVitrinePlayerStateObserver> observer in asm_vitrine_stateObservers.allObjects) [observer playerStateDidChange:state];
}

static void report(id state, BOOL platform) {
    if (![state isKindOfClass:objc_getClass("SPTPlayerState")]) return;
    dispatch_block_t apply = ^{
        if (platform) asm_vitrine_platformReported = YES;
        else if (asm_vitrine_platformReported) return;
        publish(state);
    };
    if (NSThread.isMainThread) apply();
    else dispatch_async(dispatch_get_main_queue(), apply);
}

@interface ASMVitrinePlayerObserver : NSObject
@end

@implementation ASMVitrinePlayerObserver
- (void)player:(id)player stateDidChange:(id)state {
    report(state, NO);
}
@end

static ASMVitrinePlayerObserver *asm_vitrine_ownObserver;

%hook _TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation
- (void)player:(id)player stateDidChange:(id)state {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMVitrineLog(@"player state: from %@, a %@, on the main thread %d", [player class], [state class], NSThread.isMainThread);
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
            asm_vitrine_ownObserver = [ASMVitrinePlayerObserver new];
            [(id<SPTPlayer>)player addPlayerObserver:asm_vitrine_ownObserver];
            id state = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
            if (state) report(state, NO);
        });
    });
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMVitrineRequireClasses(@[@"_TtC23NowPlaying_PlatformImpl28StatefulPlayerImplementation", @"SPTEsperantoPlayer", @"SPTPlayerState"]);
}
