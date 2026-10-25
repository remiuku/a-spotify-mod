// A double tap on the player, read against the grid Settings draws: the recognizer, what each cell does
// and the playback controller it does it with. Which view of the player it goes on is each look's own
// hookup (Native/Player/PlayerGestures.x, Redesigned/Player/PlayerGestures.x), which call ASMSpotiGestureAttach.
//
// The player already answers a sideways swipe with the next track and a vertical drag with the
// cards below, which leaves the double tap as the one gesture free to take.
#import "Core/ASMSpotiCore.h"
#import "Gestures.h"
#import "Headers/SPTNowPlayingPlaybackController.h"

static __weak SPTNowPlayingPlaybackControllerImplementation *asm_spotipw_player;
static void (^asm_spotipw_observer)(ASMSpotiGestureAction action);

void ASMSpotiGestureSetObserver(void (^observer)(ASMSpotiGestureAction action)) {
    asm_spotipw_observer = [observer copy];
}

#pragma mark - what a cell does

static void perform(ASMSpotiGestureAction action) {
    SPTNowPlayingPlaybackControllerImplementation *player = asm_spotipw_player;
    if (!player) return;
    if (action != ASMSpotiGestureNothing && asm_spotipw_observer) asm_spotipw_observer(action);
    switch (action) {
        case ASMSpotiGestureNothing:
            break;
        case ASMSpotiGestureSeekBack:
            if (player.seekingAllowed) [player seekBackwardBySeconds:ASMSpotiGestureStep()];
            break;
        case ASMSpotiGestureSeekForward:
            if (player.seekingAllowed) [player seekForwardBySeconds:ASMSpotiGestureStep()];
            break;
        case ASMSpotiGesturePlayPause:
            if (player.isPaused ? !player.disallowResuming : !player.disallowPausing) {
                [player setPaused:!player.isPaused];
            }
            break;
        case ASMSpotiGestureNextTrack:
            if (player.canSkipNext) [player skipToNextWhileDragging:NO];
            break;
        case ASMSpotiGesturePreviousTrack:
            [player skipToPreviousWhileDragging:NO];
            break;
        case ASMSpotiGestureShuffle:
            [player setGlobalShuffleMode:!player.isShuffling];
            break;
        case ASMSpotiGestureRepeat:
            [player toggleRepeatMode];
            break;
    }
}

#pragma mark - the recognizer

@interface ASMSpotiGestureTarget : NSObject
@end

@implementation ASMSpotiGestureTarget

- (void)doubleTapped:(UITapGestureRecognizer *)tap {
    // The recognizer outlives the switch: it stays on the player once attached, so the switch is
    // read here as well and the gesture stops the moment it goes off.
    if (!ASMSpotiFlag(ASMSpotiKeyGestures, NO)) return;
    // The host is the queue scrolled sideways, so a tap lands in content coordinates a few million
    // points out; its bounds origin is that scroll, and taking it off gives the point on screen.
    UIView *host = tap.view;
    CGRect visible = host.bounds;
    CGPoint point = [tap locationInView:host];
    point.x -= visible.origin.x;
    point.y -= visible.origin.y;
    NSInteger cell = ASMSpotiGestureCellAt(point, visible.size);
    NSArray<NSNumber *> *zones = ASMSpotiGestureZones();
    if (cell < 0 || cell >= (NSInteger)zones.count) return;
    perform((ASMSpotiGestureAction)zones[(NSUInteger)cell].integerValue);
}

@end

static ASMSpotiGestureTarget *target(void) {
    static ASMSpotiGestureTarget *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [ASMSpotiGestureTarget new]; });
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

void ASMSpotiGestureAttach(UIView *host) {
    if (!host || !ASMSpotiFlag(ASMSpotiKeyGestures, NO)) return;
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
    asm_spotipw_player = controller;
    return controller;
}
%end

// A single tap on the cover is Spotify's way into the tilt mode, the artwork alone in 3D. That is
// the half of a double tap that misses, so while the zones are on it would open on the way to every
// gesture; the tap goes back to Spotify with the switch.
%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMSpotiRequireClasses(@[@"SPTNowPlayingPlaybackControllerImplementation"]);
}
