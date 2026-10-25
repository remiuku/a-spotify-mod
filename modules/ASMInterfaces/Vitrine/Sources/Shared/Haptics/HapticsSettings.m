// The Vibrations page, under either look (App/ModSettings.x links it from the main page): the preview at the
// top (ASMVitrineVibrationsPreview.m), then a card per kind, the way the Audio effects page has one per effect.
// Controls is a switch with its strength under it. Music Haptics is two switches in one card that work together:
// Music Haptics itself, the mod's own from the sound while Spotify is in front, with its strength and what it
// follows (a choice that also says whether the rumble plays, rather than a switch of its own that one choice would
// leave with nothing to do) under it; and In the Background, which names the song to iOS's own Music Haptics, with
// what iOS's own is doing under it, or, while Music Haptics is off in Settings > Accessibility, a row saying so.
// The rows under a switch stay where they are, grayed, while it is off. Each strength's slider plays a tap at the
// new strength with each step, and the preview ripples with it.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Haptics.h"
#import "ASMVitrineVibrationsPreview.h"

static NSString *const kMusicInfo = @"The iPhone taps along with the drums and rumbles under the bass, worked out from the sound as Spotify plays it. Only while Spotify is open: iOS stops an app's own haptics in the background, and a song playing on another device through Connect has no sound here to follow.\n\nWith In the Background on too, iOS plays its own haptic track for the songs it has one for, and this waits, so the two never double up.";

static NSString *const kBackgroundInfo = @"Keeps the vibrations going on the lock screen and in other apps, where iOS stops Spotify's own. The mod tells iOS which recording is playing, by its ISRC code from Apple Music's catalog (no sound leaves the phone), and iOS's own Music Haptics, the one Apple Music uses, plays Apple's haptic track for it.\n\nIt needs Settings > Accessibility > Music Haptics on, and only songs Apple has a haptic track for vibrate. While Spotify is open, Music Haptics above plays the others, if it is on.";

NSNotificationName const ASMVitrineMusicHapticsSwitchesChangedNotification = @"ASMVitrineMusicHapticsSwitchesChangedNotification";
NSNotificationName const ASMVitrineSystemMusicHapticsChangedNotification = @"ASMVitrineSystemMusicHapticsChangedNotification";

static NSString *asm_vitrine_status;
static BOOL asm_vitrine_systemOff;

NSString *ASMVitrineMusicHapticsStatus(void) {
    return asm_vitrine_status ?: @"Waiting";
}

void ASMVitrineSetMusicHapticsStatus(NSString *status) {
    asm_vitrine_status = [status copy];
}

BOOL ASMVitrineSystemMusicHapticsOn(void) {
    return !asm_vitrine_systemOff;
}

void ASMVitrineSetSystemMusicHapticsOn(BOOL on) {
    if (asm_vitrine_systemOff == !on) return;
    asm_vitrine_systemOff = !on;
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineSystemMusicHapticsChangedNotification object:nil];
}

static BOOL backgroundAvailable(void) {
    if (@available(iOS 18.0, *)) return YES;
    return NO;
}

BOOL ASMVitrineMusicHapticsOn(void) {
    return ASMVitrineFlag(ASMVitrineKeyMusicHaptics, NO);
}

BOOL ASMVitrineMusicHapticsListedByInstall(void) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"MusicHapticsSupported"] boolValue];
}

BOOL ASMVitrineMusicHapticsInBackground(void) {
    return backgroundAvailable() && ASMVitrineFlag(ASMVitrineKeyMusicHapticsBackground, NO);
}

void ASMVitrineMigrateMusicHaptics(void) {
    // The redesign's old key first: ASMVitrineMigrateKey leaves it where it is once the new one exists.
    ASMVitrineMigrateKey(ASMVitrineKeyMusicHapticsWas, ASMVitrineKeyMusicHaptics);
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if (![store objectForKey:ASMVitrineKeyMusicHapticsMode]) return;
    NSInteger mode = ASMVitrineInt(ASMVitrineKeyMusicHapticsMode, 0);
    ASMVitrineSetEnabled(ASMVitrineKeyMusicHaptics, mode == 1);
    ASMVitrineSetEnabled(ASMVitrineKeyMusicHapticsBackground, mode == 2);
    [store removeObjectForKey:ASMVitrineKeyMusicHapticsMode];
    ASMVitrineLog(@"music haptics: the choice %ld is now Music Haptics %@, In the Background %@", (long)mode, mode == 1 ? @"on" : @"off", mode == 2 ? @"on" : @"off");
}

