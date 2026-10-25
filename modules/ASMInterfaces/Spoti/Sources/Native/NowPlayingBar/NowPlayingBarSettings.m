#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "NowPlayingBar.h"

UIViewController *ASMSpotiNowPlayingBarSettingsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Now playing bar" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiSection(nil, @[
            ASMSpotiHideRow(@"Hide the device button", nil, ASMSpotiHideBarConnect),
        ]),
        ASMSpotiSection(@"Spotify's flags", @[
            ASMSpotiFlagRow(@"Two lines of track info", @"ios-feature-nowplayingbar.two_lines_information_unit"),
            ASMSpotiFlagRow(@"Save button", @"ios-feature-nowplayingbar.add_button"),
            ASMSpotiFlagRow(@"Queue badge", @"ios-feature-nowplayingbar.queue_badge"),
            ASMSpotiFlagRow(@"Hold and drag to resize", @"ios-feature-nowplayingbar.hold_and_drag_to_resize"),
            ASMSpotiFlagRow(@"Video in the mini player", @"ios-feature-nowplaying.video_in_miniplayer"),
            ASMSpotiFlagRow(@"Bar to cover art animation", @"ios-feature-nowplaying.bartocoverart_animation_enabled"),
            ASMSpotiFlagRow(@"Mini player transition animations", @"ios-feature-nowplaying.miniplayer_transition_animations"),
        ]),
    ] footer:nil];
}
