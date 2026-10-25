// The Audio effects page. It is not an ASMVitrineModPage: its sliders store as they move, its cards open out
// into their controls as their switches go on, and its status line and the effects' errors come and go
// while it is open, none of which a page of fixed rows does. It keeps Settings/'s look all the same: the
// cards, the 13pt titles over 11pt subtitles, the tiles, the value and the chevron, the checkmark lists.
#import <CoreText/SFNTLayoutTypes.h>
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "AudioEffectsPage.h"
#import "ASMVitrineDSPCurveView.h"

typedef NS_ENUM(NSInteger, ASMVitrineDSPRowKind) {
    ASMVitrineDSPRowSlider,   // a number, stored as the slider moves
    ASMVitrineDSPRowChoice,   // one of a list of names, stored as its index
    ASMVitrineDSPRowPage,     // a page of its own, its value beside the chevron
    ASMVitrineDSPRowCurve,    // the equalizer's or the compressor's gains
};

@interface ASMVitrineDSPRow : NSObject
@property (nonatomic) ASMVitrineDSPRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *unit;
@property (nonatomic, copy) NSArray<NSString *> *names;   // a choice's, or what a slider's steps read as
@property (nonatomic) double scale;                        // what a slider's stored number is shown times
@property (nonatomic, copy) NSString *(^value)(void);
@property (nonatomic, copy) UIViewController *(^page)(void);
@end

@implementation ASMVitrineDSPRow
@end

// An effect's card: the switch at its head and the rows it opens out into while the switch is on.
@interface ASMVitrineDSPEffect : NSObject
@property (nonatomic, copy) NSString *key;   // the switch; nil for output control, which is always on
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSArray<ASMVitrineDSPRow *> *rows;
@end

@implementation ASMVitrineDSPEffect
@end

#pragma mark - the effects

static ASMVitrineDSPRow *row(ASMVitrineDSPRowKind kind, NSString *title, NSString *key) {
    ASMVitrineDSPRow *row = [ASMVitrineDSPRow new];
    row.kind = kind;
    row.title = title;
    row.key = key;
    row.scale = 1;
    return row;
}

static ASMVitrineDSPRow *slider(NSString *title, NSString *key, NSString *unit) {
    ASMVitrineDSPRow *r = row(ASMVitrineDSPRowSlider, title, key);
    r.unit = unit;
    return r;
}

static ASMVitrineDSPRow *choice(NSString *title, NSString *key, NSArray<NSString *> *names) {
    ASMVitrineDSPRow *r = row(ASMVitrineDSPRowChoice, title, key);
    r.names = names;
    return r;
}

static ASMVitrineDSPRow *pageRow(NSString *title, NSString *(^value)(void), UIViewController *(^page)(void)) {
    ASMVitrineDSPRow *r = row(ASMVitrineDSPRowPage, title, nil);
    r.value = value;
    r.page = page;
    return r;
}

static ASMVitrineDSPRow *fileRow(NSString *title, ASMVitrineDSPFileKind kind) {
    return pageRow(title, ^NSString *{ return ASMVitrineDSPChosenFile(kind); }, ^UIViewController *{ return ASMVitrineDSPLibraryPage(kind); });
}

static ASMVitrineDSPEffect *effect(NSString *key, NSString *title, NSString *subtitle, NSArray<ASMVitrineDSPRow *> *rows) {
    ASMVitrineDSPEffect *e = [ASMVitrineDSPEffect new];
    e.key = key;
    e.title = title;
    e.subtitle = subtitle;
    e.rows = rows;
    return e;
}

// The response's points, or Flat when every gain is zero, the way the stored text reads before anything is pasted.
static NSString *graphicEqSummary(void) {
    NSString *text = ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqNodes);
    NSRange colon = [text rangeOfString:@":"];
    if (colon.location != NSNotFound) text = [text substringFromIndex:colon.location + 1];
    NSUInteger points = 0;
    BOOL flat = YES;
    NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *pair in [text componentsSeparatedByString:@";"]) {
        NSArray<NSString *> *parts = [[pair stringByTrimmingCharactersInSet:space] componentsSeparatedByCharactersInSet:space];
        parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
        if (parts.count != 2) continue;
        points++;
        flat &= parts[1].doubleValue == 0;
    }
    return flat ? @"Flat" : [NSString stringWithFormat:@"%lu points", (unsigned long)points];
}

