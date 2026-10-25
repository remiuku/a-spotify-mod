// The Audio effects page. It is not an ASMSpotiModPage: its sliders store as they move, its cards open out
// into their controls as their switches go on, and its status line and the effects' errors come and go
// while it is open, none of which a page of fixed rows does. It keeps Settings/'s look all the same: the
// cards, the 13pt titles over 11pt subtitles, the tiles, the value and the chevron, the checkmark lists.
#import <CoreText/SFNTLayoutTypes.h>
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "JamesDSPPage.h"
#import "ASMSpotiDSPCurveView.h"

typedef NS_ENUM(NSInteger, ASMSpotiDSPRowKind) {
    ASMSpotiDSPRowSlider,   // a number, stored as the slider moves
    ASMSpotiDSPRowChoice,   // one of a list of names, stored as its index
    ASMSpotiDSPRowPage,     // a page of its own, its value beside the chevron
    ASMSpotiDSPRowCurve,    // the equalizer's or the compressor's gains
};

@interface ASMSpotiDSPRow : NSObject
@property (nonatomic) ASMSpotiDSPRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *unit;
@property (nonatomic, copy) NSArray<NSString *> *names;   // a choice's, or what a slider's steps read as
@property (nonatomic, copy) NSString *(^value)(void);
@property (nonatomic, copy) UIViewController *(^page)(void);
@end

@implementation ASMSpotiDSPRow
@end

// An effect's card: the switch at its head and the rows it opens out into while the switch is on.
@interface ASMSpotiDSPEffect : NSObject
@property (nonatomic, copy) NSString *key;   // the switch; nil for output control, which is always on
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSArray<ASMSpotiDSPRow *> *rows;
@end

@implementation ASMSpotiDSPEffect
@end

#pragma mark - the effects

static ASMSpotiDSPRow *row(ASMSpotiDSPRowKind kind, NSString *title, NSString *key) {
    ASMSpotiDSPRow *row = [ASMSpotiDSPRow new];
    row.kind = kind;
    row.title = title;
    row.key = key;
    return row;
}

static ASMSpotiDSPRow *slider(NSString *title, NSString *key, NSString *unit) {
    ASMSpotiDSPRow *r = row(ASMSpotiDSPRowSlider, title, key);
    r.unit = unit;
    return r;
}

static ASMSpotiDSPRow *steps(NSString *title, NSString *key, NSArray<NSString *> *names) {
    ASMSpotiDSPRow *r = row(ASMSpotiDSPRowSlider, title, key);
    r.names = names;
    return r;
}

static ASMSpotiDSPRow *choice(NSString *title, NSString *key, NSArray<NSString *> *names) {
    ASMSpotiDSPRow *r = row(ASMSpotiDSPRowChoice, title, key);
    r.names = names;
    return r;
}

static ASMSpotiDSPRow *pageRow(NSString *title, NSString *(^value)(void), UIViewController *(^page)(void)) {
    ASMSpotiDSPRow *r = row(ASMSpotiDSPRowPage, title, nil);
    r.value = value;
    r.page = page;
    return r;
}

static ASMSpotiDSPRow *fileRow(NSString *title, ASMSpotiDSPFileKind kind) {
    return pageRow(title, ^NSString *{ return ASMSpotiDSPChosenFile(kind); }, ^UIViewController *{ return ASMSpotiDSPLibraryPage(kind); });
}

static ASMSpotiDSPEffect *effect(NSString *key, NSString *title, NSString *subtitle, NSString *symbol, NSArray<ASMSpotiDSPRow *> *rows) {
    ASMSpotiDSPEffect *e = [ASMSpotiDSPEffect new];
    e.key = key;
    e.title = title;
    e.subtitle = subtitle;
    e.symbol = symbol;
    e.rows = rows;
    return e;
}