static NSArray<NSString *> *followsNames(void) {
    return @[@"Everything", @"Beat", @"Bass"];
}

static NSArray<NSString *> *followsNotes(void) {
    return @[@"A tap on each kick and snare, and a rumble under the bass",
             @"A tap on each kick and snare, no rumble",
             @"A tap on each kick, and a rumble under the bass"];
}

static void strengthRange(NSString *key, NSInteger *minimum, NSInteger *maximum) {
    BOOL music = [key isEqualToString:ASMVitrineKeyMusicStrength];
    *minimum = music ? ASMVitrineMusicStrengthMin : ASMVitrineControlStrengthMin;
    *maximum = music ? ASMVitrineMusicStrengthMax : ASMVitrineControlStrengthMax;
}

double ASMVitrineHapticsStrength(NSString *key) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return MAX(minimum, MIN(maximum, ASMVitrineInt(key, 100))) / 100.0;
}

ASMVitrineMusicFollows ASMVitrineMusicHapticsFollows(void) {
    NSInteger follows = ASMVitrineInt(ASMVitrineKeyMusicFollows, ASMVitrineMusicFollowsEverything);
    return follows >= ASMVitrineMusicFollowsEverything && follows <= ASMVitrineMusicFollowsBass ? (ASMVitrineMusicFollows)follows : ASMVitrineMusicFollowsEverything;
}

// A percentage slider over a strength key, telling `changed` each step it stores.
static ASMVitrineModRow *strengthRow(NSString *key, void (^changed)(void)) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return ASMVitrineSliderRow(@"Strength", nil, minimum, maximum, ASMVitrineStrengthStep,
        ^double { return ASMVitrineHapticsStrength(key) * 100; },
        ^(double value) {
            ASMVitrineSetInt(key, lround(value));
            if (changed) changed();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });
}