// The effects' cards. The engine runs them in an order of its own (ASMVitrineDSPEngine.m).
static NSArray<ASMVitrineDSPEffect *> *effects(void) {
    // Stored as 0 to 100 around 50, shown as the side's level, 100% leaving it as it is.
    ASMVitrineDSPRow *width = slider(@"Width", ASMVitrineKeyDSPStereoWideLevel, @"%");
    width.scale = 2;
    return @[
        effect(nil, @"Output control", @"Gain and limiter, always on", @[
            slider(@"Post gain", ASMVitrineKeyDSPPostGain, @" dB"),
            slider(@"Limiter threshold", ASMVitrineKeyDSPLimiterThreshold, @" dB"),
            slider(@"Limiter release", ASMVitrineKeyDSPLimiterRelease, @" ms"),
        ]),
        effect(ASMVitrineKeyDSPCompander, @"Multiband compander", @"Evens out or livens up the dynamics", @[
            row(ASMVitrineDSPRowCurve, nil, ASMVitrineKeyDSPCompanderGains),
            slider(@"Release", ASMVitrineKeyDSPCompanderTime, @" s"),
        ]),
        effect(ASMVitrineKeyDSPBass, @"Bass boost", @"Lifts the low end", @[
            slider(@"Maximum gain", ASMVitrineKeyDSPBassGain, @" dB"),
        ]),
        effect(ASMVitrineKeyDSPEqualizer, @"Equalizer", @"15 bands, with presets", @[
            row(ASMVitrineDSPRowCurve, nil, ASMVitrineKeyDSPEqualizerGains),
        ]),
        effect(ASMVitrineKeyDSPGraphicEq, @"Graphic EQ", @"Any curve, like AutoEq's corrections", @[
            pageRow(@"Response", ^NSString *{ return graphicEqSummary(); }, ^UIViewController *{ return ASMVitrineDSPGraphicEqPage(); }),
        ]),
        effect(ASMVitrineKeyDSPConvolver, @"Convolver", @"Recorded rooms and speakers", @[
            fileRow(@"Impulse response", ASMVitrineDSPFileImpulseResponse),
            choice(@"Optimization", ASMVitrineKeyDSPConvolverMode, ASMVitrineDSPConvolverModeNames()),
        ]),
        effect(ASMVitrineKeyDSPDDC, @"ViPER DDC", @"Headphone correction files", @[
            fileRow(@"DDC file", ASMVitrineDSPFileDDC),
        ]),
        effect(ASMVitrineKeyDSPLiveprog, @"Liveprog", @"Effects written as EEL scripts", @[
            fileRow(@"Script", ASMVitrineDSPFileLiveprog),
        ]),
        effect(ASMVitrineKeyDSPReverb, @"Reverb", @"A room around the music", @[
            choice(@"Room", ASMVitrineKeyDSPReverbPreset, ASMVitrineDSPReverbPresetNames()),
            slider(@"Amount", ASMVitrineKeyDSPReverbAmount, @"%"),
        ]),
        effect(ASMVitrineKeyDSPStereoWide, @"Stereo widening", @"A wider or narrower stereo image", @[
            width,
        ]),
        effect(ASMVitrineKeyDSPCrossfeed, @"Crossfeed", @"Softer stereo on headphones", @[
            choice(@"Preset", ASMVitrineKeyDSPCrossfeedMode, ASMVitrineDSPCrossfeedModeNames()),
        ]),
        effect(ASMVitrineKeyDSPTube, @"Analog modeling", @"Tube amplifier warmth", @[
            slider(@"Drive", ASMVitrineKeyDSPTubeDrive, @" dB"),
        ]),
    ];
}

// The effects whose last change can fail, each reporting why under its own switch key.
static NSSet<NSString *> *reportingEffects(void) {
    return [NSSet setWithArray:@[ASMVitrineKeyDSPGraphicEq, ASMVitrineKeyDSPConvolver, ASMVitrineKeyDSPDDC, ASMVitrineKeyDSPLiveprog]];
}

