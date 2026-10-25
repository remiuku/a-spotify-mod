// The Live Activity page (App/ModSettings.x links it from the root, under either look): the preview at its top
// (ASMVitrineLiveActivityPreview.m), then the switch, the view and the card's options, which the tick reads, so they
// apply at once to a card that is showing.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Shared/Player/SleepTimer.h"
#import "LiveActivity.h"
#import "ASMVitrineLiveActivityPreview.h"

static NSArray<NSString *> *viewNames(void) {
    return @[@"Lyrics", @"Queue", @"Control menu"];
}

@interface ASMVitrineLiveActivityPage : ASMVitrineModPage
@property (nonatomic, strong) ASMVitrineLiveActivityPreview *preview;
@end

@implementation ASMVitrineLiveActivityPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = self.preview;
}

// Handed back to the table only when its size changes (ASMVitrineFitNote's way: the table lays out again on every handing back).
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width;
    self.preview.layoutMargins = UIEdgeInsetsMake(0, table.layoutMargins.left, 0, table.layoutMargins.right);
    CGSize size = CGSizeMake(width, [self.preview heightForWidth:width]);
    if (CGSizeEqualToSize(self.preview.bounds.size, size)) return;
    self.preview.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = self.preview;
}

// Back from Shows' or Text size's list, the preview reads them again.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.preview reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.preview.running = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.preview.running = NO;
}

@end

// A menu row of `names` stored under `key`, which shows the preview the new choice.
static ASMVitrineModRow *menuRow(NSString *title, NSString *key, NSArray<NSString *> *names, NSInteger fallback, ASMVitrineLiveActivityPreview *preview) {
    __weak ASMVitrineLiveActivityPreview *weakPreview = preview;
    return ASMVitrineMenuRow(title, names, ^NSString *{
        NSInteger index = ASMVitrineInt(key, fallback);
        return names[(NSUInteger)(index >= 0 && index < (NSInteger)names.count ? index : fallback)];
    }, ^(NSInteger index) {
        ASMVitrineSetInt(key, index);
        [weakPreview reload];
    });
}

BOOL ASMVitrineLiveActivityAllowedByInstall(void) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSSupportsLiveActivities"] boolValue];
}

// At the top while the install lacks the key, saying why nothing shows and what to do.
static ASMVitrineModRow *missingRow(void) {
    ASMVitrineModRow *row = ASMVitrineWarningRow(@"Missing from this install", @"Tap for why", ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Live Activity is missing"
            message:@"iOS shows a Live Activity only for an app that says it has one, and only Vitrine's IPA build writes that into Spotify. This Spotify was put together another way, such as with Vitrine's .deb injected by hand, so iOS turns the card down. Build the IPA with Vitrine to get it."
            preferredStyle:UIAlertControllerStyleAlert];
        alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
    });
    row.visible = ^BOOL { return !ASMVitrineLiveActivityAllowedByInstall(); };
    return row;
}

UIViewController *ASMVitrineLiveActivitySettingsPage(void) {
    ASMVitrineLiveActivityPreview *preview = [ASMVitrineLiveActivityPreview new];
    __weak ASMVitrineLiveActivityPreview *weakPreview = preview;
    void (^switched)(BOOL) = ^(BOOL on) { [weakPreview reload]; };

    ASMVitrineModRow *on = ASMVitrineOptionRow(@"Live Activity", nil, ASMVitrineKeyLiveActivity);
    on.changed = ^(BOOL value) { ASMVitrineSetLiveActivityEnabled(value); };
    ASMVitrineModRow *view = ASMVitrineChoiceRow(@"Shows", nil, ASMVitrineKeyLiveActivityView, viewNames(), ASMVitrineLiveActivityLyrics);
    // The lyrics view's own rows, shown while it is picked.
    ASMVitrineModRow *without = menuRow(@"Without lyrics", ASMVitrineKeyLiveActivityWithoutLyrics, @[@"Note", @"Track"], ASMVitrineLiveActivityWithoutLyricsNote, preview);
    ASMVitrineModRow *alignment = menuRow(@"Alignment", ASMVitrineKeyLiveActivityAlignment, @[@"Left", @"Center"], ASMVitrineLiveActivityAlignCenter, preview);
    ASMVitrineModRow *translation = ASMVitrineOptionRow(@"Translations", @"Under the line, when the lyrics have one", ASMVitrineKeyLiveActivityTranslation);
    translation.changed = switched;
    ASMVitrineModRow *size = ASMVitrineChoiceRow(@"Text size", nil, ASMVitrineKeyLiveActivityTextSize, @[@"Small", @"Medium", @"Large"], ASMVitrineLiveActivityTextMedium);
    for (ASMVitrineModRow *row in @[without, alignment, translation, size]) row.visible = ^BOOL { return ASMVitrineInt(ASMVitrineKeyLiveActivityView, ASMVitrineLiveActivityLyrics) == ASMVitrineLiveActivityLyrics; };
    // Every view's.
    ASMVitrineModRow *artwork = ASMVitrineSwitchRow(@"Artwork", @"The cover beside the track's name and in the Dynamic Island", ASMVitrineKeyLiveActivityArtwork);
    artwork.changed = switched;
    ASMVitrineModRow *colors = menuRow(@"Colors", ASMVitrineKeyLiveActivityColors, @[@"Spotify", @"Artwork", @"Plain"], ASMVitrineLiveActivityColorsSpotify, preview);
    ASMVitrineModRow *progress = ASMVitrineSwitchRow(@"Progress bar", nil, ASMVitrineKeyLiveActivityProgressBar);
    progress.changed = switched;
    // The sleep timer's own: the card's Timer tab, the Sleep Timer shortcut and its control all fade by it, card on or
    // off, and so does Spotify's own timer from the player's menu (Shared/Player/SpotifySleepTimer.m).
    NSArray<NSString *> *fades = ASMVitrineSleepTimerFadeNames();
    ASMVitrineModRow *fade = ASMVitrineMenuRow(@"Fade out", fades, ^NSString *{ return fades[(NSUInteger)ASMVitrineSleepTimerFadeChoice()]; },
                               ^(NSInteger index) { ASMVitrineSetInt(ASMVitrineKeySleepTimerFade, index); });
    ASMVitrineLiveActivityPage *page = [[ASMVitrineLiveActivityPage alloc] initWithTitle:@"Live Activity" intro:nil sections:@[
        ASMVitrineSection(nil, @[missingRow(), on, view, without, alignment, translation, size]),
        ASMVitrineNotedSection(@"Card", @[artwork, colors, progress],
                       @"Colors: Spotify puts the cover's color behind Spotify's green, Artwork takes the green from the cover too, "
                       @"and Plain is white on the lock screen's own background. "
                       @"The card also shows on a paired Apple Watch, in its Smart Stack, from iOS 18, and in CarPlay from iOS 26, "
                       @"as a smaller card of the line or the track. A tap there opens Spotify on the iPhone."),
        ASMVitrineNotedSection(@"Sleep timer", @[fade],
                       @"How long the sound fades before a sleep timer pauses Spotify: the one set from the Timer tab, the Sleep Timer shortcut or Control Center, and Spotify's own from the player's ⋯ menu."),
    ] footer:nil];
    page.preview = preview;
    return page;
}
