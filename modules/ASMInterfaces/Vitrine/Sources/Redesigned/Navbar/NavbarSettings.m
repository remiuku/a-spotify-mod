#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Navbar.h"
#import "Shared/Navigation/AddTabSheet.h"
#import "Redesigned/Kit/ASMVitrineRTokens.h"

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph. Playlists was spotify:collection:playlists
// until 0.20, which 9.1.78 knows only from its old iPad sidebar table and has no handler for (#66);
// spotify:playlists is the form its collection URI parser lists, next to spotify:playlists:by-you.
// The picker still asks the dispatcher about each one and leaves out what it has nowhere to send.
static NSArray<NSDictionary *> *tabPresets(void) {
    return @[
        @{ASMVitrineTabTitle: @"Home", ASMVitrineTabURI: @"spotify:home", ASMVitrineTabIcon: @"home"},
        @{ASMVitrineTabTitle: @"Search", ASMVitrineTabURI: @"spotify:search", ASMVitrineTabIcon: @"search"},
        @{ASMVitrineTabTitle: @"Your Library", ASMVitrineTabURI: @"spotify:collection", ASMVitrineTabIcon: @"collection"},
        @{ASMVitrineTabTitle: @"Liked Songs", ASMVitrineTabURI: @"spotify:collection:tracks", ASMVitrineTabIcon: @"heart"},
        @{ASMVitrineTabTitle: @"Playlists", ASMVitrineTabURI: @"spotify:playlists", ASMVitrineTabIcon: @"playlist"},
        @{ASMVitrineTabTitle: @"Albums", ASMVitrineTabURI: @"spotify:collection:albums", ASMVitrineTabIcon: @"album"},
        @{ASMVitrineTabTitle: @"Artists", ASMVitrineTabURI: @"spotify:collection:artists", ASMVitrineTabIcon: @"artist"},
        @{ASMVitrineTabTitle: @"Podcasts", ASMVitrineTabURI: @"spotify:collection:podcasts", ASMVitrineTabIcon: @"podcasts"},
        @{ASMVitrineTabTitle: @"Audiobooks", ASMVitrineTabURI: @"spotify:collection:audiobooks", ASMVitrineTabIcon: @"audiobook"},
        @{ASMVitrineTabTitle: @"Downloads", ASMVitrineTabURI: @"spotify:collection:downloads", ASMVitrineTabIcon: @"downloaded"},
        @{ASMVitrineTabTitle: @"Your Episodes", ASMVitrineTabURI: @"spotify:collection:your-episodes", ASMVitrineTabIcon: @"bookmark"},
        @{ASMVitrineTabTitle: @"Browse", ASMVitrineTabURI: @"spotify:browse", ASMVitrineTabIcon: @"browse"},
        @{ASMVitrineTabTitle: @"New Releases", ASMVitrineTabURI: @"spotify:new-releases", ASMVitrineTabIcon: @"star"},
        @{ASMVitrineTabTitle: @"Made For You", ASMVitrineTabURI: @"spotify:made-for-you", ASMVitrineTabIcon: @"user"},
        @{ASMVitrineTabTitle: @"Concerts", ASMVitrineTabURI: @"spotify:concerts", ASMVitrineTabIcon: @"events"},
        @{ASMVitrineTabTitle: @"Queue", ASMVitrineTabURI: @"spotify:now-playing:queue", ASMVitrineTabIcon: @"queue"},
        @{ASMVitrineTabTitle: @"Create", ASMVitrineTabURI: @"spotify:create-menu", ASMVitrineTabIcon: @"plus"},
    ];
}