NSString *ASMVitrineDSPSummary(void) {
    if (!ASMVitrineDSPSwitch(ASMVitrineKeyDSP)) return @"Off";
    NSUInteger on = 0;
    for (ASMVitrineDSPEffect *e in effects()) on += e.key && ASMVitrineDSPSwitch(e.key);
    if (!on) return @"On";
    return on == 1 ? @"1 effect" : [NSString stringWithFormat:@"%lu effects", (unsigned long)on];
}

#pragma mark - numbers

// On the step's grid (every range starts on it), without the float noise of getting there.
static double snapped(NSString *key, double value) {
    ASMVitrineDSPRange range = ASMVitrineDSPRangeFor(key);
    if (range.step > 0) value = round(round(value / range.step) * range.step * 1e6) / 1e6;
    return MAX(range.min, MIN(range.max, value));
}

// "−3.5 dB", "+2 dB", "60 ms", "0.22 s", "60%": the step's decimals unless the number is whole, a sign
// where the range runs both ways, and a real minus.
static NSString *numberText(ASMVitrineDSPRow *row, double value) {
    if (row.names.count) {
        NSInteger index = (NSInteger)lround(value);
        return row.names[(NSUInteger)MAX(0, MIN((NSInteger)row.names.count - 1, index))];
    }
    ASMVitrineDSPRange range = ASMVitrineDSPRangeFor(row.key);
    double step = range.step * row.scale;
    value *= row.scale;
    int decimals = step >= 1 ? 0 : step >= 0.1 ? 1 : 2;
    if (fabs(value - round(value)) < 1e-6) decimals = 0;
    NSString *number = [NSString stringWithFormat:@"%.*f", decimals, fabs(value)];
    NSString *sign = number.doubleValue == 0 ? @"" : value < 0 ? @"−" : range.min < 0 && range.max > 0 ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%@%@", sign, number, row.unit ?: @""];
}

// Figures that do not shift sideways as they change, in whatever face the titles are in.
static UIFont *tabular(UIFont *font) {
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{
        UIFontDescriptorFeatureSettingsAttribute: @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                                                     UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}],
    }];
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

#pragma mark - the slider row

// A step at a time for VoiceOver, or a twentieth of the range where the steps are too fine to swipe through.
@interface ASMVitrineDSPSlider : UISlider
@property (nonatomic) float spokenStep;
@end

@implementation ASMVitrineDSPSlider

- (void)accessibilityIncrement {
    self.value += self.spokenStep;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)accessibilityDecrement {
    self.value -= self.spokenStep;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end

// The title and the value over a slider in the accent color, storing each step as the thumb reaches it.
@interface ASMVitrineDSPSliderCell : UITableViewCell
- (void)showRow:(ASMVitrineDSPRow *)row;
@end

@implementation ASMVitrineDSPSliderCell {
    ASMVitrineDSPRow *_row;
    UILabel *_title, *_value;
    ASMVitrineDSPSlider *_slider;
    double _shown;
    BOOL _detents;   // few enough steps that the thumb jumps between them as it is dragged
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:identifier])) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _title = [UILabel new];
    _title.textColor = UIColor.whiteColor;
    _title.isAccessibilityElement = NO;
    _value = [UILabel new];
    _value.textColor = ASMVitrineGrey();
    _value.textAlignment = NSTextAlignmentRight;
    _value.isAccessibilityElement = NO;
    _slider = [ASMVitrineDSPSlider new];
    _slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.16];
    [_slider addTarget:self action:@selector(moved) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(released) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    for (UIView *view in @[_title, _value, _slider]) [self.contentView addSubview:view];
    return self;
}

- (void)showRow:(ASMVitrineDSPRow *)row {
    _row = row;
    ASMVitrineDSPRange range = ASMVitrineDSPRangeFor(row.key);
    NSInteger count = range.step > 0 ? (NSInteger)lround((range.max - range.min) / range.step) : 0;
    _detents = count > 0 && count <= 24;
    _title.font = ASMVitrineTitleFont();
    _value.font = tabular(ASMVitrineTitleFont());
    _title.text = row.title;
    _slider.minimumTrackTintColor = ASMVitrineGreen();
    _slider.minimumValue = (float)range.min;
    _slider.maximumValue = (float)range.max;
    _slider.spokenStep = (float)(count > 0 && count <= 40 ? range.step : snapped(row.key, range.min + (range.max - range.min) / 20) - range.min);
    _shown = ASMVitrineDSPNumber(row.key);
    _slider.value = (float)_shown;
    _slider.accessibilityLabel = row.title;
    [self showValue];
}