// The response's points, or Flat when every gain is zero, the way the stored text reads before anything is pasted.
static NSString *graphicEqSummary(void) {
    NSString *text = ASMSpotiDSPString(ASMSpotiKeyDSPGraphicEqNodes);
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

// RootlessJamesDSP's cards, in its order.
static NSArray<ASMSpotiDSPEffect *> *effects(void) {
    return @[
        effect(nil, @"Output control", @"Gain and limiter, always on", @"speaker.wave.2", @[
            slider(@"Post gain", ASMSpotiKeyDSPPostGain, @" dB"),
            slider(@"Limiter threshold", ASMSpotiKeyDSPLimiterThreshold, @" dB"),
            slider(@"Limiter release", ASMSpotiKeyDSPLimiterRelease, @" ms"),
        ]),
        effect(ASMSpotiKeyDSPCompander, @"Dynamic range compressor", @"Evens out loud and quiet parts", @"rectangle.compress.vertical", @[
            row(ASMSpotiDSPRowCurve, nil, ASMSpotiKeyDSPCompanderGains),
            slider(@"Time constant", ASMSpotiKeyDSPCompanderTime, @" s"),
            steps(@"Granularity", ASMSpotiKeyDSPCompanderGranularity, @[@"Very low", @"Low", @"Medium", @"High", @"Extreme"]),
            choice(@"Transform", ASMSpotiKeyDSPCompanderTransform, ASMSpotiDSPCompanderTransformNames()),
        ]),
        effect(ASMSpotiKeyDSPBass, @"Bass boost", @"Lifts the low end", @"hifispeaker", @[
            slider(@"Maximum gain", ASMSpotiKeyDSPBassGain, @" dB"),
        ]),
        effect(ASMSpotiKeyDSPEqualizer, @"Equalizer", @"15 bands, with JamesDSP's presets", @"slider.vertical.3", @[
            row(ASMSpotiDSPRowCurve, nil, ASMSpotiKeyDSPEqualizerGains),
            choice(@"Filter", ASMSpotiKeyDSPEqualizerFilter, ASMSpotiDSPEqualizerFilterNames()),
            choice(@"Interpolation", ASMSpotiKeyDSPEqualizerInterpolation, ASMSpotiDSPEqualizerInterpolationNames()),
        ]),
        effect(ASMSpotiKeyDSPGraphicEq, @"Graphic EQ", @"Any curve, like AutoEq's corrections", @"chart.xyaxis.line", @[
            pageRow(@"Response", ^NSString *{ return graphicEqSummary(); }, ^UIViewController *{ return ASMSpotiDSPGraphicEqPage(); }),
        ]),
        effect(ASMSpotiKeyDSPConvolver, @"Convolver", @"Recorded rooms and speakers", @"waveform.path", @[
            fileRow(@"Impulse response", ASMSpotiDSPFileImpulseResponse),
            choice(@"Optimization", ASMSpotiKeyDSPConvolverMode, ASMSpotiDSPConvolverModeNames()),
        ]),
        effect(ASMSpotiKeyDSPDDC, @"ViPER DDC", @"Headphone correction presets", @"headphones", @[
            fileRow(@"DDC file", ASMSpotiDSPFileDDC),
        ]),
        effect(ASMSpotiKeyDSPLiveprog, @"Liveprog", @"Effects written as EEL scripts", @"chevron.left.forwardslash.chevron.right", @[
            fileRow(@"Script", ASMSpotiDSPFileLiveprog),
        ]),
        effect(ASMSpotiKeyDSPReverb, @"Reverb", @"A room around the music", @"building.columns", @[
            choice(@"Room", ASMSpotiKeyDSPReverbPreset, ASMSpotiDSPReverbPresetNames()),
        ]),
        effect(ASMSpotiKeyDSPStereoWide, @"Stereo widening", @"A wider or narrower stereo image", @"arrow.left.and.right", @[
            slider(@"Width", ASMSpotiKeyDSPStereoWideLevel, @"%"),
        ]),
        effect(ASMSpotiKeyDSPCrossfeed, @"Crossfeed", @"Softer stereo on headphones", @"ear", @[
            choice(@"Preset", ASMSpotiKeyDSPCrossfeedMode, ASMSpotiDSPCrossfeedModeNames()),
        ]),
        effect(ASMSpotiKeyDSPTube, @"Analog modelling", @"Tube amplifier warmth", @"flame", @[
            slider(@"Drive", ASMSpotiKeyDSPTubeDrive, @" dB"),
        ]),
    ];
}

// The effects whose last change can fail, each reporting why under its own switch key.
static NSSet<NSString *> *reportingEffects(void) {
    return [NSSet setWithArray:@[ASMSpotiKeyDSPGraphicEq, ASMSpotiKeyDSPConvolver, ASMSpotiKeyDSPDDC, ASMSpotiKeyDSPLiveprog]];
}

NSString *ASMSpotiDSPSummary(void) {
    if (!ASMSpotiDSPSwitch(ASMSpotiKeyDSP)) return @"Off";
    NSUInteger on = 0;
    for (ASMSpotiDSPEffect *e in effects()) on += e.key && ASMSpotiDSPSwitch(e.key);
    if (!on) return @"On";
    return on == 1 ? @"1 effect" : [NSString stringWithFormat:@"%lu effects", (unsigned long)on];
}

#pragma mark - numbers

// On the step's grid (every range starts on it), without the float noise of getting there.
static double snapped(NSString *key, double value) {
    ASMSpotiDSPRange range = ASMSpotiDSPRangeFor(key);
    if (range.step > 0) value = round(round(value / range.step) * range.step * 1e6) / 1e6;
    return MAX(range.min, MIN(range.max, value));
}

// "−3.5 dB", "+2 dB", "60 ms", "0.22 s", "60%": the step's decimals unless the number is whole, a sign
// where the range runs both ways, and a real minus.
static NSString *numberText(ASMSpotiDSPRow *row, double value) {
    if (row.names.count) {
        NSInteger index = (NSInteger)lround(value);
        return row.names[(NSUInteger)MAX(0, MIN((NSInteger)row.names.count - 1, index))];
    }
    ASMSpotiDSPRange range = ASMSpotiDSPRangeFor(row.key);
    int decimals = range.step >= 1 ? 0 : range.step >= 0.1 ? 1 : 2;
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
@interface ASMSpotiDSPSlider : UISlider
@property (nonatomic) float spokenStep;
@end

@implementation ASMSpotiDSPSlider

- (void)accessibilityIncrement {
    self.value += self.spokenStep;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)accessibilityDecrement {
    self.value -= self.spokenStep;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end

// The title and the value over a slider in the accent colour, storing each step as the thumb reaches it.
@interface ASMSpotiDSPSliderCell : UITableViewCell
- (void)showRow:(ASMSpotiDSPRow *)row;
@end

@implementation ASMSpotiDSPSliderCell {
    ASMSpotiDSPRow *_row;
    UILabel *_title, *_value;
    ASMSpotiDSPSlider *_slider;
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
    _value.textColor = ASMSpotiGrey();
    _value.textAlignment = NSTextAlignmentRight;
    _value.isAccessibilityElement = NO;
    _slider = [ASMSpotiDSPSlider new];
    _slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.16];
    [_slider addTarget:self action:@selector(moved) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(released) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    for (UIView *view in @[_title, _value, _slider]) [self.contentView addSubview:view];
    return self;
}

- (void)showRow:(ASMSpotiDSPRow *)row {
    _row = row;
    ASMSpotiDSPRange range = ASMSpotiDSPRangeFor(row.key);
    NSInteger count = range.step > 0 ? (NSInteger)lround((range.max - range.min) / range.step) : 0;
    _detents = count > 0 && count <= 24;
    _title.font = ASMSpotiTitleFont();
    _value.font = tabular(ASMSpotiTitleFont());
    _title.text = row.title;
    _slider.minimumTrackTintColor = ASMSpotiGreen();
    _slider.minimumValue = (float)range.min;
    _slider.maximumValue = (float)range.max;
    _slider.spokenStep = (float)(count > 0 && count <= 40 ? range.step : snapped(row.key, range.min + (range.max - range.min) / 20) - range.min);
    _shown = ASMSpotiDSPNumber(row.key);
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
    [_value sizeToFit];
    CGFloat valueWidth = MAX(_value.bounds.size.width, 44);
    _value.frame = CGRectMake(width - side - valueWidth, 12, valueWidth, 18);
    _title.frame = CGRectMake(side, 12, CGRectGetMinX(_value.frame) - side - 8, 18);
    _slider.frame = CGRectMake(side, 36, width - 2 * side, 28);
}

- (void)moved {
    double value = snapped(_row.key, _slider.value);
    if (_detents) _slider.value = (float)value;
    if (value == _shown) return;
    _shown = value;
    ASMSpotiDSPSetNumber(_row.key, value);
    [self showValue];
}

- (void)released {
    [_slider setValue:(float)_shown animated:YES];
}

@end

#pragma mark - the curve row

@interface ASMSpotiDSPCurveCell : UITableViewCell
@property (nonatomic, strong) ASMSpotiDSPCurveView *curve;
@end

@implementation ASMSpotiDSPCurveCell
- (void)layoutSubviews {
    [super layoutSubviews];
    self.curve.frame = self.contentView.bounds;
}
@end

#pragma mark - a choice's list

// The names a choice picks from, a checkmark against the one set. Unlike Settings' own list it stays
// open after a pick, so one reverb room after another can be heard before going back.
@interface ASMSpotiDSPChoicePage : ASMSpotiPage
- (instancetype)initWithRow:(ASMSpotiDSPRow *)row;
@end

@implementation ASMSpotiDSPChoicePage {
    ASMSpotiDSPRow *_row;
}

- (instancetype)initWithRow:(ASMSpotiDSPRow *)row {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = row.title;
    _row = row;
    return self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMSpotiInsetForBars(self.tableView);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_row.names.count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMSpotiSectionGap;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"choice");
    ASMSpotiFillCell(cell, _row.names[(NSUInteger)path.row], nil, nil, nil);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    BOOL chosen = path.row == (NSInteger)lround(ASMSpotiDSPNumber(_row.key));
    if (chosen) {
        UIImageView *tick = ASMSpotiSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
        tick.tintColor = ASMSpotiGreen();
        cell.accessoryView = tick;
    }
    cell.accessibilityTraits = chosen ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    ASMSpotiDSPSetNumber(_row.key, path.row);
    [table reloadRowsAtIndexPaths:table.indexPathsForVisibleRows withRowAnimation:UITableViewRowAnimationNone];
}

@end

#pragma mark - the page

// The value and the chevron of a row opening a page, as Settings' own rows draw them.
static UIView *valueAndChevron(NSString *text) {
    UILabel *label = [UILabel new];
    label.font = ASMSpotiTitleFont();
    label.textColor = ASMSpotiGrey();
    label.text = text;
    [label sizeToFit];
    UIImageView *chevron = ASMSpotiSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
    CGFloat height = MAX(label.bounds.size.height, chevron.bounds.size.height);
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, label.bounds.size.width + 6 + chevron.bounds.size.width, height)];
    label.center = CGPointMake(label.bounds.size.width / 2, height / 2);
    chevron.center = CGPointMake(box.bounds.size.width - chevron.bounds.size.width / 2, height / 2);
    [box addSubview:label];
    [box addSubview:chevron];
    return box;
}

