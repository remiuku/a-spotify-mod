// The Sing page (Sing on Mod Settings' main page, and Lyrics > Karaoke), under either look: the card at its top
// (ASMVitrineSingCard.m: the song, what Sing is doing, the vocals and the rest traced live, play and pause, the vocals'
// level and its three stops), Sing's switch, which turns the mic on and off at once, Ignore heat warnings, the voice
// model (Best quality or Light, the chosen one's download and removal, and the other's removal), spatial voice's page (its preview, ASMVitrineSpatialPreview.m, and its switch), and Runs on under
// Advanced. While the page is on screen with Spotify in front, the card's reads of its lines keep Sing separating
// the playing song even at As sung, where it otherwise rests (ASMVitrineSingReadLevels), so what the card shows and what
// its slider sets are heard at once; popped, covered or in the background, the page no longer counts.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Sing.h"
#import <sys/utsname.h>

// Chips before the A14 (the iPhone XS, XR, 11 and SE 2: iPhone11,x and iPhone12,x) are untested and may not keep up.
static BOOL untestedChip(void) {
    struct utsname name;
    int major = 0;
    return uname(&name) == 0 && sscanf(name.machine, "iPhone%d,", &major) == 1 && major < 13;
}

UIView *ASMVitrineSingCardView(void);   // ASMVitrineSingCard.m