- (void)showValue {
    _value.text = numberText(_row, _shown);
    _slider.accessibilityValue = _value.text;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width, side = 16;
    CGFloat y = ASMVitrineLayOutSliderText(_title, _value, nil, side, 12, width - 2 * side);
    _slider.frame = CGRectMake(side, y + 6, width - 2 * side, 28);
}

- (void)moved {
    double value = snapped(_row.key, _slider.value);
    if (_detents) _slider.value = (float)value;
    if (value == _shown) return;
    _shown = value;
    ASMVitrineDSPSetNumber(_row.key, value);
    [self showValue];
}

- (void)released {
    [_slider setValue:(float)_shown animated:YES];
}

@end

#pragma mark - the curve row

@interface ASMVitrineDSPCurveCell : UITableViewCell
@property (nonatomic, strong) ASMVitrineDSPCurveView *curve;
@end

@implementation ASMVitrineDSPCurveCell
- (void)layoutSubviews {
    [super layoutSubviews];
    self.curve.frame = self.contentView.bounds;
}
@end

#pragma mark - a choice's list

// The names a choice picks from, a checkmark against the one set. Unlike Settings' own list it stays
// open after a pick, so one reverb room after another can be heard before going back.
@interface ASMVitrineDSPChoicePage : ASMVitrinePage
- (instancetype)initWithRow:(ASMVitrineDSPRow *)row;
@end

@implementation ASMVitrineDSPChoicePage {
    ASMVitrineDSPRow *_row;
}

- (instancetype)initWithRow:(ASMVitrineDSPRow *)row {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = row.title;
    _row = row;
    return self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_row.names.count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionGap;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"choice");
    ASMVitrineFillCell(cell, _row.names[(NSUInteger)path.row], nil, nil, nil);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    BOOL chosen = path.row == (NSInteger)lround(ASMVitrineDSPNumber(_row.key));
    if (chosen) {
        UIImageView *tick = ASMVitrineSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
        tick.tintColor = ASMVitrineGreen();
        cell.accessoryView = tick;
    }
    cell.accessibilityTraits = chosen ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    ASMVitrineDSPSetNumber(_row.key, path.row);
    [table reloadRowsAtIndexPaths:table.indexPathsForVisibleRows withRowAnimation:UITableViewRowAnimationNone];
}

@end

#pragma mark - the page

@interface ASMVitrineDSPPage : ASMVitrinePage
@end

@implementation ASMVitrineDSPPage {
    NSArray<ASMVitrineDSPEffect *> *_effects;
    NSMutableSet<NSString *> *_open;                          // the effects showing their rows
    NSMutableDictionary<NSString *, NSString *> *_errors;     // the errors showing, by switch key
    UIView *_intro;
    UIView *_credits;
    UITextView *_creditsText;
    NSTimer *_ticker;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Audio effects";
    _effects = effects();
    _open = [NSMutableSet set];
    _errors = [NSMutableDictionary dictionary];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _intro = ASMVitrineNote(@"Changes apply straight away.");
    self.tableView.tableHeaderView = _intro;
    [self buildCredits];
    self.tableView.tableFooterView = _credits;
}

