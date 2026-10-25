#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "About.h"
#import "App/Onboarding/Onboarding.h"
#import "Shared/AutoMix/AutoMix.h"
#import "Shared/Lossless/LosslessQuality.h"

// Every key of the mod's is under one prefix, so a reset is a sweep of the defaults with the stock
// marker of ASMVitrinePrefs.h left behind; the hooks read them at launch, so it ends in a restart.
static void resetAll(void) {
    // Spotify's own settings that AutoMix and Lossless changed go back first, while the keys that hold them are there.
    ASMVitrineAutoMixApply(NO);
    ASMVitrineLosslessLowerQuality(NO);
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSUInteger removed = 0;
    for (NSString *key in [store persistentDomainForName:NSBundle.mainBundle.bundleIdentifier].allKeys) {
        if (![key hasPrefix:@"asm.interface.vitrine."]) continue;
        [store removeObjectForKey:key];
        removed++;
    }
    [store setBool:YES forKey:ASMVitrineKeyStock];
    ASMVitrineLog(@"reset: removed %lu keys", (unsigned long)removed);
    ASMVitrineRestartSpotify();
}

static void confirmReset(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all settings?"
                                                                  message:@"Every switch goes off, flag overrides and the tab bar layout are cleared, and Spotify restarts as it came, with the mod doing nothing until asked. Spotify's own settings are untouched."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset and restart" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) { resetAll(); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

static ASMVitrineModRow *withSymbol(ASMVitrineModRow *row, NSString *symbol) {
    row.symbol = symbol;
    return row;
}

// Which build this is, whether GitHub has a newer release, and where to reach the mod: without these
// rows a build that is already installed has no way of telling its user that anything moved on.
UIViewController *ASMVitrineAboutPage(void) {
    ASMVitrineModRow *reset = withSymbol(ASMVitrineActionRow(@"Reset all settings", nil, ^{ confirmReset(); }), @"trash");
    reset.color = ASMVitrineRed();
    NSString *spotify = ASMVitrineSpotifyVersion();
    if ([ASMVitrineSpotifyLikelyWorksVersions containsObject:spotify]) spotify = [spotify stringByAppendingString:@", likely works"];
    else if (![ASMVitrineSpotifySupportedVersions containsObject:spotify]) spotify = [NSString stringWithFormat:@"%@, made for %@", spotify, ASMVitrineSpotifyMadeFor];
    // The row reads out where the build stands and opens the changelog of everything newer than it.
    ASMVitrineModRow *updates = ASMVitrinePageRow(@"Updates", ^UIViewController *{ return ASMVitrineUpdatePage(); });
    updates.value = ^NSString *{ return ASMVitrineUpdateStatus(); };
    // A release build can opt into betas; a beta build starts opted in. Either way a check follows at
    // once, since the stored list only holds what counted at the last one.
    ASMVitrineModRow *betas = ASMVitrineSwitchRow(@"Include betas", @"Offer test builds ahead of each release", ASMVitrineKeyUpdateBetas);
    betas.defaultOn = ASMVitrineBuildIsBeta();
    betas.changed = ^(BOOL on) { ASMVitrineCheckForUpdate(YES); };
    NSMutableArray<ASMVitrineModRow *> *links = [NSMutableArray array];
    if (ASMVitrineRepoURL) [links addObject:withSymbol(ASMVitrineLinkRow(@"GitHub", nil, ASMVitrineRepoURL), @"chevron.left.forwardslash.chevron.right")];
    [links addObjectsFromArray:@[
        withSymbol(ASMVitrinePageRow(@"Licenses", ^UIViewController *{ return ASMVitrineLicensesPage(); }), @"doc.text"),
        withSymbol(ASMVitrineActionRow(@"Welcome tour", nil, ^{ ASMVitrineShowOnboarding(); }), @"map"),
    ]];
    if (ASMVitrineWhatsNewChanges().count) [links insertObject:withSymbol(ASMVitrineActionRow(@"What's New", nil, ^{ ASMVitrineShowWhatsNew(); }), @"sparkles") atIndex:links.count - 1];
    NSMutableArray<ASMVitrineModRow *> *build = [NSMutableArray arrayWithObjects:updates, betas,
        ASMVitrineStatRow(@"Version", ^NSString *{ return @(ASMVitrine_VERSION); }),
        ASMVitrineStatRow(@"Spotify", ^NSString *{ return spotify; }), nil];
    ASMVitrineModRow *signedUntil = ASMVitrineSigningExpiryRow();
    if (signedUntil) [build addObject:signedUntil];
    return [[ASMVitrineModPage alloc] initWithTitle:@"Mod" intro:nil sections:@[
        ASMVitrineSection(nil, build),
        ASMVitrineSection(nil, links),
        ASMVitrineSection(nil, @[
            withSymbol(ASMVitrineActionRow(@"Export settings", nil, ^{ ASMVitrineExportSettings(); }), @"square.and.arrow.up"),
            withSymbol(ASMVitrineActionRow(@"Import settings", nil, ^{ ASMVitrineImportSettings(); }), @"square.and.arrow.down"),
            withSymbol(ASMVitrineActionRow(@"Share diagnostics", @"For a bug report: versions, ad counts, this launch's log and Spotify's config. Song names can show.",
                                   ^{ ASMVitrineShareDiagnostics(); }), @"stethoscope"),
        ]),
        ASMVitrineSection(nil, @[reset]),
    ] footer:nil];
}