static void tell(NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

static void ask(NSString *title, NSString *message, NSString *action, BOOL destructive, void (^then)(void)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:action style:destructive ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { then(); }]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

NSString *ASMVitrineSingLevelText(double level) {
    if (level <= 0.001) return @"Gone";
    if (level < 0.999) return [NSString stringWithFormat:@"%.0f%%", level * 100];
    if (level <= 1.001) return @"As sung";
    if (level >= 1.999) return @"Vocals only";
    return [NSString stringWithFormat:@"Backing %.0f%%", (2 - level) * 100];
}

static NSString *bytes(long long count) {
    return [NSByteCountFormatter stringFromByteCount:count countStyle:NSByteCountFormatterCountStyleFile];
}

// The row's state: with the old model, its update reads as the model's download, worded as an update.
static ASMVitrineSingModelState rowState(void) {
    if (ASMVitrineSingModelUpdateDownloading()) return ASMVitrineSingModelDownloading;
    if (ASMVitrineSingModelUpdateAvailable()) return ASMVitrineSingModelMissing;
    return ASMVitrineSingModelCurrentState();
}

static NSString *modelValue(void) {
    if (!ASMVitrineSingOSSupported()) return @"Unavailable";
    BOOL update = ASMVitrineSingModelUpdateAvailable();
    switch (rowState()) {
        case ASMVitrineSingModelDownloading:
            if (ASMVitrineSingModelChecking()) return @"Checking…";
            if (ASMVitrineSingModelWaitingForNetwork()) return ASMVitrineSingModelOverCellular() ? @"Waiting for the network" : @"Waiting for Wi-Fi";
            return [NSString stringWithFormat:@"%.0f%%", ASMVitrineSingModelProgress() * 100];
        case ASMVitrineSingModelReady: return [NSString stringWithFormat:@"Downloaded · %@", ASMVitrineSingModelSizeText()];
        case ASMVitrineSingModelMissing:
            if (ASMVitrineSingModelError()) return update ? @"Update failed, try again" : @"Failed, try again";
            if (ASMVitrineSingModelPausedBytes()) {
                return [NSString stringWithFormat:@"%@ · %@ of %@", update ? @"Update paused" : @"Paused", bytes(ASMVitrineSingModelPausedBytes()), ASMVitrineSingModelSizeText()];
            }
            return [NSString stringWithFormat:update ? @"Update available · %@" : @"Download, %@", ASMVitrineSingModelSizeText()];
    }
    return @"";
}

static void modelTapped(UITableViewController *page) {
    if (!ASMVitrineSingOSSupported()) {
        tell(@"Voice model", ASMVitrineSingMissing());
        return;
    }
    switch (rowState()) {
        case ASMVitrineSingModelMissing: {
            BOOL update = ASMVitrineSingModelUpdateAvailable();
            NSString *message = [NSString stringWithFormat:@"%@%@%@ from Hugging Face. It waits for Wi-Fi unless you let it use cellular. It stays on this iPhone, and no audio leaves it.",
                                 ASMVitrineSingModelError() ? [NSString stringWithFormat:@"The last try failed: %@\n\n", ASMVitrineSingModelError()] : @"",
                                 update ? @"The new voice model runs on the Neural Engine, faster and cooler, and Karaoke keeps the one it has until it is in. " : @"",
                                 ASMVitrineSingModelSizeText()];
            if (untestedChip()) {
                message = [message stringByAppendingString:ASMVitrineSingChosenModel() == ASMVitrineSingModelLight
                    ? @"\n\nKaraoke is tested on the iPhone 15 Pro. On iPhones older than the iPhone 12 it may not keep up, even with the light model."
                    : @"\n\nKaraoke is tested on the iPhone 15 Pro. On iPhones older than the iPhone 12 it may not keep up; the light model has a better chance."];
            }
            NSString *title = ASMVitrineSingModelPausedBytes() ? (update ? @"Carry on with the update?" : @"Carry on with the download?")
                                                       : (update ? @"Download the update?" : @"Download the voice model?");
            ask(title, message, @"Download", NO, ^{ ASMVitrineSingDownloadModel(); });
            break;
        }
        case ASMVitrineSingModelDownloading:
            if (ASMVitrineSingModelWaitingForNetwork() && !ASMVitrineSingModelOverCellular()) {
                ask(@"Download over cellular?", [NSString stringWithFormat:@"The download waits for Wi-Fi. Over cellular or a Low Data Mode network it uses up to %@ of your plan.",
                                                 ASMVitrineSingModelSizeText()], @"Use cellular", NO, ^{ ASMVitrineSingDownloadModelOverCellular(); });
                break;
            }
            ask(@"Stop the download?", @"What has come in is kept, so the next download carries on from it.", @"Stop", YES, ^{ ASMVitrineSingCancelModelDownload(); });
            break;
        case ASMVitrineSingModelReady:
            ask(@"Delete the voice model?", [NSString stringWithFormat:@"It frees %@. Karaoke needs it again to turn the vocals down.", ASMVitrineSingModelInUseSizeText()],
                @"Delete", YES, ^{
                    ASMVitrineSetSingOn(NO);
                    ASMVitrineSingDeleteModel();
                    // Sing's switch goes off with it.
                    [page.tableView reloadData];
                });
            break;
    }
}

// Spatial voice's page, under Sing's: the preview at its top and the switch.
@interface ASMVitrineSpatialVoicePage : ASMVitrineModPage
@property (nonatomic, readonly) ASMVitrineSpatialPreview *preview;
@end

@implementation ASMVitrineSpatialVoicePage

- (void)viewDidLoad {
    [super viewDidLoad];
    _preview = [[ASMVitrineSpatialPreview alloc] initWithFrame:CGRectMake(0, 0, self.tableView.bounds.size.width, 0)];
    self.tableView.tableHeaderView = _preview;
}

// Its caption follows Dynamic Type and what the preview is doing, so the header is sized to it, and handed back
// only when that size changes (ASMVitrineFitNote's way: the table lays out again on every handing back).
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGSize size = [_preview sizeThatFits:CGSizeMake(table.bounds.size.width, 0)];
    if (CGSizeEqualToSize(_preview.bounds.size, size)) return;
    _preview.frame = (CGRect){_preview.frame.origin, size};
    table.tableHeaderView = _preview;
}

@end

