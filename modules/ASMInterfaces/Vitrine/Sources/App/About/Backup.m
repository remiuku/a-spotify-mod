#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <OSLog/OSLog.h>
#import <sys/utsname.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/AdBlock/AdBlock.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "About.h"
#import "Redesigned/Player/Player.h"

// Every key under the prefix travels, the way the reset sweeps them, so a new switch needs nothing
// here. What is left out belongs to this install rather than to its user's choices.
static BOOL isSetting(NSString *key) {
    if (![key hasPrefix:@"asm.interface.vitrine."]) return NO;
    for (NSString *local in @[@"asm.interface.vitrine.adblock.counts", @"asm.interface.vitrine.privacy.counts", @"asm.interface.vitrine.update.",
                              @"asm.interface.vitrine.signing.", @"asm.interface.vitrine.onboarding.", @"asm.interface.vitrine.navbar.stock",
                              @"asm.interface.vitrine.redesign.navbar.stock", @"asm.interface.vitrine.automix.saved",
                              @"asm.interface.vitrine.lossless.savedQuality", @"asm.interface.vitrine.liveActivity.startedAt"]) {
        if ([key hasPrefix:local]) return NO;
    }
    return YES;
}

static NSDictionary *storedDefaults(void) {
    return [NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier] ?: @{};
}

static void showAlert(NSString *title, NSString *message, UIAlertAction *confirm) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    if (confirm) [alert addAction:confirm];
    [alert addAction:[UIAlertAction actionWithTitle:confirm ? @"Cancel" : @"OK" style:UIAlertActionStyleCancel handler:nil]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

void ASMVitrineExportSettings(void) {
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [storedDefaults() enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if (isSetting(key) && [NSJSONSerialization isValidJSONObject:@[value]]) settings[key] = value;
    }];
    NSDictionary *file = @{
        @"mod": @(ASMVitrine_VERSION),
        @"spotify": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        @"settings": settings,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:file options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"spotifyglass-settings.json"]];
    [data writeToURL:url atomically:YES];

    UIViewController *top = ASMVitrineTopController();
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = top.view;
    [top presentViewController:sheet animated:YES completion:nil];
}

void ASMVitrineShareDiagnostics(void) {
    NSMutableString *text = [NSMutableString string];
    struct utsname machine;
    uname(&machine);
    [text appendFormat:@"Vitrine %s, Spotify %@, iOS %@, %s\n", ASMVitrine_VERSION,
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        UIDevice.currentDevice.systemVersion, machine.machine];
    [text appendFormat:@"look %@, hide ads %d, hide upsells %d, spoof premium %d, EeveeSpotify %d\n\n",
        ASMVitrineRedesignedUIStored() ? @"redesign" : @"native", ASMVitrineHidden(ASMVitrineKeyHideAds), ASMVitrineHidden(ASMVitrineKeyHideUpsells),
        ASMVitrineHidden(ASMVitrineKeyFakePremium), ASMVitrineEeveeSpotifyInjected()];
    [text appendString:@"== ads blocked (stopped of checked)\n"];
    for (NSString *label in ASMVitrineAdBlockLabels()) {
        NSUInteger checked = ASMVitrineAdBlockChecked(label);
        [text appendFormat:@"%@: %lu%@\n", label, (unsigned long)ASMVitrineAdBlockCount(label),
            checked == NSNotFound ? @"" : [NSString stringWithFormat:@" of %lu", (unsigned long)checked]];
    }
    // This launch's lines, from the system log: release builds keep none of their own.
    [text appendString:@"\n== log, this launch\n"];
    NSError *error;
    OSLogStore *store = [OSLogStore storeWithScope:OSLogStoreCurrentProcessIdentifier error:&error];
    // FLEX builds dump the screen's views into the log, page after page; the report keeps the lines.
    NSPredicate *ours = [NSPredicate predicateWithFormat:
        @"composedMessage BEGINSWITH '[spotifyglass]' AND NOT composedMessage BEGINSWITH '[spotifyglass] screen dump'"];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (OSLogEntry *entry in [store entriesEnumeratorWithOptions:0 position:nil predicate:ours error:&error]) {
        [lines addObject:[NSString stringWithFormat:@"%@ %@", entry.date, [entry.composedMessage substringFromIndex:15]]];
    }
    // ponytail: the last 1500 lines only; a whole day's launch can hold tens of thousands.
    NSUInteger keep = MIN(lines.count, 1500);
    [text appendString:[[lines subarrayWithRange:NSMakeRange(lines.count - keep, keep)] componentsJoinedByString:@"\n"]];
    if (!lines.count) [text appendFormat:@"(none: %@)", error.localizedDescription ?: @"the log is empty"];
    NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSString *config = [NSString stringWithContentsOfURL:[caches URLByAppendingPathComponent:@"Vitrine/live-config.txt"]
                                                encoding:NSUTF8StringEncoding error:nil];
    [text appendFormat:@"\n\n== config Spotify's server last sent\n%@", config ?: @"(none yet: Spoof Premium is off, or no fetch so far)\n"];

    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"vitrine-diagnostics.txt"]];
    [text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIViewController *top = ASMVitrineTopController();
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    sheet.popoverPresentationController.sourceView = top.view;
    [top presentViewController:sheet animated:YES completion:nil];
}