@interface ASMSpotiDSPPage : ASMSpotiPage
@end

@implementation ASMSpotiDSPPage {
    NSArray<ASMSpotiDSPEffect *> *_effects;
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
    _intro = ASMSpotiNote(@"Changes apply straight away.");
    self.tableView.tableHeaderView = _intro;
    [self buildCredits];
    self.tableView.tableFooterView = _credits;
}

// JamesDSP's author and where its two apps live, in the grey of a note with the names as links.
- (void)buildCredits {
    NSDictionary *grey = @{NSFontAttributeName: ASMSpotiSubtitleFont(), NSForegroundColorAttributeName: ASMSpotiGrey()};
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"JamesDSP by James Fung (james34602). Its engine, libjamesdsp, is free software under the GPL.\n" attributes:grey];
    NSArray<NSArray<NSString *> *> *links = @[
        @[@"JamesDSPManager", @"https://github.com/james34602/JamesDSPManager"],
        @[@"RootlessJamesDSP", @"https://github.com/timschneeb/RootlessJamesDSP"],
    ];
    [links enumerateObjectsUsingBlock:^(NSArray<NSString *> *link, NSUInteger i, BOOL *stop) {
        if (i) [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"  ·  " attributes:grey]];
        NSMutableDictionary *linked = [grey mutableCopy];
        linked[NSLinkAttributeName] = [NSURL URLWithString:link[1]];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:link[0] attributes:linked]];
    }];
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
    ASMSpotiFitNote(self.tableView, _intro, 24, 0);
    // ASMSpotiFitNote's way, for a text view rather than a label.
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
    ASMSpotiInsetForBars(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // A choice, a file or the GraphicEQ text may have changed on the page this one opened.
    [self readState];
    [self.tableView reloadData];
    // A cancelled back swipe appears the page again without it ever disappearing, so the old timer goes first.
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
    for (ASMSpotiDSPEffect *e in _effects) {
        if (!e.key || ASMSpotiDSPSwitch(e.key)) [_open addObject:e.key ?: @""];
        if (e.key && ASMSpotiDSPSwitch(e.key) && [reportingEffects() containsObject:e.key]) _errors[e.key] = ASMSpotiDSPError(e.key);
    }
}