UIViewController *ASMVitrineSpatialVoiceSettingsPage(void) {
    ASMVitrineModRow *spatial = ASMVitrineOptionRow(@"Spatial voice", nil, ASMVitrineKeySingSpatial);
    __block __weak ASMVitrineSpatialVoicePage *page;
    spatial.changed = ^(BOOL on) {
        ASMVitrineSetSingSpatial(on);
        [page.preview refresh];
    };
    ASMVitrineSpatialVoicePage *made = [[ASMVitrineSpatialVoicePage alloc] initWithTitle:@"Spatial voice" intro:nil sections:@[
        ASMVitrineNotedSection(nil, @[spatial],
                       @"The singer's voice keeps its place in front of you as you turn your head, while the rest of the song turns with "
                       @"you; stay turned, and it comes round in front again. It follows your head through headphones that "
                       @"track it: AirPods Pro, AirPods 3 or later, AirPods Max, and asks for Motion & Fitness the first time. "
                       @"While iOS's own Spatialize Stereo is on, which already holds the whole song in place, the voice is left to it."),
        ASMVitrineNotedSection(@"Sound", @[
            ASMVitrineSliderRow(@"Distance", nil, 1, 6.5, 0.5, ^double { return ASMVitrineSingSpatialDistance(); }, ^(double value) {
                ASMVitrineSetSingSpatialSound(value, ASMVitrineSingSpatialRoom(), ASMVitrineSingSpatialFront(), ASMVitrineSingSpatialWidth());
            }, ^NSString *(double value) { return [NSString stringWithFormat:@"%.1f m", value]; }),
            ASMVitrineSliderRow(@"Room", nil, 0, 100, 5, ^double { return ASMVitrineSingSpatialRoom(); }, ^(double value) {
                ASMVitrineSetSingSpatialSound(ASMVitrineSingSpatialDistance(), value, ASMVitrineSingSpatialFront(), ASMVitrineSingSpatialWidth());
            }, ^NSString *(double value) { return [NSString stringWithFormat:@"%.0f%%", value]; }),
            ASMVitrineSliderRow(@"Back in front", nil, 5, 60, 1, ^double { return ASMVitrineSingSpatialFront(); }, ^(double value) {
                ASMVitrineSetSingSpatialSound(ASMVitrineSingSpatialDistance(), ASMVitrineSingSpatialRoom(), value, ASMVitrineSingSpatialWidth());
            }, ^NSString *(double value) { return [NSString stringWithFormat:@"After %.0f s", value]; }),
            ASMVitrineSliderRow(@"Instruments width", nil, 0, 200, 5, ^double { return ASMVitrineSingSpatialWidth(); }, ^(double value) {
                ASMVitrineSetSingSpatialSound(ASMVitrineSingSpatialDistance(), ASMVitrineSingSpatialRoom(), ASMVitrineSingSpatialFront(), value);
            }, ^NSString *(double value) { return [NSString stringWithFormat:@"%.0f%%", value]; }),
        ], @"How far ahead the voice sings, and how much of the room you hear around it: farther, the voice is quieter and "
           @"more of it is the room. Back in front is how long a head that stays turned takes to bring the voice ahead again. "
           @"Instruments width spreads the rest of the song wider than the recording, or narrows it below 100%."),
    ] footer:nil];
    page = made;
    return made;
}

// The Sing page: the card (ASMVitrineSingCard.m) as the table's header, sized to Dynamic Type, then its rows.
@interface ASMVitrineSingPage : ASMVitrineModPage
@end

@implementation ASMVitrineSingPage {
    UIView *_card;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _card = ASMVitrineSingCardView();
    self.tableView.tableHeaderView = _card;
}

// Handed back only when its size changes (ASMVitrineFitNote's way: the table lays out again on every handing back).
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGSize size = [_card sizeThatFits:CGSizeMake(table.bounds.size.width, 0)];
    if (CGSizeEqualToSize(_card.bounds.size, size)) return;
    _card.frame = (CGRect){_card.frame.origin, size};
    table.tableHeaderView = _card;
}