// The cards, `preview` told when something it reads out changes and shown the slider's taps, `explain` run by a
// tap on the row that says iOS's Music Haptics is off.
static NSArray<ASMVitrineModSection *> *sections(ASMVitrineVibrationsPreview *preview, void (^explain)(void)) {
    ASMVitrineMigrateMusicHaptics();
    __weak ASMVitrineVibrationsPreview *weakPreview = preview;
    ASMVitrineModRow *controls = ASMVitrineSwitchRow(@"Controls", nil, ASMVitrineKeyControlHaptics);
    controls.changed = ^(BOOL on) { [weakPreview reload]; };
    ASMVitrineModRow *controlStrength = strengthRow(ASMVitrineKeyControlStrength, ^{
        // Felt as it is set, and seen: a tap at the new strength with each step, and its ripple.
        ASMVitrinePlayFeedback(ASMVitrineFeedbackAdd);
        [weakPreview rippleAt:ASMVitrineHapticsStrength(ASMVitrineKeyControlStrength)];
    });
    controlStrength.waitsOn = ASMVitrineKeyControlHaptics;

    void (^switched)(BOOL) = ^(BOOL on) {
        [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineMusicHapticsSwitchesChangedNotification object:nil];
        [weakPreview reload];
    };
    ASMVitrineModRow *music = ASMVitrineOptionRow(@"Music Haptics", nil, ASMVitrineKeyMusicHaptics);
    music.info = kMusicInfo;
    music.changed = switched;
    ASMVitrineModRow *musicStrength = strengthRow(ASMVitrineKeyMusicStrength, ^{
        // As Controls' Strength: a kick at the new strength with each step, and its ripple.
        ASMVitrineMusicHapticsSettingsChanged();
        ASMVitrineMusicHapticsPreview();
        [weakPreview rippleAt:ASMVitrineHapticsStrength(ASMVitrineKeyMusicStrength) / 2];
    });
    musicStrength.waitsOn = ASMVitrineKeyMusicHaptics;
    ASMVitrineModRow *follows = ASMVitrineChoiceRow(@"Follows", nil, ASMVitrineKeyMusicFollows, followsNames(), ASMVitrineMusicFollowsEverything);
    follows.choiceNotes = followsNotes();
    follows.chosen = ^(NSInteger index) { ASMVitrineMusicHapticsSettingsChanged(); };
    follows.waitsOn = ASMVitrineKeyMusicHaptics;

    ASMVitrineModRow *background = ASMVitrineOptionRow(@"In the Background", nil, ASMVitrineKeyMusicHapticsBackground);
    background.info = kBackgroundInfo;
    background.changed = switched;
    background.visible = ^BOOL { return backgroundAvailable(); };
    // What iOS's own is doing, or, while it is off in Accessibility, a row saying where to turn it on.
    ASMVitrineModRow *status = ASMVitrineStatRow(@"Status", ^NSString *{ return ASMVitrineMusicHapticsStatus(); });
    status.visible = ^BOOL { return ASMVitrineMusicHapticsInBackground() && ASMVitrineSystemMusicHapticsOn(); };
    // Under In the Background while the install lacks the key iOS lists apps for Music Haptics by.
    ASMVitrineModRow *unlisted = ASMVitrineWarningRow(@"In the Background is missing from this install", @"Tap for why", ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"In the Background is missing"
            message:@"iOS plays Music Haptics only for apps that say they support it, and only Vitrine's IPA build writes that into Spotify. This Spotify was put together another way, such as with Vitrine's .deb injected by hand, so the vibrations stop when Spotify leaves the screen. Music Haptics above still works while Spotify is open. Build the IPA with Vitrine to get both."
            preferredStyle:UIAlertControllerStyleAlert];
        alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
    });
    unlisted.visible = ^BOOL { return backgroundAvailable() && !ASMVitrineMusicHapticsListedByInstall(); };
    ASMVitrineModRow *systemOff = ASMVitrineActionRow(@"Music Haptics is off in iOS", @"Tap to turn it on in Settings", explain);
    systemOff.visible = ^BOOL { return ASMVitrineMusicHapticsInBackground() && !ASMVitrineSystemMusicHapticsOn(); };

    return @[
        ASMVitrineSection(nil, @[ASMVitrineWithSymbol(controls, @"hand.tap"), controlStrength]),
        ASMVitrineSection(nil, @[ASMVitrineWithSymbol(music, @"waveform"), musicStrength, follows, background, unlisted, status, systemOff]),
    ];
}

#pragma mark - the page

@interface ASMVitrineVibrationsPage : ASMVitrineModPage
@property (nonatomic, strong) ASMVitrineVibrationsPreview *preview;
@end

@implementation ASMVitrineVibrationsPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = self.preview;
    // Music Haptics turned on or off in Accessibility while the page is open, or before coming back to it.
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(systemMusicHapticsChanged:) name:ASMVitrineSystemMusicHapticsChangedNotification object:nil];
}

- (void)systemMusicHapticsChanged:(NSNotification *)note {
    [self refreshVisibility];
}

// The header keeps the height it is given, so it is sized here and handed back to the table only when that
// changes (a table header set on every pass lays the table out again forever).
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.preview reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.preview.listening = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.preview.listening = NO;
}

// The row under In the Background that says iOS's Music Haptics is off: what it needs, and the way there.
- (void)explainBackground {
    // iOS opens no Settings page but an app's own from a third-party app (App-prefs: links fail on iOS 27), so the
    // message gives the path from there.
    NSString *message = @"In the Background needs iOS's Music Haptics. Settings opens on Spotify's page: go back to Settings, then Accessibility > Music Haptics, and turn it on.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Turn On Music Haptics" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Not Now" style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *open = [UIAlertAction actionWithTitle:@"Open Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
    }];
    [alert addAction:open];
    alert.preferredAction = open;
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMVitrineVibrationsSettingsPage(void) {
    ASMVitrineVibrationsPreview *preview = [ASMVitrineVibrationsPreview new];
    __block __weak ASMVitrineVibrationsPage *weakPage;
    NSArray<ASMVitrineModSection *> *cards = sections(preview, ^{ [weakPage explainBackground]; });
    ASMVitrineVibrationsPage *page = [[ASMVitrineVibrationsPage alloc] initWithTitle:@"Vibrations" intro:nil sections:cards footer:nil];
    page.preview = preview;
    weakPage = page;
    return page;
}

