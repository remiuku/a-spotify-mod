#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "About.h"
#import "App/Onboarding/Onboarding.h"

// Every key of the mod's is under one prefix, so a reset is a sweep of the defaults with the stock
// marker of ASMSpotiPrefs.h left behind; the hooks read them at launch, so it ends in a restart.
static void resetAll(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSUInteger removed = 0;
    for (NSString *key in [store persistentDomainForName:NSBundle.mainBundle.bundleIdentifier].allKeys) {
        if (![key hasPrefix:@"asm.interface.spotipw."]) continue;
        [store removeObjectForKey:key];
        removed++;
    }
    [store setBool:YES forKey:ASMSpotiKeyStock];
    ASMSpotiLog(@"reset: removed %lu keys", (unsigned long)removed);
    ASMSpotiRestartSpotify();
}

static void confirmReset(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all settings?"
                                                                  message:@"Every switch goes off, flag overrides and the tab bar layout are cleared, and Spotify restarts as it came, with the mod doing nothing until asked. Spotify's own settings are untouched."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset and restart" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { resetAll(); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ASMSpotiTopController() presentViewController:alert animated:YES completion:nil];
}

static ASMSpotiModRow *withSymbol(ASMSpotiModRow *row, NSString *symbol) {
    row.symbol = symbol;
    return row;
}

// Which build this is, whether GitHub has a newer release, and where to reach the mod: without these
// rows a build that is already installed has no way of telling its user that anything moved on.
UIViewController *ASMSpotiAboutPage(void) {
    ASMSpotiModRow *reset = withSymbol(ASMSpotiActionRow(@"Reset all settings", nil, ^{ confirmReset(); }), @"trash");
    reset.color = ASMSpotiRed();
    NSString *spotify = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    // The row reads out where the build stands and opens the changelog of everything newer than it.
    ASMSpotiModRow *updates = ASMSpotiPageRow(@"Updates", ^UIViewController *{ return ASMSpotiUpdatePage(); });
    updates.value = ^NSString *{ return ASMSpotiUpdateStatus(); };
    return [[ASMSpotiModPage alloc] initWithTitle:@"Mod" intro:nil sections:@[
        ASMSpotiSection(nil, @[
            updates,
            ASMSpotiStatRow(@"Version", ^NSString *{ return @(ASMSpoti_VERSION); }),
            ASMSpotiStatRow(@"Spotify", ^NSString *{ return spotify; }),
        ]),
        ASMSpotiSection(nil, @[
            withSymbol(ASMSpotiLinkRow(@"Website", nil, ASMSpotiSiteURL), @"safari"),
            withSymbol(ASMSpotiLinkRow(@"GitHub", nil, ASMSpotiRepoURL), @"chevron.left.forwardslash.chevron.right"),
            withSymbol(ASMSpotiActionRow(@"Welcome tour", nil, ^{ ASMSpotiShowOnboarding(); }), @"map"),
        ]),
        ASMSpotiSection(nil, @[
            withSymbol(ASMSpotiActionRow(@"Export settings", nil, ^{ ASMSpotiExportSettings(); }), @"square.and.arrow.up"),
            withSymbol(ASMSpotiActionRow(@"Import settings", nil, ^{ ASMSpotiImportSettings(); }), @"square.and.arrow.down"),
        ]),
        ASMSpotiSection(nil, @[reset]),
    ] footer:nil];
}
