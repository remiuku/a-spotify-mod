// The player's open and close, told from the appearance callbacks of a controller inside the player,
// which UIKit sends as the presentation or the dismissal begins, whatever animates it; the transition
// coordinator says when it is over, a cancelled swipe included. Spotify 9.1.78 presents the player
// through SPTBarInteractivePresentationController, never through NowPlaying_ViewPageImpl's
// Show/CloseFullscreenAnimatedTransitioning animators, whose hooks never once fired.
#import "Core/ASMSpotiCore.h"
#import "PlayerEvents.h"

NSString *const ASMSpotiPlayerTransitionNotification = @"asm.interface.spotipw.playerTransition";
NSString *const ASMSpotiPlayerTransitionEndedNotification = @"asm.interface.spotipw.playerTransitionEnded";
static CFTimeInterval asm_spotipw_transitionEnds;
static NSUInteger asm_spotipw_transitionGeneration;

CFTimeInterval ASMSpotiPlayerTransitionEnds(void) {
    return asm_spotipw_transitionEnds > CACurrentMediaTime() ? asm_spotipw_transitionEnds : 0;
}

static void announceTransition(UIViewController *unit, BOOL animated, NSString *what) {
    id<UIViewControllerTransitionCoordinator> coordinator = unit.transitionCoordinator;
    if (!animated || !coordinator) return;
    NSTimeInterval duration = MAX(0.1, coordinator.transitionDuration);
    NSUInteger generation = ++asm_spotipw_transitionGeneration;
    asm_spotipw_transitionEnds = CACurrentMediaTime() + duration;
    [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiPlayerTransitionNotification object:nil];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (generation != asm_spotipw_transitionGeneration) return;
        asm_spotipw_transitionEnds = 0;
        [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiPlayerTransitionEndedNotification object:nil];
    }];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMSpotiLog(@"player %@ over %.2fs, by its appearance callbacks", what, duration); });
}

%hook _TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    announceTransition((UIViewController *)self, animated, @"opens");
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    announceTransition((UIViewController *)self, animated, @"closes");
}
%end

%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMSpotiRequireClasses(@[@"_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController"]);
}