#pragma mark - rows

// Section 0 is JamesDSP's switch, then a card per effect, then the reset.
- (ASMSpotiDSPEffect *)effectIn:(NSInteger)section {
    return section >= 1 && section <= (NSInteger)_effects.count ? _effects[(NSUInteger)section - 1] : nil;
}

- (BOOL)isOpen:(ASMSpotiDSPEffect *)e {
    return [_open containsObject:e.key ?: @""];
}

- (NSInteger)rowCountOf:(ASMSpotiDSPEffect *)e {
    if (![self isOpen:e]) return 1;
    return 1 + (NSInteger)e.rows.count + (e.key && _errors[e.key] ? 1 : 0);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return (NSInteger)_effects.count + 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    ASMSpotiDSPEffect *e = [self effectIn:section];
    return e ? [self rowCountOf:e] : 1;
}

// No views, but asked for all the same: without them the table keeps its own spacing, not the heights below.
- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMSpotiSectionGap;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (ASMSpotiDSPRow *)rowAt:(NSIndexPath *)path {
    ASMSpotiDSPEffect *e = [self effectIn:path.section];
    if (!e || path.row == 0 || path.row > (NSInteger)e.rows.count) return nil;
    return e.rows[(NSUInteger)path.row - 1];
}

- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    // The heads, the values and the errors size themselves; a nil row would read as a slider.
    ASMSpotiDSPRow *row = [self rowAt:path];
    if (!row) return UITableViewAutomaticDimension;
    if (row.kind == ASMSpotiDSPRowSlider) return 74;
    if (row.kind == ASMSpotiDSPRowCurve) return [ASMSpotiDSPCurveView heightForKey:row.key];
    return UITableViewAutomaticDimension;
}