// The libraries two of the effects run on, in the gray of a note with the names as links.
- (void)buildCredits {
    NSDictionary *grey = @{NSFontAttributeName: ASMVitrineSubtitleFont(), NSForegroundColorAttributeName: ASMVitrineGrey()};
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Crossfeed is " attributes:grey];
    NSArray<NSArray<NSString *> *> *parts = @[
        @[@"libbs2b", @"https://github.com/alexmarsev/libbs2b"], @[@" by Boris Mikhaylov. Liveprog runs on ", @""],
        @[@"EEL2", @"https://github.com/justinfrankel/WDL"], @[@", from Cockos' WDL.", @""],
    ];
    for (NSArray<NSString *> *part in parts) {
        NSMutableDictionary *attributes = [grey mutableCopy];
        if (part[1].length) attributes[NSLinkAttributeName] = [NSURL URLWithString:part[1]];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:part[0] attributes:attributes]];
    }
    _creditsText = [UITextView new];
    _creditsText.attributedText = text;
    _creditsText.editable = NO;
    _creditsText.scrollEnabled = NO;
    _creditsText.backgroundColor = UIColor.clearColor;
    _creditsText.textContainerInset = UIEdgeInsetsZero;
    _creditsText.textContainer.lineFragmentPadding = 0;
    _creditsText.linkTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    _credits = [UIView new];
    [_credits addSubview:_creditsText];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _intro, 24, 0);
    // ASMVitrineFitNote's way, for a text view rather than a label.
    UITableView *table = self.tableView;
    CGFloat inset = table.layoutMargins.left, width = table.bounds.size.width - 2 * inset;
    CGFloat height = ceil([_creditsText sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    _creditsText.frame = CGRectMake(inset, 16, width, height);
    CGSize size = CGSizeMake(table.bounds.size.width, 16 + height + 24);
    if (CGSizeEqualToSize(_credits.bounds.size, size)) return;
    _credits.frame = (CGRect){_credits.frame.origin, size};
    table.tableFooterView = _credits;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // A choice, a file or the GraphicEQ text may have changed on the page this one opened.
    [self readState];
    [self.tableView reloadData];
    // A canceled back swipe appears the page again without it ever disappearing, so the old timer goes first.
    [_ticker invalidate];
    _ticker = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_ticker invalidate];
    _ticker = nil;
}

- (void)readState {
    [_open removeAllObjects];
    [_errors removeAllObjects];
    for (ASMVitrineDSPEffect *e in _effects) {
        if (!e.key || ASMVitrineDSPSwitch(e.key)) [_open addObject:e.key ?: @""];
        if (e.key && ASMVitrineDSPSwitch(e.key) && [reportingEffects() containsObject:e.key]) _errors[e.key] = ASMVitrineDSPError(e.key);
    }
}

#pragma mark - rows

// Section 0 is the effects' switch, Presets and Headphones, then a card per effect, then the reset.
- (ASMVitrineDSPEffect *)effectIn:(NSInteger)section {
    return section >= 1 && section <= (NSInteger)_effects.count ? _effects[(NSUInteger)section - 1] : nil;
}

- (BOOL)isOpen:(ASMVitrineDSPEffect *)e {
    return [_open containsObject:e.key ?: @""];
}

- (NSInteger)rowCountOf:(ASMVitrineDSPEffect *)e {
    if (![self isOpen:e]) return 1;
    return 1 + (NSInteger)e.rows.count + (e.key && _errors[e.key] ? 1 : 0);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return (NSInteger)_effects.count + 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    ASMVitrineDSPEffect *e = [self effectIn:section];
    return e ? [self rowCountOf:e] : section == 0 ? 3 : 1;
}

// No views, but asked for all the same: without them the table keeps its own spacing, not the heights below.
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionGap;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (ASMVitrineDSPRow *)rowAt:(NSIndexPath *)path {
    ASMVitrineDSPEffect *e = [self effectIn:path.section];
    if (!e || path.row == 0 || path.row > (NSInteger)e.rows.count) return nil;
    return e.rows[(NSUInteger)path.row - 1];
}

- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    // The heads, the values and the errors size themselves; a nil row would read as a slider.
    ASMVitrineDSPRow *row = [self rowAt:path];
    if (!row) return UITableViewAutomaticDimension;
    // As ASMVitrineDSPSliderCell lays it out: its text at the cell's width, which the table's margins inset, less 16pt sides.
    CGFloat text = table.bounds.size.width - table.layoutMargins.left - table.layoutMargins.right - 32;
    if (row.kind == ASMVitrineDSPRowSlider) return 12 + ASMVitrineSliderTextHeight(row.title, nil, text) + 6 + 28 + 10;
    if (row.kind == ASMVitrineDSPRowCurve) return [ASMVitrineDSPCurveView heightForKey:row.key];
    return UITableViewAutomaticDimension;
}

- (UISwitch *)switchOn:(BOOL)on action:(SEL)action tag:(NSInteger)tag {
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = ASMVitrineGreen();
    toggle.on = on;
    toggle.tag = tag;
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return toggle;
}

