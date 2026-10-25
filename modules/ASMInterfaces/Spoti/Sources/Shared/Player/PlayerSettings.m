// The player's settings that do not depend on the look: the lock screen widget's flags.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "PlayerSettings.h"

UIViewController *ASMSpotiLockScreenWidgetPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Lock screen widget" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiSection(@"Controls", @[
            ASMSpotiFlagRow(@"Like and dislike buttons", @"ios-feature-lockscreen.like_dislike_enabled"),
            ASMSpotiFlagRow(@"Skip button on podcasts", @"ios-feature-lockscreen.skip_button_on_podcasts"),
            ASMSpotiFlagRow(@"Chapter skip controls", @"ios-feature-lockscreen.enable_chapter_skip_controls"),
            ASMSpotiFlagRow(@"Burst skip", @"ios-feature-lockscreen.burst_skip_enabled"),
        ]),
        ASMSpotiSection(@"Artwork", @[
            ASMSpotiFlagRow(@"Animated artwork", @"ios-feature-lockscreen.animated_artwork_enabled"),
            ASMSpotiFlagRow(@"Video artwork", @"ios-feature-lockscreen.vit_artwork_enabled"),
            ASMSpotiFlagRow(@"Companion content", @"ios-feature-lockscreen.companion_content_enabled"),
        ]),
    ] footer:nil];
}