@end

NSNotificationName const ASMVitrineSingButtonDidChangeNotification = @"ASMVitrineSingButtonDidChangeNotification";

UIViewController *ASMVitrineSingSettingsPage(void) {
    ASMVitrineModRow *sing = ASMVitrineOptionRow(@"Karaoke", nil, ASMVitrineKeySing);
    sing.changed = ^(BOOL on) { ASMVitrineSetSingOn(on); };
    // Only the redesign's lyrics have the mic.
    ASMVitrineModRow *button = ASMVitrineSwitchRow(@"Toggle from lyrics", @"The mic in the corner of the lyrics", ASMVitrineKeySingButton);
    button.changed = ^(BOOL on) { [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineSingButtonDidChangeNotification object:nil]; };
    button.visible = ^BOOL { return ASMVitrineRedesignedUIStored(); };
    ASMVitrineModRow *heat = ASMVitrineOptionRow(@"Ignore heat warnings", @"Keeps Karaoke going on a hot iPhone, which then gets hotter", ASMVitrineKeySingIgnoreHeat);
    ASMVitrineModRow *memory = ASMVitrineOptionRow(@"Ignore memory warnings", @"Keeps Karaoke going when iOS is low on memory, which may then close Spotify",
                                   ASMVitrineKeySingIgnoreMemory);
    heat.changed = ^(BOOL on) { ASMVitrineSetSingIgnoresHeat(on); };
    __block __weak ASMVitrineModPage *page;
    ASMVitrineModRow *model = ASMVitrineStatActionRow(@"Voice model", nil, ^NSString *{ return modelValue(); }, ^{ modelTapped(page); });
    ASMVitrineModRow *remove = ASMVitrineActionRow(@"Remove voice model", nil, ^{
        BOOL partial = ASMVitrineSingModelCurrentState() != ASMVitrineSingModelReady;
        ask(partial ? @"Remove the paused download?" : @"Remove the voice model?",
            partial ? [NSString stringWithFormat:@"It frees %@. A new download starts from the beginning.", bytes(ASMVitrineSingModelPausedBytes())]
                    : [NSString stringWithFormat:@"It frees %@. Karaoke needs it again to turn the vocals down.", ASMVitrineSingModelInUseSizeText()],
            @"Remove", YES, ^{
                ASMVitrineSetSingOn(NO);
                ASMVitrineSingDeleteModel();
                [page.tableView reloadData];
            });
    });
    remove.color = ASMVitrineRed();
    remove.visible = ^BOOL { return ASMVitrineSingModelCurrentState() == ASMVitrineSingModelReady || ASMVitrineSingModelPausedBytes() > 0; };
    // The two models, picked on the page: the rows below follow the one with the checkmark.
    ASMVitrineModRow *(^choice)(NSString *, NSString *, ASMVitrineSingModelKind) = ^ASMVitrineModRow *(NSString *title, NSString *format, ASMVitrineSingModelKind kind) {
        ASMVitrineModRow *row = ASMVitrineActionRow(title, [NSString stringWithFormat:format, ASMVitrineSingModelSizeTextOf(kind)], ^{
            if (ASMVitrineSingChosenModel() == kind) return;
            void (^choose)(void) = ^{
                ASMVitrineSetSingChosenModel(kind);
                [page.tableView reloadData];
                [page refreshVisibility];
            };
            BOOL downloading = ASMVitrineSingModelCurrentState() == ASMVitrineSingModelDownloading || ASMVitrineSingModelUpdateDownloading();
            if (!downloading) choose();
            else ask(@"Stop the download?", @"The voice model coming in stops, and what has come in is kept for when you choose it again.", @"Switch", NO, choose);
        });
        row.checked = ^BOOL { return ASMVitrineSingChosenModel() == kind; };
        return row;
    };
    ASMVitrineModRow *full = choice(@"Best quality", @"The full model, %@: the cleanest result, for recent iPhones", ASMVitrineSingModelFull);
    ASMVitrineModRow *light = choice(@"Light", @"A small model, %@, for older iPhones: more of the voice is left in, and the music dips under it",
                             ASMVitrineSingModelLight);
    ASMVitrineModRow *other = ASMVitrineStatActionRow(@"Remove the other model", nil, ^NSString *{ return bytes(ASMVitrineSingOtherModelBytes()); }, ^{
        NSString *name = ASMVitrineSingChosenModel() == ASMVitrineSingModelFull ? @"Light" : @"Best quality";
        ask(@"Remove the other model?", [NSString stringWithFormat:@"%@ is not in use. Removing it frees %@, and choosing it again downloads it again.",
                                         name, bytes(ASMVitrineSingOtherModelBytes())],
            @"Remove", YES, ^{
                ASMVitrineSingDeleteOtherModel();
                [page refreshVisibility];
            });
    });
    other.color = ASMVitrineRed();
    other.visible = ^BOOL { return ASMVitrineSingOtherModelBytes() > 0; };
    ASMVitrineModRow *spatial = ASMVitrinePageRow(@"Spatial voice", ^UIViewController *{ return ASMVitrineSpatialVoiceSettingsPage(); });
    spatial.subtitle = @"With AirPods, the voice stays in front of you as you turn your head";
    spatial.value = ^NSString *{ return ASMVitrineSingSpatial() ? @"On" : @"Off"; };
    // Facts about the iPhone, which do not change while the page shows.
    spatial.visible = ^BOOL { return ASMVitrineSingSpatialAvailable(); };
    ASMVitrineModRow *units = ASMVitrineChoiceRow(@"Runs on", nil, ASMVitrineKeySingComputeUnits, ASMVitrineSingComputeUnitNames(), 0);
    units.choiceNotes = @[@"The Neural Engine, the fastest, with the CPU while it loads", @"Slower and warmer, and a little less memory"];
    units.choiceFooter = @"Karaoke loads the voice model on the CPU first and starts with it. On Automatic a second copy then loads on "
                         @"the Neural Engine and takes over, in the background too. The iPhone prepares it the first time after Vitrine "
                         @"is installed or updated, for a minute or so, and Karaoke runs on the CPU until then, unless Prepare after "
                         @"updates did it already. If it does not load, "
                         @"Karaoke stays on the CPU until Spotify is opened again.";
    units.chosen = ^(NSInteger index) { ASMVitrineSingComputeUnitsChanged(); };
    ASMVitrineModRow *prepare = ASMVitrineSwitchRow(@"Prepare after updates",
                                    @"Readies the Neural Engine in the background after Vitrine or iOS updates, so Karaoke starts at full speed", ASMVitrineKeySingPrepareAhead);
    ASMVitrineSingPage *made = [[ASMVitrineSingPage alloc] initWithTitle:@"Karaoke" intro:nil sections:@[
        ASMVitrineSection(nil, @[sing, button, heat, memory]),
        ASMVitrineNotedSection(@"Voice model", @[full, light, model, remove, other],
                       @"Each model is downloaded and kept on its own, and Karaoke needs only the chosen one. A switch takes effect "
                       @"without restarting Spotify: the model loads in a few seconds, and the song plays as it is until it is in."),
        ASMVitrineSection(nil, @[spatial]),
        ASMVitrineNotedSection(@"Advanced", @[units, prepare],
                       @"Karaoke turns a song's vocals down to sing over, or the rest down to hear the vocals alone, with a voice model that "
                       @"runs only on this iPhone: no audio leaves it. It listens a few seconds ahead of what plays, so the vocals change a "
                       @"few seconds after a song starts or after a seek."),
    ] footer:nil];
    page = made;
    return made;
}
