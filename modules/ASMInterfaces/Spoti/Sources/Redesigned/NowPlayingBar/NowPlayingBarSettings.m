// The Now playing page of the redesign, under Player (App/Pages.m puts it there): the bar and the
// player behind it.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "NowPlayingBar.h"
#import "Redesigned/Player/Player.h"

UIViewController *ASMSpotiRNowPlayingBarSettingsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Now playing" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiSection(nil, @[
            ASMSpotiHideRow(@"Hide the device button", nil, ASMSpotiRHideBarConnect),
        ]),
        ASMSpotiSection(nil, @[
            ASMSpotiSwitchRow(@"Moving background", nil, ASMSpotiRKeyPlayerMotion),
        ]),
    ] footer:nil];
}
