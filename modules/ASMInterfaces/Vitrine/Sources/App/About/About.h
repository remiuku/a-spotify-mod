// About: where the build points its user, and whether GitHub has a newer release (Update.m,
// UpdatePage.m). The status is a string for the Updates row; the page's ticker reads it, so the
// check needs no callback, and a check that lands posts ASMVitrineUpdateCheckedNotification for the page
// that is open at the time. ASMVitrineCheckForUpdate(NO) respects a six hour cache, ASMVitrineCheckForUpdate(YES)
// always asks.
#import <UIKit/UIKit.h>
#import "Settings/ASMVitrineModPage.h"

extern NSString *const ASMVitrineUpdateURL;   // nil turns the check off; the repo is in Settings/ASMVitrinePageStyle.h
extern NSString *const ASMVitrineUpdateCheckedNotification;   // on the main thread, after a check ends either way

// One line of a release's changelog: what changed, under the heading Release Please put it under,
// and the commit it came from.
@interface ASMVitrineUpdateChange : NSObject
@property (nonatomic, copy) NSString *kind;   // "Features", "Fixes", ... as the release names it
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *url;    // the commit, nil for a line written by hand
@end

// One GitHub release, as the last check stored it.
@interface ASMVitrineUpdateRelease : NSObject
@property (nonatomic, copy) NSString *version;   // without the tag's v
@property (nonatomic, copy) NSString *date;      // ISO 8601, as GitHub publishes it
@property (nonatomic, copy) NSString *url;       // the release page, where the .deb is
@property (nonatomic, copy) NSArray<ASMVitrineUpdateChange *> *changes;
@property (nonatomic) BOOL prerelease;   // a beta, by GitHub's mark or the "-" in its version
@end

// Mod > Include betas: whether the check counts pre-releases. Unset, it is on for a beta build (a "-"
// in ASMVitrine_VERSION) and off for a release; the row rechecks when it is flipped.
#define ASMVitrineKeyUpdateBetas @"asm.interface.vitrine.update.betas"
BOOL ASMVitrineBuildIsBeta(void);
BOOL ASMVitrineUpdateIncludesBetas(void);

NSArray<ASMVitrineUpdateRelease *> *ASMVitrineUpdateReleases(void);   // newest first that count for this build, empty until a check lands
// GitHub's reply as the check stores it: the newest twenty that count for this build, newest first,
// empty when none does, nil when the reply is not a list of releases.
NSArray<NSDictionary *> *ASMVitrineUpdateReleasesFrom(NSData *data);
BOOL ASMVitrineUpdateChecked(void);   // a check has landed at least once
// The lines of a release body as Release Please writes it, also what the What's new sheet reads.
NSArray<ASMVitrineUpdateChange *> *ASMVitrineUpdateChangesIn(NSString *body);
ASMVitrineUpdateRelease *ASMVitrineUpdateNewestRelease(void);
NSString *ASMVitrineUpdateVersion(void);  // nil unless GitHub has a release newer than this build
BOOL ASMVitrineUpdateIsNewer(NSString *version);   // whether that release is newer than the build running
BOOL ASMVitrineVersionIsNewer(NSString *candidate, NSString *current);   // semantic versions, pre-releases included
NSString *ASMVitrineUpdateStatus(void);
void ASMVitrineCheckForUpdate(BOOL force);
UIViewController *ASMVitrineUpdatePage(void);   // UpdatePage.m: the state and the changelog
UIViewController *ASMVitrineLicensesPage(void); // Licenses.m: the mod's license and the third-party ones it ships

// UpdateNotice.m: the sheet a release newer than this build brings on its own, a few seconds after
// Spotify comes up, once per release. Watched from the settings %ctor; the switch is on the Updates
// page and takes effect at once.
#define ASMVitrineKeyUpdateNotice @"asm.interface.vitrine.update.notice"
void ASMVitrineWatchForUpdates(void);


// Whether the now playing card on the lock screen can open this build. It depends on the signature,
// not on the mod: iOS launches by the App ID of the application-identifier entitlement, so a build
// whose bundle id is not that App ID cannot be opened from the card. Signing.m says so once.
NSString *ASMVitrineSigningAppIdentifier(void);      // App ID without the team prefix, nil if unreadable
BOOL ASMVitrineSigningOpensFromLockScreen(void);     // YES when unreadable, so a build that works stays quiet
ASMVitrineModRow *ASMVitrineSigningWarningRow(void);          // nil while the signature is sound
void ASMVitrineCheckSigningOnce(void);
void ASMVitrineShowSigningFixIfPending(void);   // the sheet the tour held back, if any
// When the provisioning profile the build is signed with runs out, read from embedded.mobileprovision:
// nil without one. A free Apple ID's lasts a week, after which Spotify no longer opens.
BOOL ASMVitrineSigningWeekLong(void);
ASMVitrineModRow *ASMVitrineSigningExpiryRow(void);   // "Signed until …", nil without a profile

// Backup.m: the settings out to a JSON file through the share sheet, and back in from one, replacing
// what is set and restarting.
void ASMVitrineExportSettings(void);
void ASMVitrineImportSettings(void);
// A text file for a bug report through the share sheet: the versions and switches, the ad counts, this launch's
// log lines and the config Spotify's server last sent (Shared/AdBlock/Premium.m). No account details or settings
// values beyond the switches named; the log can name songs played.
void ASMVitrineShareDiagnostics(void);

UIViewController *ASMVitrineAboutPage(void);   // the Mod page
