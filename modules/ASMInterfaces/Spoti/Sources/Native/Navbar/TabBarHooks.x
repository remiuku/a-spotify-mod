// What drives the native look's navbar: Spotify's tab bar composed on its layout passes (Navbar.x), and
// holding Home opens Mod Settings.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > UIStackView of
//   ElementContentView<TabBarItemElement>, each with an SPTEncoreIconView and an SPTEncoreLabel.
#import "Core/ASMSpotiCore.h"
#import "Navbar.h"
#import "Settings/ASMSpotiPage.h"

@interface ASMSpotiHomeHold : UILongPressGestureRecognizer
@end

@implementation ASMSpotiHomeHold
+ (void)held:(ASMSpotiHomeHold *)hold {
    if (hold.state == UIGestureRecognizerStateBegan) ASMSpotiOpenModSettings(hold.view);
}
@end

// On Spotify's own bar a hold that begins fails the item's tap recognizer, so Home is not tapped too.
static void holdHome(UIView *stockBar) {
    UIView *home = ASMSpotiRowIn(stockBar).arrangedSubviews.firstObject;
    if (!home) return;
    for (UIGestureRecognizer *recognizer in home.gestureRecognizers) {
        if ([recognizer isKindOfClass:ASMSpotiHomeHold.class]) return;
    }
    [home addGestureRecognizer:[[ASMSpotiHomeHold alloc] initWithTarget:ASMSpotiHomeHold.class action:@selector(held:)]];
}

static UIView *tabBarOf(UIView *item) {
    Class barClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl10TabBarView");
    for (UIView *v = item.superview; v; v = v.superview) if ([v isKindOfClass:barClass]) return v;
    return nil;
}

%hook _TtC23NavigationUI_TabBarImpl10TabBarView
- (void)layoutSubviews {
    %orig;
    ASMSpotiComposeTabBar((UIView *)self);
    holdHome((UIView *)self);
    ASMSpotiLogTabBarRow((UIView *)self);
}
%end

// The bar's own pass runs before Spotify has filled the row; the items lay out as they arrive.
static void itemDidLayOut(UIView *item) {
    UIView *bar = tabBarOf(item);
    if (!bar) return;
    ASMSpotiComposeTabBar(bar);
    holdHome(bar);
    ASMSpotiLogTabBarRow(bar);
}

%hook _TtC23NavigationUI_TabBarImpl21TabBarItemElementView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiNativeUI()) return;
    %init;
    ASMSpotiRequireClasses(@[
        @"_TtC23NavigationUI_TabBarImpl10TabBarView",
        @"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView",
        @"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView",
    ]);
}
