#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "NowPlayingBar.h"

UIViewController *ASMVitrineNowPlayingBarSettingsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Now playing bar" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineSection(nil, @[
            ASMVitrineHideRow(@"Hide the device button", nil, ASMVitrineHideBarConnect),
        ]),
        ASMVitrineSection(@"Spotify's flags", @[
            ASMVitrineFlagRow(@"Two lines of track info", @"ios-feature-nowplayingbar.two_lines_information_unit"),
            ASMVitrineFlagRow(@"Save button", @"ios-feature-nowplayingbar.add_button"),
            ASMVitrineFlagRow(@"Queue badge", @"ios-feature-nowplayingbar.queue_badge"),
            ASMVitrineFlagRow(@"Hold and drag to resize", @"ios-feature-nowplayingbar.hold_and_drag_to_resize"),
            ASMVitrineFlagRow(@"Video in the mini player", @"ios-feature-nowplaying.video_in_miniplayer"),
            ASMVitrineFlagRow(@"Bar to cover art animation", @"ios-feature-nowplaying.bartocoverart_animation_enabled"),
            ASMVitrineFlagRow(@"Mini player transition animations", @"ios-feature-nowplaying.miniplayer_transition_animations"),
        ]),
    ] footer:nil];
}
