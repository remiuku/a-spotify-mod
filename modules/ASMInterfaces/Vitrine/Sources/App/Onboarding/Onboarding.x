// The tour goes up the first time Home appears, not at launch: a fresh sideload lands on the login
// screen first, and a tour over that is wrong. A moment after, so Home has drawn under the glass. A
// build that has had its tour and runs a version for the first time shows What's new there instead;
// a fresh install's tour counts as this version's What's new.
#import "Core/ASMVitrineCore.h"
#import "Onboarding.h"

static BOOL newVersion(void) {
    return ![[NSUserDefaults.standardUserDefaults stringForKey:ASMVitrineKeyWhatsNewSeen] isEqualToString:@(ASMVitrine_VERSION)];
}

%hook _TtC19Home_FunkisPageImpl20FunkisViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL fresh = newVersion();
            [NSUserDefaults.standardUserDefaults setObject:@(ASMVitrine_VERSION) forKey:ASMVitrineKeyWhatsNewSeen];
            if (!ASMVitrineFlag(ASMVitrineKeyOnboardingSeen, NO)) ASMVitrineShowOnboarding();
            else if (fresh) ASMVitrineShowWhatsNew();
        });
    });
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    ASMVitrineCheckEnvironmentOnce();
    if (ASMVitrineFlag(ASMVitrineKeyOnboardingSeen, NO) && !newVersion()) return;
    %init;
    ASMVitrineRequireClasses(@[@"_TtC19Home_FunkisPageImpl20FunkisViewController"]);
}