// A row with no symbol, so its line fits beside the switch or chevron.
- (void)fillHead:(UITableViewCell *)cell title:(NSString *)title subtitle:(NSString *)subtitle {
    ASMVitrineFillCell(cell, title, subtitle.length ? subtitle : nil, nil, nil);
    cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0 && path.row == 1) return [self valueCell:table title:@"Presets" value:@""];
    if (path.section == 0 && path.row == 2) return [self valueCell:table title:@"Headphones" value:ASMVitrineDSPHeadphoneSummary()];
    if (path.section == 0) {
        UITableViewCell *cell = ASMVitrineDequeueCell(table, @"master");
        [self fillHead:cell title:@"Effects" subtitle:ASMVitrineDSPStatus()];
        cell.accessoryView = [self switchOn:ASMVitrineDSPSwitch(ASMVitrineKeyDSP) action:@selector(masterToggled:) tag:0];
        return cell;
    }
    ASMVitrineDSPEffect *e = [self effectIn:path.section];
    if (!e) {
        UITableViewCell *cell = ASMVitrineDequeueCell(table, @"reset");
        [self fillHead:cell title:@"Reset all effects" subtitle:nil];
        UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
        content.textProperties.color = ASMVitrineRed();
        cell.contentConfiguration = content;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    if (path.row == 0) {
        UITableViewCell *cell = ASMVitrineDequeueCell(table, @"effect");
        [self fillHead:cell title:e.title subtitle:e.subtitle];
        if (e.key) cell.accessoryView = [self switchOn:ASMVitrineDSPSwitch(e.key) action:@selector(effectToggled:) tag:path.section];
        return cell;
    }
    ASMVitrineDSPRow *row = [self rowAt:path];
    if (!row) return [self errorCell:table text:_errors[e.key]];
    switch (row.kind) {
        case ASMVitrineDSPRowSlider: {
            ASMVitrineDSPSliderCell *cell = [table dequeueReusableCellWithIdentifier:@"slider"] ?: [[ASMVitrineDSPSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"slider"];
            cell.backgroundColor = ASMVitrineCardBackground();
            [cell showRow:row];
            return cell;
        }
        case ASMVitrineDSPRowCurve: {
            ASMVitrineDSPCurveCell *cell = [table dequeueReusableCellWithIdentifier:row.key];
            if (!cell) {
                cell = [[ASMVitrineDSPCurveCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:row.key];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.curve = [[ASMVitrineDSPCurveView alloc] initWithKey:row.key];
                [cell.contentView addSubview:cell.curve];
            }
            cell.backgroundColor = ASMVitrineCardBackground();
            [cell.curve reload];
            return cell;
        }
        case ASMVitrineDSPRowChoice: {
            NSInteger index = (NSInteger)lround(ASMVitrineDSPNumber(row.key));
            NSString *name = index >= 0 && index < (NSInteger)row.names.count ? row.names[(NSUInteger)index] : row.names.firstObject;
            return [self valueCell:table title:row.title value:name];
        }
        case ASMVitrineDSPRowPage:
            return [self valueCell:table title:row.title value:row.value()];
    }
    return ASMVitrineDequeueCell(table, @"row");
}

// The value under the title, and a chevron.
- (UITableViewCell *)valueCell:(UITableView *)table title:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"value");
    [self fillHead:cell title:title subtitle:value];
    cell.accessoryView = ASMVitrineChevronView();
    cell.accessibilityValue = value;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

// Red, the way Settings' warning rows are: the effect's last change did not take, and why.
- (UITableViewCell *)errorCell:(UITableView *)table text:(NSString *)text {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"error");
    ASMVitrineFillCell(cell, @"Not applied", text, ASMVitrineRed(), @"exclamationmark.triangle.fill");
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    content.secondaryTextProperties.color = ASMVitrineRed();
    cell.contentConfiguration = content;
    cell.separatorInset = UIEdgeInsetsMake(0, 48, 0, 0);
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == (NSInteger)_effects.count + 1) {
        [self confirmReset];
        return;
    }
    if (path.section == 0 && path.row > 0) {
        [self.navigationController pushViewController:path.row == 1 ? ASMVitrineDSPPresetsPage() : ASMVitrineDSPHeadphonesPage() animated:YES];
        return;
    }
    ASMVitrineDSPRow *row = [self rowAt:path];
    if (!row) return;
    if (row.kind == ASMVitrineDSPRowChoice) [self.navigationController pushViewController:[[ASMVitrineDSPChoicePage alloc] initWithRow:row] animated:YES];
    else if (row.kind == ASMVitrineDSPRowPage) [self.navigationController pushViewController:row.page() animated:YES];
}