- (UISwitch *)switchOn:(BOOL)on action:(SEL)action tag:(NSInteger)tag {
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = ASMSpotiGreen();
    toggle.on = on;
    toggle.tag = tag;
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return toggle;
}

- (void)fillHead:(UITableViewCell *)cell title:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol {
    ASMSpotiFillCell(cell, title, subtitle, nil, nil);
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    content.image = ASMSpotiTileImage(symbol);
    content.imageToTextPadding = 14;
    content.secondaryTextProperties.numberOfLines = 1;
    cell.contentConfiguration = content;
    cell.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 0) {
        UITableViewCell *cell = ASMSpotiDequeueCell(table, @"master");
        [self fillHead:cell title:@"JamesDSP" subtitle:ASMSpotiDSPStatus() symbol:@"waveform"];
        cell.accessoryView = [self switchOn:ASMSpotiDSPSwitch(ASMSpotiKeyDSP) action:@selector(masterToggled:) tag:0];
        return cell;
    }
    ASMSpotiDSPEffect *e = [self effectIn:path.section];
    if (!e) {
        UITableViewCell *cell = ASMSpotiDequeueCell(table, @"reset");
        ASMSpotiFillCell(cell, @"Reset all effects", nil, ASMSpotiRed(), @"arrow.counterclockwise");
        UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
        content.secondaryTextProperties.color = ASMSpotiRed();
        cell.contentConfiguration = content;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.separatorInset = UIEdgeInsetsMake(0, 48, 0, 0);
        return cell;
    }
    if (path.row == 0) {
        UITableViewCell *cell = ASMSpotiDequeueCell(table, @"effect");
        [self fillHead:cell title:e.title subtitle:e.subtitle symbol:e.symbol];
        if (e.key) cell.accessoryView = [self switchOn:ASMSpotiDSPSwitch(e.key) action:@selector(effectToggled:) tag:path.section];
        return cell;
    }
    ASMSpotiDSPRow *row = [self rowAt:path];
    if (!row) return [self errorCell:table text:_errors[e.key]];
    switch (row.kind) {
        case ASMSpotiDSPRowSlider: {
            ASMSpotiDSPSliderCell *cell = [table dequeueReusableCellWithIdentifier:@"slider"] ?: [[ASMSpotiDSPSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"slider"];
            cell.backgroundColor = ASMSpotiCardBackground();
            [cell showRow:row];
            return cell;
        }
        case ASMSpotiDSPRowCurve: {
            ASMSpotiDSPCurveCell *cell = [table dequeueReusableCellWithIdentifier:row.key];
            if (!cell) {
                cell = [[ASMSpotiDSPCurveCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:row.key];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.curve = [[ASMSpotiDSPCurveView alloc] initWithKey:row.key];
                [cell.contentView addSubview:cell.curve];
            }
            cell.backgroundColor = ASMSpotiCardBackground();
            [cell.curve reload];
            return cell;
        }
        case ASMSpotiDSPRowChoice: {
            NSInteger index = (NSInteger)lround(ASMSpotiDSPNumber(row.key));
            NSString *name = index >= 0 && index < (NSInteger)row.names.count ? row.names[(NSUInteger)index] : row.names.firstObject;
            return [self valueCell:table title:row.title value:name];
        }
        case ASMSpotiDSPRowPage:
            return [self valueCell:table title:row.title value:row.value()];
    }
    return ASMSpotiDequeueCell(table, @"row");
}

// The value on the right beside the chevron where it fits next to the title, and under the title
// where it does not: the compressor's transforms are longer than a narrow phone has room for.
- (UITableViewCell *)valueCell:(UITableView *)table title:(NSString *)title value:(NSString *)value {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"value");
    CGFloat card = table.bounds.size.width - table.layoutMargins.left - table.layoutMargins.right;
    UIView *accessory = valueAndChevron(value);
    CGFloat titleWidth = ceil([title sizeWithAttributes:@{NSFontAttributeName: ASMSpotiTitleFont()}].width);
    BOOL fits = 16 + titleWidth + 16 + accessory.bounds.size.width + 16 <= card;
    ASMSpotiFillCell(cell, title, fits ? nil : value, nil, nil);
    cell.accessoryView = fits ? accessory : ASMSpotiSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
    cell.accessibilityValue = value;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    return cell;
}

