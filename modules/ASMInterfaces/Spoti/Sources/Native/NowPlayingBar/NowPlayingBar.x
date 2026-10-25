// The device button of Spotify's own now playing bar, hidden on request.
//
// Tree (trees/test6.txt): the button row is a UIStackView holding Connect_EntryPointsImpl.ConnectStateView
// (the connected device) and .ConnectButtonView, each wrapped; hiding the wrapper closes the gap.
// The ConnectStateView under the title ("playing on ...") sits in InformationContainer and stays.
#import "Core/ASMSpotiCore.h"
#import "NowPlayingBar.h"

static BOOL insideClass(UIView *view, NSString *marker) {
    for (UIView *v = view; v; v = v.superview) if ([NSStringFromClass(v.class) containsString:marker]) return YES;
    return NO;
}

static void hideConnectButton(UIView *bar) {
    ASMSpotiForEachView(bar, ^(UIView *v) {
        NSString *name = NSStringFromClass(v.class);
        if (![name containsString:@"ConnectButtonView"] && ![name containsString:@"ConnectStateView"]) return;
        if (insideClass(v, @"InformationContainer")) return;
        UIView *item = v;
        while (item.superview && ![item.superview isKindOfClass:UIStackView.class]) item = item.superview;
        if (item.superview && !item.hidden) item.hidden = YES;
    });
}

%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    hideConnectButton(((UIViewController *)self).view);
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiNativeUI() || !ASMSpotiHidden(ASMSpotiHideBarConnect)) return;
    %init;
    ASMSpotiRequireClasses(@[@"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"]);
}