// The list the Navbar page edits: the saved order first, then every tab of Spotify's it does not
// name, in Spotify's order. Entries for tabs Spotify no longer has drop out.
static NSMutableArray<NSMutableDictionary *> *navbarEntries(void) {
    NSArray<NSString *> *stock = ASMVitrineRNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in ASMVitrineRNavbarLayout()) {
        NSString *ident = entry[ASMVitrineRNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[ASMVitrineRNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{ASMVitrineRNavbarID: ident, ASMVitrineRNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [@{ASMVitrineRNavbarID: NSUUID.UUID.UUIDString, ASMVitrineRNavbarTitle: tab[ASMVitrineTabTitle],
                                    ASMVitrineRNavbarURI: tab[ASMVitrineTabURI], ASMVitrineRNavbarIcon: tab[ASMVitrineTabIcon]} mutableCopy];
    entry[ASMVitrineRNavbarIconSet] = tab[ASMVitrineTabIconSet];
    ASMVitrineRSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    ASMVitrineRRefreshTabBar();
}

// Split tabs: a switch per tab of the bar, on to set it apart at the trailing end.
@interface ASMVitrineRSplitTabsPage : ASMVitrinePage
@end

@implementation ASMVitrineRSplitTabsPage {
    NSArray<NSDictionary *> *_entries;
    NSMutableSet<NSString *> *_split;
    UIView *_intro;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Split Tabs";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _intro = ASMVitrineNote(@"Tabs switched on here sit apart from the others at the right end of the bar, the way the Music "
                    "app sets Search apart. Hidden tabs stay hidden.");
    self.tableView.tableHeaderView = _intro;
    _entries = navbarEntries();
    _split = [NSMutableSet setWithArray:ASMVitrineRNavbarSplit()];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _intro, 24, 0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_entries.count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeader(table, @"Tabs");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeaderHeight();
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"split");
    NSDictionary *entry = _entries[(NSUInteger)path.row];
    BOOL apart = [_split containsObject:entry[ASMVitrineRNavbarID]];
    NSString *where = [entry[ASMVitrineRNavbarHidden] boolValue] ? @"Hidden" : apart ? @"Apart, on the right" : @"With the others";
    ASMVitrineFillCell(cell, entry[ASMVitrineRNavbarTitle], where, nil, nil);
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = ASMVitrineGreen();
    toggle.on = apart;
    toggle.tag = path.row;
    [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)toggled:(UISwitch *)toggle {
    NSString *ident = _entries[(NSUInteger)toggle.tag][ASMVitrineRNavbarID];
    if (toggle.on) [_split addObject:ident];
    else [_split removeObject:ident];
    ASMVitrineRSetNavbarSplit(_split.allObjects);
    ASMVitrineRRefreshTabBar();
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:toggle.tag inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

@end

#pragma mark - the preview

// Spotify's own tabs in Spotify's order, as entries, all shown: what the bar has with Custom tab bar off.
static NSArray<NSDictionary *> *stockEntries(void) {
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
    for (NSString *ident in ASMVitrineRNavbarStock()) [entries addObject:@{ASMVitrineRNavbarID: ident, ASMVitrineRNavbarTitle: ident}];
    return entries;
}

static UIImage *glyphFor(NSDictionary *entry, BOOL active) {
    return ASMVitrineRNavbarGlyph(entry, active) ?: [UIImage systemImageNamed:@"square.dashed"];
}

static UITabBar *previewBar(void) {
    UITabBar *bar = [UITabBar new];
    // Dark whatever the system is, as TabBar.x's bars are.
    bar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    bar.userInteractionEnabled = NO;
    bar.tintColor = ASMVitrineRAccent();
    return bar;
}

// TabBar.x's split bar: UIKit draws a bar's platter 21 pt in from its sides, a split tab takes a 62 pt circle,
// and the main bar runs under the split bar's leading inset to leave 12 pt between the two platters.
static const CGFloat kPlatterInset = 21, kApartItemWidth = 62, kPlatterGap = 12;

// The glass bar as it will look, drawn by the same system UITabBar TabBar.x puts over Spotify's bar, from the
// list as it stands on the page: the shown tabs in order, the first selected, the split tabs on a bar of
// their own, names under the glyphs unless Icons only is picked. It takes no touches.
@interface ASMVitrineRTabBarPreview : UIView
- (void)showEntries:(NSArray<NSDictionary *> *)entries;
@end

@implementation ASMVitrineRTabBarPreview {
    UITabBar *_main, *_apart;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _main = previewBar();
    _apart = previewBar();
    [self addSubview:_main];
    [self addSubview:_apart];
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"Tab bar preview";
    return self;
}

static NSArray<UITabBarItem *> *itemsFor(NSArray<NSDictionary *> *entries, BOOL names) {
    NSMutableArray<UITabBarItem *> *items = [NSMutableArray array];
    for (NSDictionary *entry in entries) {
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:names ? entry[ASMVitrineRNavbarTitle] : nil image:glyphFor(entry, NO) tag:(NSInteger)items.count];
        item.selectedImage = glyphFor(entry, YES);
        [items addObject:item];
    }
    return items;
}

// What Navbar.x composes from the same list: with nothing left shown, Spotify's own tabs come back.
- (void)showEntries:(NSArray<NSDictionary *> *)entries {
    BOOL custom = ASMVitrineEnabled(ASMVitrineRKeyNavbar), names = !ASMVitrineHidden(ASMVitrineRKeyNavbarHideLabels);
    NSMutableArray<NSDictionary *> *shown = [NSMutableArray array];
    if (custom) for (NSDictionary *entry in entries) if (![entry[ASMVitrineRNavbarHidden] boolValue]) [shown addObject:entry];
    if (!shown.count) [shown addObjectsFromArray:stockEntries()];
    NSSet<NSString *> *split = custom ? [NSSet setWithArray:ASMVitrineRNavbarSplit()] : nil;
    NSMutableArray<NSDictionary *> *main = [NSMutableArray array], *apart = [NSMutableArray array];
    for (NSDictionary *entry in shown) [([split containsObject:entry[ASMVitrineRNavbarID]] ? apart : main) addObject:entry];
    if (!main.count) {
        main = shown;
        apart = [NSMutableArray array];
    }
    [_main setItems:itemsFor(main, names) animated:NO];
    _main.selectedItem = _main.items.firstObject;
    [_apart setItems:itemsFor(apart, names) animated:NO];
    _apart.selectedItem = nil;
    _apart.hidden = !apart.count;
    self.accessibilityValue = [[shown valueForKey:ASMVitrineRNavbarTitle] componentsJoinedByString:@", "];
    [self setNeedsLayout];
}

- (CGSize)sizeThatFits:(CGSize)size {
    return CGSizeMake(size.width, [_main sizeThatFits:CGSizeMake(size.width, 49)].height);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds, main = bounds, apart = CGRectZero;
    if (!_apart.hidden) {
        CGFloat width = MIN(bounds.size.width / 2, _apart.items.count * kApartItemWidth + 2 * kPlatterInset);
        CGRectDivide(bounds, &apart, &main, width, CGRectMaxXEdge);
        main.size.width += 2 * kPlatterInset - kPlatterGap;
    }
    _main.frame = main;
    _apart.frame = apart;
    for (UITabBar *bar in @[_main, _apart]) {
        [bar layoutIfNeeded];
        ASMVitrineRShrinkTabTitles(bar);
    }
}

@end

#pragma mark - the labels' cards

// One of the two ways the bar can label its tabs, as a picture of the bar's first three tabs with or without
// their names, the choice's name under it and a check circle under that.
@interface ASMVitrineRLabelCard : UIControl
@property (nonatomic, readonly) BOOL names;
- (instancetype)initWithTitle:(NSString *)title names:(BOOL)names;
- (void)showEntries:(NSArray<NSDictionary *> *)entries;
@end

@implementation ASMVitrineRLabelCard {
    UIView *_picture;
    NSMutableArray<UIImageView *> *_glyphs;
    NSMutableArray<UIView *> *_bars;   // a gray bar under each glyph stands for its name
    UILabel *_title;
    UIImageView *_check;
}

static const CGFloat kPictureHeight = 76;

- (instancetype)initWithTitle:(NSString *)title names:(BOOL)names {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _names = names;
    _picture = [UIView new];
    _picture.backgroundColor = ASMVitrineCardBackground();
    _picture.layer.cornerRadius = 18;
    _picture.layer.cornerCurve = kCACornerCurveContinuous;
    _picture.userInteractionEnabled = NO;
    [self addSubview:_picture];
    _glyphs = [NSMutableArray array];
    _bars = [NSMutableArray array];
    for (NSUInteger i = 0; i < 3; i++) {
        UIImageView *glyph = [UIImageView new];
        glyph.contentMode = UIViewContentModeScaleAspectFit;
        glyph.tintColor = UIColor.whiteColor;
        [_picture addSubview:glyph];
        [_glyphs addObject:glyph];
        UIView *bar = [UIView new];
        bar.backgroundColor = ASMVitrineGrey();
        bar.layer.cornerRadius = 2;
        bar.hidden = !names;
        [_picture addSubview:bar];
        [_bars addObject:bar];
    }
    _title = [UILabel new];
    _title.text = title;
    _title.font = ASMVitrineSubtitleFont();
    _title.textColor = UIColor.whiteColor;
    _title.textAlignment = NSTextAlignmentCenter;
    _title.adjustsFontSizeToFitWidth = YES;
    _title.minimumScaleFactor = 0.8;
    [self addSubview:_title];
    _check = [UIImageView new];
    _check.contentMode = UIViewContentModeCenter;
    [self addSubview:_check];
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = title;
    return self;
}

- (void)showEntries:(NSArray<NSDictionary *> *)entries {
    for (NSUInteger i = 0; i < 3; i++) {
        NSDictionary *entry = i < entries.count ? entries[i] : nil;
        _glyphs[i].image = entry ? [glyphFor(entry, NO) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : nil;
        _bars[i].alpha = entry ? 1 : 0;
    }
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    _picture.layer.borderWidth = selected ? 2 : 0;
    _picture.layer.borderColor = ASMVitrineRAccent().CGColor;
    UIImageSymbolConfiguration *size = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
    _check.image = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle" withConfiguration:size];
    _check.tintColor = selected ? ASMVitrineRAccent() : ASMVitrineGrey();
    self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    _picture.alpha = highlighted ? 0.6 : 1;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    _picture.frame = CGRectMake(0, 0, width, kPictureHeight);
    CGFloat slot = (width - 16) / 3, glyphTop = _names ? 18 : 26;
    for (NSUInteger i = 0; i < 3; i++) {
        CGFloat x = 8 + i * slot;
        _glyphs[i].frame = CGRectMake(x + (slot - 24) / 2, glyphTop, 24, 24);
        _bars[i].frame = CGRectMake(x + (slot - 20) / 2, glyphTop + 32, 20, 4);
    }
    _title.font = ASMVitrineSubtitleFont();
    _title.numberOfLines = [ASMVitrineRLabelCard titleLines];
    CGFloat titleHeight = _title.numberOfLines * ceil(_title.font.lineHeight);
    _title.frame = CGRectMake(0, kPictureHeight + 8, width, titleHeight);
    _check.frame = CGRectMake((width - 44) / 2, CGRectGetMaxY(_title.frame) - 6, 44, 44);
}

// The name takes a second line at the accessibility sizes, where half the row is too narrow for it.
+ (NSInteger)titleLines {
    return ASMVitrineAccessibilityTextSize() ? 2 : 1;
}

+ (CGFloat)height {
    return kPictureHeight + 8 + [self titleLines] * ceil(ASMVitrineSubtitleFont().lineHeight) - 6 + 44;
}

@end

#pragma mark - the page

typedef NS_ENUM(NSInteger, ASMVitrineRNavbarSection) {
    ASMVitrineRNavbarSectionSwitch,
    ASMVitrineRNavbarSectionLabels,
    ASMVitrineRNavbarSectionTabs,
    ASMVitrineRNavbarSectionLinks,   // Add a tab, Use Spotify's tabs
    ASMVitrineRNavbarSectionSplit,
    ASMVitrineRNavbarSectionCount,
};

// A tab of the list: a check circle that shows or hides it, its glyph, its name, and the table's drag handle.
@interface ASMVitrineRTabCell : UITableViewCell
@property (nonatomic, strong) UIButton *check;
@end

@implementation ASMVitrineRTabCell
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat height = self.contentView.bounds.size.height;
    self.check.frame = CGRectMake(4, (height - 44) / 2, 44, 44);
}
@end

// The labels' cell: clear, so it drops the inset-grouped corner mask that clipped the cards' outer corners.
@interface ASMVitrineRUnclippedCell : UITableViewCell
@end

@implementation ASMVitrineRUnclippedCell

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = 0;
    self.layer.masksToBounds = NO;
    self.contentView.clipsToBounds = NO;
}

@end

// The tab editor: a preview of the bar, how it labels its tabs, the tabs in the order the bar shows them
// (the circle shows or hides one, the handle drags it, a tap on one of the mod's own opens it in the Add a
// Tab sheet to edit or remove), then adding one, going back to Spotify's tabs and splitting tabs apart.
// Spotify's own tabs are named by their label and drawn by Spotify, so they can be hidden but not renamed,
// given another icon or removed. Mod Settings and the welcome tour show the same editor.
@interface ASMVitrineRNavbarPage : ASMVitrinePage
@end

@implementation ASMVitrineRNavbarPage {
    NSMutableArray<NSMutableDictionary *> *_entries;
    ASMVitrineRTabBarPreview *_preview;
    UIView *_header;
    ASMVitrineRLabelCard *_withNames, *_iconsOnly;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Tab bar";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.editing = YES;
    _preview = [ASMVitrineRTabBarPreview new];
    _header = [UIView new];
    [_header addSubview:_preview];
    self.tableView.tableHeaderView = _header;
    _withNames = [[ASMVitrineRLabelCard alloc] initWithTitle:@"Icons and names" names:YES];
    _iconsOnly = [[ASMVitrineRLabelCard alloc] initWithTitle:@"Icons only" names:NO];
    for (ASMVitrineRLabelCard *card in @[_withNames, _iconsOnly]) [card addTarget:self action:@selector(labelsPicked:) forControlEvents:UIControlEventTouchUpInside];
    _entries = navbarEntries();
    [self showChoices];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Split tabs, a page pushed from here, changes what the preview shows.
    [self reload];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width;
    CGFloat height = [_preview sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    _preview.frame = CGRectMake(0, 8, width, height);
    CGSize size = CGSizeMake(width, CGRectGetMaxY(_preview.frame) + 8);
    if (CGSizeEqualToSize(_header.bounds.size, size)) return;
    _header.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = _header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

// The preview and the cards, from the list as it stands.
- (void)showChoices {
    [_preview showEntries:_entries];
    NSMutableArray<NSDictionary *> *shown = [NSMutableArray array];
    for (NSDictionary *entry in _entries) if (![entry[ASMVitrineRNavbarHidden] boolValue]) [shown addObject:entry];
    BOOL names = !ASMVitrineHidden(ASMVitrineRKeyNavbarHideLabels);
    for (ASMVitrineRLabelCard *card in @[_withNames, _iconsOnly]) {
        [card showEntries:shown.count ? shown : (NSArray *)_entries];
        card.selected = card.names == names;
    }
    [self.view setNeedsLayout];
}

- (void)reload {
    _entries = navbarEntries();
    [self.tableView reloadData];
    [self showChoices];
}

- (void)save {
    ASMVitrineRSetNavbarLayout(_entries);
    // A split tab removed leaves the split list with it.
    NSArray *idents = [_entries valueForKey:ASMVitrineRNavbarID];
    ASMVitrineRSetNavbarSplit([ASMVitrineRNavbarSplit() filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", idents]]);
    ASMVitrineRRefreshTabBar();
    [self showChoices];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMVitrineRNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == ASMVitrineRNavbarSectionTabs) return (NSInteger)_entries.count;
    return section == ASMVitrineRNavbarSectionLinks ? 2 : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == ASMVitrineRNavbarSectionTabs ? @"Tabs" : nil;
}

- (NSString *)footerFor:(NSInteger)section {
    if (section == ASMVitrineRNavbarSectionSwitch && !ASMVitrineEnabled(ASMVitrineRKeyNavbar))
        return @"Off, the bar shows Spotify's own tabs in Spotify's order. Your list is kept for when it is on again.";
    if (section == ASMVitrineRNavbarSectionTabs)
        return @"Drag a tab to move it. Tap one you added to rename it or change its icon, or one of Spotify's to hide it.";
    return nil;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self headerFor:section];
    return title ? ASMVitrineSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return [self headerFor:section] ? ASMVitrineSectionHeaderHeight() : ASMVitrineSectionGap;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    NSString *text = [self footerFor:section];
    return text ? ASMVitrineSectionFooter(table, text) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    NSString *text = [self footerFor:section];
    return text ? ASMVitrineSectionFooterHeight(table, text) : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineRNavbarSectionLabels ? [ASMVitrineRLabelCard height] : UITableViewAutomaticDimension;
}

- (UITableViewCell *)labelsCell:(UITableView *)table {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"labels"] ?: [[ASMVitrineRUnclippedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"labels"];
    cell.contentConfiguration = nil;
    cell.backgroundColor = UIColor.clearColor;
    cell.backgroundConfiguration = [UIBackgroundConfiguration clearConfiguration];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (_withNames.superview != cell.contentView) {
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_withNames, _iconsOnly]];
        row.distribution = UIStackViewDistributionFillEqually;
        row.spacing = 12;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
            [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
            [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        ]];
    }
    return cell;
}

- (UITableViewCell *)tabCell:(UITableView *)table at:(NSIndexPath *)path {
    ASMVitrineRTabCell *cell = [table dequeueReusableCellWithIdentifier:@"tab"] ?: [[ASMVitrineRTabCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"tab"];
    NSDictionary *entry = _entries[(NSUInteger)path.row];
    BOOL hidden = [entry[ASMVitrineRNavbarHidden] boolValue];
    ASMVitrineFillCell(cell, entry[ASMVitrineRNavbarTitle], nil, hidden ? ASMVitrineGrey() : nil, nil);
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    content.image = glyphFor(entry, NO);
    content.imageProperties.tintColor = hidden ? ASMVitrineGrey() : UIColor.whiteColor;
    content.imageProperties.maximumSize = CGSizeMake(24, 24);
    content.imageProperties.reservedLayoutSize = CGSizeMake(28, 28);
    content.imageToTextPadding = 12;
    NSDirectionalEdgeInsets margins = content.directionalLayoutMargins;
    margins.leading = 52;
    content.directionalLayoutMargins = margins;
    cell.contentConfiguration = content;
    cell.separatorInset = UIEdgeInsetsMake(0, 52, 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessibilityValue = hidden ? @"Hidden" : @"Shown";
    cell.accessibilityHint = entry[ASMVitrineRNavbarURI] ? @"Opens the tab to edit it" : @"Shows or hides the tab";

    if (!cell.check) {
        cell.check = [UIButton buttonWithType:UIButtonTypeSystem];
        [cell.check addTarget:self action:@selector(checkTapped:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:cell.check];
    }
    UIImageSymbolConfiguration *size = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
    [cell.check setImage:[UIImage systemImageNamed:hidden ? @"circle" : @"checkmark.circle.fill" withConfiguration:size] forState:UIControlStateNormal];
    cell.check.tintColor = hidden ? ASMVitrineGrey() : ASMVitrineRAccent();
    cell.check.accessibilityLabel = [NSString stringWithFormat:@"Show %@ on the bar", entry[ASMVitrineRNavbarTitle]];
    cell.check.accessibilityValue = hidden ? @"Off" : @"On";
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == ASMVitrineRNavbarSectionLabels) return [self labelsCell:table];
    if (path.section == ASMVitrineRNavbarSectionTabs) return [self tabCell:table at:path];
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"navbar");
    switch (path.section) {
        case ASMVitrineRNavbarSectionSwitch: {
            ASMVitrineFillCell(cell, @"Custom tab bar", @"Your order, hidden tabs and tabs you add", nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMVitrineGreen();
            toggle.on = ASMVitrineEnabled(ASMVitrineRKeyNavbar);
            [toggle addTarget:self action:@selector(customToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMVitrineRNavbarSectionLinks:
            // Links in the accent color, as the system's own actions in a list are.
            ASMVitrineFillCell(cell, path.row == 0 ? @"Add a tab" : @"Use Spotify's tabs", nil, ASMVitrineRAccent(), nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            break;
        default:
            ASMVitrineFillCell(cell, @"Split tabs", @"Place chosen tabs apart on the right", nil, @"rectangle.split.2x1");
            cell.accessoryView = ASMVitrineSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineRNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineRNavbarSectionTabs;
}

// The circle stands where the delete control would; a tab of the mod's own is removed from its sheet.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)table shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path {
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    if (to.section == ASMVitrineRNavbarSectionTabs) return to;
    // Dragged past either end of the list, the tab stops at that end.
    return [NSIndexPath indexPathForRow:to.section < ASMVitrineRNavbarSectionTabs ? 0 : (NSInteger)_entries.count - 1 inSection:ASMVitrineRNavbarSectionTabs];
}

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSMutableDictionary *entry = _entries[(NSUInteger)from.row];
    [_entries removeObjectAtIndex:(NSUInteger)from.row];
    [_entries insertObject:entry atIndex:(NSUInteger)to.row];
    [self save];
}

- (void)toggleRow:(NSInteger)row {
    NSMutableDictionary *entry = _entries[(NSUInteger)row];
    entry[ASMVitrineRNavbarHidden] = [entry[ASMVitrineRNavbarHidden] boolValue] ? nil : @YES;
    [self save];
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:ASMVitrineRNavbarSectionTabs]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)checkTapped:(UIButton *)check {
    UIView *view = check;
    while (view && ![view isKindOfClass:UITableViewCell.class]) view = view.superview;
    NSIndexPath *path = view ? [self.tableView indexPathForCell:(UITableViewCell *)view] : nil;
    if (path.section == ASMVitrineRNavbarSectionTabs) [self toggleRow:path.row];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    __weak typeof(self) weakSelf = self;
    switch (path.section) {
        case ASMVitrineRNavbarSectionTabs:
            if (_entries[(NSUInteger)path.row][ASMVitrineRNavbarURI]) [self editRow:path.row];
            else [self toggleRow:path.row];
            break;
        case ASMVitrineRNavbarSectionLinks: {
            if (path.row == 1) {
                [self reset];
                break;
            }
            ASMVitrinePresentAddTabSheet(self, tabPresets(), ^(NSDictionary *tab) {
                appendTab(tab);
                [weakSelf reload];
            });
            break;
        }
        case ASMVitrineRNavbarSectionSplit:
            [self.navigationController pushViewController:[ASMVitrineRSplitTabsPage new] animated:YES];
            break;
    }
}

// The entry of the list as it is now with this identity; the list is read again whenever the page appears.
- (NSMutableDictionary *)entryWithID:(NSString *)ident {
    for (NSMutableDictionary *entry in _entries) if ([entry[ASMVitrineRNavbarID] isEqualToString:ident]) return entry;
    return nil;
}

// The Add a Tab sheet over the tab as it is; Save keeps its place on the bar and its identity.
- (void)editRow:(NSInteger)row {
    NSDictionary *entry = _entries[(NSUInteger)row];
    NSString *ident = entry[ASMVitrineRNavbarID];
    NSMutableDictionary *tab = [@{ASMVitrineTabTitle: entry[ASMVitrineRNavbarTitle] ?: @"", ASMVitrineTabURI: entry[ASMVitrineRNavbarURI], ASMVitrineTabIcon: entry[ASMVitrineRNavbarIcon] ?: @"star"} mutableCopy];
    tab[ASMVitrineTabIconSet] = entry[ASMVitrineRNavbarIconSet];
    __weak typeof(self) weakSelf = self;
    ASMVitrinePresentEditTabSheet(self, tabPresets(), tab, ^(NSDictionary *edited) {
        NSMutableDictionary *now = [weakSelf entryWithID:ident];
        if (!now) return;
        now[ASMVitrineRNavbarTitle] = edited[ASMVitrineTabTitle];
        now[ASMVitrineRNavbarURI] = edited[ASMVitrineTabURI];
        now[ASMVitrineRNavbarIcon] = edited[ASMVitrineTabIcon];
        now[ASMVitrineRNavbarIconSet] = edited[ASMVitrineTabIconSet];
        [weakSelf save];
        [weakSelf.tableView reloadData];
    }, ^{
        typeof(self) page = weakSelf;
        NSMutableDictionary *now = [page entryWithID:ident];
        if (!now) return;
        [page->_entries removeObjectIdenticalTo:now];
        [page save];
        [page.tableView reloadData];
    });
}

- (void)labelsPicked:(ASMVitrineRLabelCard *)card {
    if (card.selected) return;
    ASMVitrineSetEnabled(ASMVitrineRKeyNavbarHideLabels, !card.names);
    [[UISelectionFeedbackGenerator new] selectionChanged];
    ASMVitrineRRefreshTabBar();
    [self showChoices];
}

- (void)customToggled:(UISwitch *)toggle {
    ASMVitrineSetEnabled(ASMVitrineRKeyNavbar, toggle.on);
    ASMVitrineRRefreshTabBar();
    [self showChoices];
    [UIView performWithoutAnimation:^{
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:ASMVitrineRNavbarSectionSwitch] withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's tabs"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, the tabs you added go, and no tab is split apart."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMVitrineRSetNavbarLayout(@[]);
        ASMVitrineRSetNavbarSplit(@[]);
        ASMVitrineRRefreshTabBar();
        [self reload];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMVitrineRNavbarSettingsPage(void) {
    return [ASMVitrineRNavbarPage new];
}

UIViewController *ASMVitrineRNavbarEditorPage(void) {
    return [ASMVitrineRNavbarPage new];
}
