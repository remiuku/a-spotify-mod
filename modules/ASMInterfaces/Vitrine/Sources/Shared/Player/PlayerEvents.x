// The player's open and close, told from the appearance callbacks of a controller inside the player,
// which UIKit sends as the presentation or the dismissal begins, whatever animates it; the transition
// coordinator says when it is over, a canceled swipe included. Spotify 9.1.78 presents the player
// through SPTBarInteractivePresentationController, never through NowPlaying_ViewPageImpl's
// Show/CloseFullscreenAnimatedTransitioning animators, whose hooks never once fired.
#import "Core/ASMVitrineCore.h"
#import "PlayerEvents.h"

NSString *const ASMVitrinePlayerTransitionNotification = @"asm.interface.vitrine.playerTransition";
NSString *const ASMVitrinePlayerTransitionEndedNotification = @"asm.interface.vitrine.playerTransitionEnded";
static CFTimeInterval asm_vitrine_transitionEnds;
static NSUInteger asm_vitrine_transitionGeneration;

CFTimeInterval ASMVitrinePlayerTransitionEnds(void) {
    return asm_vitrine_transitionEnds > CACurrentMediaTime() ? asm_vitrine_transitionEnds : 0;
}

static void announceTransition(UIViewController *unit, BOOL animated, NSString *what) {
    id<UIViewControllerTransitionCoordinator> coordinator = unit.transitionCoordinator;
    if (!animated || !coordinator) return;
    NSTimeInterval duration = MAX(0.1, coordinator.transitionDuration);
    NSUInteger generation = ++asm_vitrine_transitionGeneration;
    asm_vitrine_transitionEnds = CACurrentMediaTime() + duration;
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrinePlayerTransitionNotification object:nil];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        if (generation != asm_vitrine_transitionGeneration) return;
        asm_vitrine_transitionEnds = 0;
        [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrinePlayerTransitionEndedNotification object:nil];
    }];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineLog(@"player %@ over %.2fs, by its appearance callbacks", what, duration); });
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
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMVitrineRequireClasses(@[@"_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController"]);
}