static Class kindOf(id value) {
    for (Class kind in @[NSNumber.class, NSString.class, NSArray.class, NSDictionary.class]) {
        if ([value isKindOfClass:kind]) return kind;
    }
    return Nil;
}

// A key already stored keeps its type: the hooks send boolValue to whatever they find at launch, and
// an array there would crash Spotify before the reset row could be reached.
// Settings exported by Chroma (spoti.pw 0.50) under its own names, in ours. Its player background knows only
// Fluid (0) and Animated (1); its artwork sources call Spotify's clips "spotify". Its menu row cache and
// one-time notices have no counterpart and are left out.
static NSDictionary *fromChroma(NSDictionary *settings) {
    NSDictionary<NSString *, NSString *> *renamed = @{
        @"asm.interface.vitrine.redesign.sing": @"asm.interface.vitrine.sing",
        @"asm.interface.vitrine.redesign.sing.ignoreHeat": @"asm.interface.vitrine.sing.ignoreHeat",
        @"asm.interface.vitrine.redesign.spatialVoice": @"asm.interface.vitrine.sing.spatial",
        @"asm.interface.vitrine.redesign.player.hideVideoSwitch": @"asm.interface.vitrine.hide.videoSwitch",
        @"asm.interface.vitrine.gestures.head": @"asm.interface.vitrine.headgestures",
        @"asm.interface.vitrine.redesign.inlinePlayer": @"asm.interface.vitrine.redesign.navbar.minimize",
    };
    NSSet<NSString *> *dropped = [NSSet setWithArray:@[@"asm.interface.vitrine.redesign.menuNumbers", @"asm.interface.vitrine.eevee.warned",
                                                       @"asm.interface.vitrine.spotifyversion.warned", @"asm.interface.vitrine.lockscreen.lyricsartwork"]];
    NSMutableDictionary *ours = [NSMutableDictionary dictionary];
    for (NSString *key in settings) {
        id value = settings[key];
        if ([dropped containsObject:key]) continue;
        if ([key isEqualToString:@"asm.interface.vitrine.redesign.player.backdrop"]) {
            ours[@"asm.interface.vitrine.redesign.player.background"] = @([value integerValue] == 1 ? ASMVitrineRPlayerBackgroundAnimated : ASMVitrineRPlayerBackgroundFluid);
        } else if ([key isEqualToString:@"asm.interface.vitrine.redesign.player.artworksources"] && [value isKindOfClass:NSArray.class]) {
            NSMutableArray *sources = [NSMutableArray array];
            for (NSString *source in value) [sources addObject:[source isEqual:@"spotify"] ? @"canvas" : source];
            ours[@"asm.interface.vitrine.motion.sources"] = sources;
        } else {
            ours[renamed[key] ?: key] = value;
        }
    }
    return ours;
}

static void importSettings(NSDictionary *settings) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    settings = fromChroma(settings);
    NSDictionary *stored = storedDefaults();
    for (NSString *key in stored) {
        if (isSetting(key)) [store removeObjectForKey:key];
    }
    NSUInteger skipped = 0;
    for (NSString *key in settings) {
        id value = settings[key];
        id current = stored[key];
        BOOL fits = isSetting(key)
            && [NSPropertyListSerialization propertyList:value isValidForFormat:NSPropertyListBinaryFormat_v1_0]
            && (!current || kindOf(current) == kindOf(value));
        if (fits) [store setObject:value forKey:key];
        else skipped++;
    }
    ASMVitrineLog(@"import: set %lu keys, skipped %lu", (unsigned long)(settings.count - skipped), (unsigned long)skipped);
    ASMVitrineRestartSpotify();
}

@interface ASMVitrineSettingsPicker : NSObject <UIDocumentPickerDelegate>
@end

@implementation ASMVitrineSettingsPicker

- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSData *data = [NSData dataWithContentsOfURL:urls.firstObject];
    id file = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSDictionary *settings = [file isKindOfClass:NSDictionary.class] ? file[@"settings"] : nil;
    if (![settings isKindOfClass:NSDictionary.class]) {
        showAlert(@"Not a settings file", @"Pick a file made by Export settings.", nil);
        return;
    }
    NSString *mod = [file[@"mod"] isKindOfClass:NSString.class] ? file[@"mod"] : @"unknown";
    NSString *message = [NSString stringWithFormat:@"Your settings are replaced by the file's, exported from version %@. Anything it does not have goes back to its default, and Spotify restarts.", mod];
    showAlert(@"Import settings?", message, [UIAlertAction actionWithTitle:@"Import and restart" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        importSettings(settings);
    }]);
}

@end

void ASMVitrineImportSettings(void) {
    static ASMVitrineSettingsPicker *delegate;
    if (!delegate) delegate = [ASMVitrineSettingsPicker new];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON] asCopy:YES];
    picker.delegate = delegate;
    [ASMVitrineTopController() presentViewController:picker animated:YES completion:nil];
}
