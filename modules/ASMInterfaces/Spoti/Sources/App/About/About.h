// About: where the build points its user, and whether GitHub has a newer release (Update.m,
// UpdatePage.m). The status is a string for the Updates row; the page's ticker reads it, so the
// check needs no callback, and a check that lands posts ASMSpotiUpdateCheckedNotification for the page
// that is open at the time. ASMSpotiCheckForUpdate(NO) respects a six hour cache, ASMSpotiCheckForUpdate(YES)
// always asks.
#import <UIKit/UIKit.h>
#import "Settings/ASMSpotiModPage.h"

extern NSString *const ASMSpotiUpdateURL;   // spoti.pw's; the site and the repo are in Settings/ASMSpotiPageStyle.h
extern NSString *const ASMSpotiUpdateCheckedNotification;   // on the main thread, after a check ends either way

// One line of a release's changelog: what changed, under the heading Release Please put it under,
// and the commit it came from.
@interface ASMSpotiUpdateChange : NSObject
@property (nonatomic, copy) NSString *kind;   // "Features", "Fixes", ... as the release names it
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *url;    // the commit, nil for a line written by hand
@end

// One GitHub release, as the last check stored it.
@interface ASMSpotiUpdateRelease : NSObject
@property (nonatomic, copy) NSString *version;   // without the tag's v
@property (nonatomic, copy) NSString *date;      // ISO 8601, as GitHub publishes it
@property (nonatomic, copy) NSString *url;       // the release page, where the .deb is
@property (nonatomic, copy) NSArray<ASMSpotiUpdateChange *> *changes;
@end

NSArray<ASMSpotiUpdateRelease *> *ASMSpotiUpdateReleases(void);   // newest first, empty until a check lands
ASMSpotiUpdateRelease *ASMSpotiUpdateNewestRelease(void);
NSString *ASMSpotiUpdateVersion(void);  // nil unless GitHub has a release newer than this build
BOOL ASMSpotiUpdateIsNewer(NSString *version);   // whether that release is newer than the build running
NSString *ASMSpotiUpdateStatus(void);
void ASMSpotiCheckForUpdate(BOOL force);
UIViewController *ASMSpotiUpdatePage(void);   // UpdatePage.m: the state and the changelog

// Usage.m: the body the check posts to spoti.pw, nil while the switch is off. The key sits outside
// "asm.interface.spotipw." so that Reset all settings neither switches the count off nor undoes an opt-out.
#define ASMSpotiKeyUsage @"spotipw.usage"
NSData *ASMSpotiUsageBody(void);
BOOL ASMSpotiUsageOwed(void);        // on, and not yet sent this UTC day
void ASMSpotiUsageNoteAsked(void);

// UpdateNotice.m: the sheet a release newer than this build brings on its own, a few seconds after
// Spotify comes up, once per release. Watched from the settings %ctor; the switch is on the Updates
// page and takes effect at once.
#define ASMSpotiKeyUpdateNotice @"asm.interface.spotipw.update.notice"
void ASMSpotiWatchForUpdates(void);
BOOL ASMSpotiUpdateNoticeShown(void);   // this run, so the donate sheet stays out of its way


// Whether the now playing card on the lock screen can open this build. It depends on the signature,
// not on the mod: iOS launches by the App ID of the application-identifier entitlement, so a build
// whose bundle id is not that App ID cannot be opened from the card. Signing.m says so once.
extern NSString *const ASMSpotiSigningHelpURL;
NSString *ASMSpotiSigningAppIdentifier(void);      // App ID without the team prefix, nil if unreadable
BOOL ASMSpotiSigningOpensFromLockScreen(void);     // YES when unreadable, so a build that works stays quiet
ASMSpotiModRow *ASMSpotiSigningWarningRow(void);          // nil while the signature is sound
void ASMSpotiCheckSigningOnce(void);
void ASMSpotiShowSigningFixIfPending(void);   // the sheet the tour held back, if any

// Backup.m: the settings out to a JSON file through the share sheet, and back in from one, replacing
// what is set and restarting.
void ASMSpotiExportSettings(void);
void ASMSpotiImportSettings(void);

UIViewController *ASMSpotiAboutPage(void);   // the Mod page