- (BOOL)tableView:(UITableView *)table shouldHighlightRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == (NSInteger)_effects.count + 1 || (path.section == 0 && path.row > 0)) return YES;
    ASMVitrineDSPRow *row = [self rowAt:path];
    return row && (row.kind == ASMVitrineDSPRowChoice || row.kind == ASMVitrineDSPRowPage);
}

#pragma mark - changes

- (void)masterToggled:(UISwitch *)toggle {
    ASMVitrineDSPSetSwitch(ASMVitrineKeyDSP, toggle.on);
    [self showStatus];
}

// The effect's rows come in under its switch, or go, rather than the page reloading around them; then the
// card is scrolled into view, as much of it as the screen holds.
- (void)effectToggled:(UISwitch *)toggle {
    NSInteger section = toggle.tag;
    ASMVitrineDSPEffect *e = [self effectIn:section];
    if (!e.key) return;
    ASMVitrineDSPSetSwitch(e.key, toggle.on);
    UITableView *table = self.tableView;
    NSInteger before = [self rowCountOf:e];
    [table performBatchUpdates:^{
        if (toggle.on) [self->_open addObject:e.key];
        else [self->_open removeObject:e.key];
        self->_errors[e.key] = toggle.on && [reportingEffects() containsObject:e.key] ? ASMVitrineDSPError(e.key) : nil;
        NSInteger after = [self rowCountOf:e];
        NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
        for (NSInteger i = 1; i < MAX(before, after); i++) [paths addObject:[NSIndexPath indexPathForRow:i inSection:section]];
        if (after > before) [table insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
        else if (after < before) [table deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
    } completion:^(BOOL finished) {
        if (!toggle.on) return;
        CGRect card = [table rectForSection:section];
        CGFloat room = table.bounds.size.height - table.adjustedContentInset.top - table.adjustedContentInset.bottom;
        card.size.height = MIN(card.size.height, room);
        [table scrollRectToVisible:card animated:YES];
    }];
}

// Once a second while the page shows: what the engine is doing, and whether an effect's change failed.
- (void)tick {
    [self showStatus];
    UITableView *table = self.tableView;
    [_effects enumerateObjectsUsingBlock:^(ASMVitrineDSPEffect *e, NSUInteger i, BOOL *stop) {
        if (![reportingEffects() containsObject:e.key] || ![self isOpen:e]) return;
        NSString *shown = self->_errors[e.key], *now = ASMVitrineDSPError(e.key);
        if (shown == now || [shown isEqualToString:now]) return;
        NSIndexPath *path = [NSIndexPath indexPathForRow:1 + (NSInteger)e.rows.count inSection:(NSInteger)i + 1];
        [table performBatchUpdates:^{
            self->_errors[e.key] = now;
            if (shown && now) [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationFade];
            else if (now) [table insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationFade];
            else [table deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationFade];
        } completion:nil];
    }];
}

// Written into the cell rather than reloaded, so the switch beside it is never swapped under a finger.
// The status wraps, so the row's height is measured again without reloading it.
- (void)showStatus {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    NSString *status = ASMVitrineDSPStatus();
    if (!content || [content.secondaryText isEqualToString:status]) return;
    content.secondaryText = status;
    cell.contentConfiguration = content;
    [UIView performWithoutAnimation:^{ [self.tableView performBatchUpdates:nil completion:nil]; }];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all effects?"
        message:@"Every effect goes off, and every value, curve and file choice back to its default. The Effects switch and your imported files stay."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMVitrineDSPResetAll();
        [self readState];
        [UIView transitionWithView:self.tableView duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.tableView reloadData];
        } completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMVitrineDSPSettingsPage(void) {
    return [ASMVitrineDSPPage new];
}