// Red, the way Settings' warning rows are: the effect's last change did not take, and why.
- (UITableViewCell *)errorCell:(UITableView *)table text:(NSString *)text {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"error");
    ASMSpotiFillCell(cell, @"Not applied", text, ASMSpotiRed(), @"exclamationmark.triangle.fill");
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    content.secondaryTextProperties.color = ASMSpotiRed();
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
    ASMSpotiDSPRow *row = [self rowAt:path];
    if (!row) return;
    if (row.kind == ASMSpotiDSPRowChoice) [self.navigationController pushViewController:[[ASMSpotiDSPChoicePage alloc] initWithRow:row] animated:YES];
    else if (row.kind == ASMSpotiDSPRowPage) [self.navigationController pushViewController:row.page() animated:YES];
}

- (BOOL)tableView:(UITableView *)table shouldHighlightRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == (NSInteger)_effects.count + 1) return YES;
    ASMSpotiDSPRow *row = [self rowAt:path];
    return row && (row.kind == ASMSpotiDSPRowChoice || row.kind == ASMSpotiDSPRowPage);
}

#pragma mark - changes

- (void)masterToggled:(UISwitch *)toggle {
    ASMSpotiDSPSetSwitch(ASMSpotiKeyDSP, toggle.on);
    [self showStatus];
}

// The effect's rows come in under its switch, or go, rather than the page reloading around them; then the
// card is scrolled into view, as much of it as the screen holds.
- (void)effectToggled:(UISwitch *)toggle {
    NSInteger section = toggle.tag;
    ASMSpotiDSPEffect *e = [self effectIn:section];
    if (!e.key) return;
    ASMSpotiDSPSetSwitch(e.key, toggle.on);
    UITableView *table = self.tableView;
    NSInteger before = [self rowCountOf:e];
    [table performBatchUpdates:^{
        if (toggle.on) [self->_open addObject:e.key];
        else [self->_open removeObject:e.key];
        self->_errors[e.key] = toggle.on && [reportingEffects() containsObject:e.key] ? ASMSpotiDSPError(e.key) : nil;
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
    [_effects enumerateObjectsUsingBlock:^(ASMSpotiDSPEffect *e, NSUInteger i, BOOL *stop) {
        if (![reportingEffects() containsObject:e.key] || ![self isOpen:e]) return;
        NSString *shown = self->_errors[e.key], *now = ASMSpotiDSPError(e.key);
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
- (void)showStatus {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    NSString *status = ASMSpotiDSPStatus();
    if (!content || [content.secondaryText isEqualToString:status]) return;
    content.secondaryText = status;
    cell.contentConfiguration = content;
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset all effects?"
        message:@"Every effect goes off, and every value, curve and file choice back to its default. JamesDSP's own switch and your imported files stay."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMSpotiDSPResetAll();
        [self readState];
        [UIView transitionWithView:self.tableView duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.tableView reloadData];
        } completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMSpotiDSPSettingsPage(void) {
    return [ASMSpotiDSPPage new];
}
