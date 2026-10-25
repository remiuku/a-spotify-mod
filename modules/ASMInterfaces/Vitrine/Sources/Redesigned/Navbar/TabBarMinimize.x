// What minimizes the glass bar and what brings it back (TabBar.x draws it): a page scrolled down by a
// finger or the fling after it, and scrolled back up or to its top (MinimizeStep.h). After the bar changes some
// other way (a tap on its circle, a tab, the player), only a new touch minimizes it again: the fling still
// running would otherwise undo the tap at once; another tab (TabBar.x);
// and the full screen player opening or closing, which takes Spotify's pictures of the bars to move with it
// and would have moved the card from the tab bar's row back up to its place above the bar.
//
// Only a page's own scroll views count: those inside Spotify's tab bar container. The player and the now
// playing bar are outside it, and a shelf scrolling sideways has nothing to scroll down.
#import "Core/ASMVitrineCore.h"
#import "Navbar.h"
#import "MinimizeStep.h"
#import "Shared/Player/PlayerEvents.h"

static Class asm_vitrine_containerClass;
static __weak UIScrollView *asm_vitrine_page, *asm_vitrine_other;
static ASMVitrineRMinimizeTrack asm_vitrine_track;
static BOOL asm_vitrine_waitForTouch;

static BOOL inContainer(UIView *view) {
    for (UIResponder *r = view.nextResponder; r; r = r.nextResponder) if ([r isKindOfClass:asm_vitrine_containerClass]) return YES;
    return NO;
}

static void scrolled(UIScrollView *scrollView) {
    if ((!scrollView.isTracking && !scrollView.isDecelerating) || scrollView == asm_vitrine_other) return;
    CGFloat offset = scrollView.contentOffset.y;
    if (scrollView != asm_vitrine_page) {
        if (!inContainer(scrollView)) {
            asm_vitrine_other = scrollView;
            return;
        }
        asm_vitrine_page = scrollView;
        asm_vitrine_track = (ASMVitrineRMinimizeTrack){offset, ASMVitrineRTabBarMinimized()};
    }
    // The bar changed some other way (a tab, the player): the scroll counts from here.
    if (asm_vitrine_track.minimized != ASMVitrineRTabBarMinimized()) {
        asm_vitrine_track = (ASMVitrineRMinimizeTrack){offset, ASMVitrineRTabBarMinimized()};
        asm_vitrine_waitForTouch = YES;
    }
    if (scrollView.isTracking) asm_vitrine_waitForTouch = NO;
    UIEdgeInsets inset = scrollView.adjustedContentInset;
    CGFloat top = -inset.top, bottom = scrollView.contentSize.height + inset.bottom - scrollView.bounds.size.height;
    BOOL minimized = ASMVitrineRMinimizeStep(&asm_vitrine_track, offset, top, bottom);
    if (minimized == ASMVitrineRTabBarMinimized() || (minimized && !ASMVitrineEnabled(ASMVitrineRKeyNavbarMinimize))) return;
    if (minimized && asm_vitrine_waitForTouch) return;
    ASMVitrineRSetTabBarMinimized(minimized, YES);
}

%hook UIScrollView
- (void)setContentOffset:(CGPoint)offset {
    %orig;
    scrolled(self);
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    asm_vitrine_containerClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl");
    if (!asm_vitrine_containerClass) return;
    %init;
    [NSNotificationCenter.defaultCenter addObserverForName:ASMVitrinePlayerTransitionNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { ASMVitrineRSetTabBarMinimized(NO, NO); }];
}
