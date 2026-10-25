// A double tap on the player, read against the grid Settings draws: the recognizer, what each cell does
// and the playback controller it does it with. Which view of the player it goes on is each look's own
// hookup (Native/Player/PlayerGestures.x, Redesigned/Player/PlayerGestures.x), which call ASMVitrineGestureAttach.
//
// The player already answers a sideways swipe with the next track and a vertical drag with the
// cards below, which leaves the double tap as the one gesture free to take.
#import "Core/ASMVitrineCore.h"
#import "Gestures.h"
#import "Headers/SPTNowPlayingPlaybackController.h"

static __weak SPTNowPlayingPlaybackControllerImplementation *asm_vitrine_player;
static void (^asm_vitrine_observer)(ASMVitrineGestureAction action);

void ASMVitrineGestureSetObserver(void (^observer)(ASMVitrineGestureAction action)) {
    asm_vitrine_observer = [observer copy];
}

#pragma mark - what a cell does

static void perform(ASMVitrineGestureAction action) {
    SPTNowPlayingPlaybackControllerImplementation *player = asm_vitrine_player;
    if (!player) return;
    if (action != ASMVitrineGestureNothing && asm_vitrine_observer) asm_vitrine_observer(action);
    switch (action) {
        case ASMVitrineGestureNothing:
            break;
        case ASMVitrineGestureSeekBack:
            if (player.seekingAllowed) [player seekBackwardBySeconds:ASMVitrineGestureStep()];
            break;
        case ASMVitrineGestureSeekForward:
            if (player.seekingAllowed) [player seekForwardBySeconds:ASMVitrineGestureStep()];
            break;
        case ASMVitrineGesturePlayPause:
            if (player.isPaused ? !player.disallowResuming : !player.disallowPausing) {
                [player setPaused:!player.isPaused];
            }
            break;
        case ASMVitrineGestureNextTrack:
            if (player.canSkipNext) [player skipToNextWhileDragging:NO];
            break;
        case ASMVitrineGesturePreviousTrack:
            [player skipToPreviousWhileDragging:NO];
            break;
        case ASMVitrineGestureShuffle:
            [player setGlobalShuffleMode:!player.isShuffling];
            break;
        case ASMVitrineGestureRepeat:
            [player toggleRepeatMode];
            break;
    }
}

#pragma mark - the recognizer

@interface ASMVitrineGestureTarget : NSObject
@end

@implementation ASMVitrineGestureTarget

- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    // The recognizer outlives the switch: it stays on the player once attached, so the switch is
    // read here as well and the gesture stops the moment it goes off.
    if (!ASMVitrineFlag(ASMVitrineKeyGestures, NO)) return;
    // The host is the queue scrolled sideways, so a tap lands in content coordinates a few million
    // points out; its bounds origin is that scroll, and taking it off gives the point on screen.
    UIView *host = tap.view;
    CGRect visible = host.bounds;
    CGPoint point = [tap locationInView:host];
    point.x -= visible.origin.x;
    point.y -= visible.origin.y;
    NSInteger cell = ASMVitrineGestureCellAt(point, visible.size);
    NSArray<NSNumber *> *zones = ASMVitrineGestureZones();
    if (cell < 0 || cell >= (NSInteger)zones.count) return;
    perform((ASMVitrineGestureAction)zones[(NSUInteger)cell].integerValue);
}

@end

static ASMVitrineGestureTarget *target(void) {
    static ASMVitrineGestureTarget *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [ASMVitrineGestureTarget new]; });
    return shared;
}

// Spotify's own single tap on the player scrolls it to the cards below, and would fire on the first
// of a pair as well; every one above the artwork is asked to wait for the double tap to miss.
static void yieldSingleTaps(UIView *host, UITapGestureRecognizer *tap) {
    for (UIView *view = host; view; view = view.superview) {
        for (UIGestureRecognizer *other in view.gestureRecognizers) {
            if (other == tap || ![other isKindOfClass:UITapGestureRecognizer.class]) continue;
            if (((UITapGestureRecognizer *)other).numberOfTapsRequired != 1) continue;
            [other requireGestureRecognizerToFail:tap];
        }
    }
}

static char kTapKey, kSeenKey;

// Spotify adds its own recognizers as the player's controllers load, which is not ordered against
// this hook: the count of what stands above the artwork is watched so a later one still yields.
static NSUInteger tapsAbove(UIView *host) {
    NSUInteger count = 0;
    for (UIView *view = host; view; view = view.superview) count += view.gestureRecognizers.count;
    return count;
}

void ASMVitrineGestureAttach(UIView *host) {
    if (!host || !ASMVitrineFlag(ASMVitrineKeyGestures, NO)) return;
    UITapGestureRecognizer *tap = objc_getAssociatedObject(host, &kTapKey);
    if (!tap) {
        tap = [[UITapGestureRecognizer alloc] initWithTarget:target() action:@selector(doubleTapped:)];
        tap.numberOfTapsRequired = 2;
        [host addGestureRecognizer:tap];
        objc_setAssociatedObject(host, &kTapKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSNumber *seen = objc_getAssociatedObject(host, &kSeenKey);
    NSUInteger now = tapsAbove(host);
    if (seen.unsignedIntegerValue == now) return;
    objc_setAssociatedObject(host, &kSeenKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    yieldSingleTaps(host, tap);
}

#pragma mark - hooks

%hook SPTNowPlayingPlaybackControllerImplementation
- (id)initWithPlayer:(id)player testManager:(id)manager inStreamClient:(id)client {
    id controller = %orig;
    asm_vitrine_player = controller;
    return controller;
}
%end

// A single tap on the cover is Spotify's way into the tilt mode, the artwork alone in 3D. That is
// the half of a double tap that misses, so while the zones are on it would open on the way to every
// gesture; the tap goes back to Spotify with the switch.
%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMVitrineRequireClasses(@[@"SPTNowPlayingPlaybackControllerImplementation"]);
}
