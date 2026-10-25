// Onboarding: a welcome page over Home the first time this build runs, in glass: Vitrine's logo landing,
// then a pick between the redesign (offered first on iOS 26) and Spotify's own look, a No ads switch that
// turns Hide ads, Hide upsells and Spoof Premium on together (off leaves them alone), pointers to what people
// miss in Mod Settings (Split Tabs, Lyrics, AirPods gestures and the Live Activity), and a line on holding
// Home for Mod Settings. The look and those switches are read at launch, so a changed pick ends the
// welcome in a restart. After an update instead, a What's new sheet lists what the version brought. The Mod page
// offers both again.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyOnboardingSeen @"asm.interface.vitrine.onboarding.seen"
// The version whose What's new was last shown, or skipped because the tour came first.
#define ASMVitrineKeyWhatsNewSeen @"asm.interface.vitrine.whatsnew.seen"

// Presents the tour over the top of the app; does nothing while it is already up.
void ASMVitrineShowOnboarding(void);
// The tour or What's new holds the screen; other sheets wait for it (App/About).
BOOL ASMVitrineOnboardingShowing(void);

// WhatsNew.m: this build's section of CHANGELOG.md, read through App/About/Update.m's parser; empty for a
// build with no section of its own, which then has no sheet and no row.
@class ASMVitrineUpdateChange;
NSArray<ASMVitrineUpdateChange *> *ASMVitrineWhatsNewChanges(void);
void ASMVitrineShowWhatsNew(void);
BOOL ASMVitrineWhatsNewShowing(void);

// Environment.m: what about the install can work against the mod. Said once per install state, a few
// seconds after Spotify comes up and behind the tour, What's new and the signing sheet, and kept as
// warning rows at the top of Mod Settings while it lasts.
// The Spotify versions Vitrine knows. Supported ones are tested as long as the one it is made for, which comes
// first and whose flag table it reads. Likely ones ran cleanly in a short test. Neither gets the install
// warning, and About notes "likely works" after the second. A new version goes in one list, and the warning's
// text and About follow.
#define ASMVitrineSpotifyMadeFor @"9.1.78"
#define ASMVitrineSpotifySupportedVersions @[ASMVitrineSpotifyMadeFor, @"9.1.88", @"9.1.90"]
#define ASMVitrineSpotifyLikelyWorksVersions @[]
@class ASMVitrineModRow;
// ASMVitrineEeveeSpotifyInjected() is Shared/Lyrics/Lyrics.h's.
NSString *ASMVitrineSpotifyVersion(void);
NSArray<ASMVitrineModRow *> *ASMVitrineEnvironmentWarningRows(void);
void ASMVitrineCheckEnvironmentOnce(void);

// The tour's prominent glass button, also What's new's Continue.
UIButton *ASMVitrineOnboardingButton(NSString *title);
