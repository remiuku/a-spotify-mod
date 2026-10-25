#import "Core/ASMVitrineCore.h"
#import "AddTabSheet.h"
#import "Links.h"
#import "TabIcons.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"

NSString *const ASMVitrineTabTitle = @"title";
NSString *const ASMVitrineTabURI = @"uri";
NSString *const ASMVitrineTabIcon = @"icon";
NSString *const ASMVitrineTabIconSet = @"iconSet";

static NSString *const kCompactDetent = @"asm.interface.vitrine.addTab.compact";

// The tab being put together, shared by the sheet's three pages.
@interface ASMVitrineTabDraft : NSObject
@property (nonatomic, copy) NSString *title, *uri, *icon;
@property (nonatomic) BOOL symbols;
// Once an icon is picked, a preset picked after it leaves the icon alone.
@property (nonatomic) BOOL iconChosen;
@end

@implementation ASMVitrineTabDraft
@end

// What the dispatcher makes of a URI, logged, so a link left out or refused says why. Unknown (the
// dispatcher is not set up yet, or not where 9.1.78 keeps it) lets the link through, as before.
static ASMVitrineLinkRoute routeOf(NSURL *url, NSString *what) {
    NSString *via = nil;
    ASMVitrineLinkRoute route = ASMVitrineSpotifyURIRoute(url, &via);
    ASMVitrineLog(@"add tab: %@ %@ -> %@", what, url.absoluteString,
          route == ASMVitrineLinkRouteOpens ? via : route == ASMVitrineLinkRouteNone ? @"no handler" : @"unknown");
    return route;
}

static NSString *iconSummary(ASMVitrineTabDraft *draft) {
    return [NSString stringWithFormat:@"%@ · %@", draft.symbols ? @"SF Symbols" : @"Spotify Encore", draft.icon];
}

// An icon at `size`, centered in a box of that size, for the right of a row.
static UIView *previewOf(NSString *name, BOOL symbols, CGFloat size) {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    UIView *icon = ASMVitrineTabIconView(name, symbols, UIColor.whiteColor);
    // Encore's views lay themselves out from constraints; this one is placed by frame.
    icon.translatesAutoresizingMaskIntoConstraints = YES;
    icon.frame = box.bounds;
    if ([icon isKindOfClass:UIImageView.class]) icon.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:icon];
    box.isAccessibilityElement = NO;
    box.accessibilityElementsHidden = YES;
    return box;
}

static UIView *withChevron(UIView *view) {
    UIImageView *chevron = ASMVitrineSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
    CGFloat height = MAX(view.bounds.size.height, chevron.bounds.size.height);
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width + 8 + chevron.bounds.size.width, height)];
    view.center = CGPointMake(view.bounds.size.width / 2, height / 2);
    chevron.center = CGPointMake(box.bounds.size.width - chevron.bounds.size.width / 2, height / 2);
    [box addSubview:view];
    [box addSubview:chevron];
    return box;
}

static void showProblem(UIViewController *page, NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [page presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Choose a Link

@interface ASMVitrineTabLinkPage : ASMVitrinePage
- (instancetype)initWithDraft:(ASMVitrineTabDraft *)draft presets:(NSArray<NSDictionary *> *)presets;
@end

@implementation ASMVitrineTabLinkPage {
    ASMVitrineTabDraft *_draft;
    NSArray<NSDictionary *> *_presets;
}

- (instancetype)initWithDraft:(ASMVitrineTabDraft *)draft presets:(NSArray<NSDictionary *> *)presets {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Choose a Link";
    _draft = draft;
    _presets = presets;
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)_presets.count : 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeader(table, section == 0 ? @"Spotify's pages" : @"Custom link");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeaderHeight();
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return section == 1 ? ASMVitrineSectionFooter(table, @"Paste a share link or a spotify: URI.") : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return section == 1 ? ASMVitrineSectionFooterHeight(table, @"Paste a share link or a spotify: URI.") : CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"link");
    if (path.section == 0) {
        NSDictionary *tab = _presets[(NSUInteger)path.row];
        BOOL current = [tab[ASMVitrineTabURI] isEqualToString:_draft.uri];
        ASMVitrineFillCell(cell, tab[ASMVitrineTabTitle], tab[ASMVitrineTabURI], nil, nil);
        cell.accessoryView = current ? ASMVitrineSymbolView(@"checkmark", 15, UIImageSymbolWeightSemibold, 24) : previewOf(tab[ASMVitrineTabIcon], NO, 24);
    } else {
        ASMVitrineFillCell(cell, @"Enter a custom link…", nil, nil, @"link");
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        NSDictionary *tab = _presets[(NSUInteger)path.row];
        _draft.uri = tab[ASMVitrineTabURI];
        if (!_draft.title.length) _draft.title = tab[ASMVitrineTabTitle];
        if (!_draft.iconChosen) {
            _draft.icon = tab[ASMVitrineTabIcon];
            _draft.symbols = NO;
        }
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom Link" message:@"A share link or a spotify: URI." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"spotify:playlist:…";
        field.text = self->_draft.uri;
        field.keyboardType = UIKeyboardTypeURL;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Use Link" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self useLink:alert.textFields.firstObject.text];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Said here rather than by Spotify's "Couldn't open link" on the bar later, every time the tab is tapped.
- (void)useLink:(NSString *)text {
    NSURL *url = ASMVitrineSpotifyURIFromText(text);
    BOOL spotify = [url.scheme.lowercaseString isEqualToString:@"spotify"];
    if (!spotify || routeOf(url, @"custom") == ASMVitrineLinkRouteNone) {
        NSString *what = text.length ? text : @"nothing";
        showProblem(self, @"Can't Use That Link",
                    spotify ? [NSString stringWithFormat:@"Spotify has nowhere to open %@, so it would not work as a tab.", url.absoluteString]
                            : [NSString stringWithFormat:@"%@ is not a share link or a spotify: URI.", what]);
        return;
    }
    _draft.uri = url.absoluteString;
    if (!_draft.title.length) _draft.title = _draft.uri;
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark - Choose an Icon

@interface ASMVitrineTabIconPage : ASMVitrinePage <UISearchResultsUpdating, UISearchControllerDelegate>
- (instancetype)initWithDraft:(ASMVitrineTabDraft *)draft;
@end

@implementation ASMVitrineTabIconPage {
    ASMVitrineTabDraft *_draft;
    UISegmentedControl *_sets;
    UISearchController *_search;
    NSArray<NSString *> *_symbols;      // every SF Symbol, once ASMVitrineLoadSymbolNames has them
    NSArray<NSArray<NSString *> *> *_sections;
    NSArray<NSString *> *_headers;
    NSString *_footer;
    NSUInteger _generation;   // a search that finishes after a newer one began is dropped
    BOOL _popAfterSearch;
}

- (instancetype)initWithDraft:(ASMVitrineTabDraft *)draft {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Choose an Icon";
    _draft = draft;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _sets = [[UISegmentedControl alloc] initWithItems:@[@"Spotify Encore", @"SF Symbols"]];
    _sets.selectedSegmentIndex = _draft.symbols ? 1 : 0;
    [_sets addTarget:self action:@selector(setChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = _sets;

    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.delegate = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Search icons";
    _search.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _search.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    // On 26 the field waits as a button in a toolbar at the bottom, where the thumb is.
    if (@available(iOS 26.0, *)) {
        self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementIntegratedButton;
        self.navigationItem.searchBarPlacementAllowsToolbarIntegration = YES;
        self.toolbarItems = @[[UIBarButtonItem flexibleSpaceItem], self.navigationItem.searchBarPlacementBarButtonItem];
    }
    self.definesPresentationContext = YES;

    __weak typeof(self) weakSelf = self;
    ASMVitrineLoadSymbolNames(^(NSArray<NSString *> *names) {
        typeof(self) page = weakSelf;
        if (!page) return;
        page->_symbols = names;
        if (page->_sets.selectedSegmentIndex == 1 && page->_search.searchBar.text.length) [page filterNow];
    });
    [self filterNow];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (@available(iOS 26.0, *)) [self.navigationController setToolbarHidden:NO animated:animated];
    // Hundreds of rows want the whole height.
    UISheetPresentationController *sheet = self.navigationController.sheetPresentationController;
    [sheet animateChanges:^{
        sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _search.active = NO;
    [self.navigationController setToolbarHidden:YES animated:animated];
}

- (void)didDismissSearchController:(UISearchController *)search {
    if (!_popAfterSearch) return;
    _popAfterSearch = NO;
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setChanged {
    [self filterNow];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSUInteger generation = ++_generation;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) page = weakSelf;
        if (page && page->_generation == generation) [page filterNow];
    });
}

// Encore: the common glyphs, then the rest. SF Symbols: the common ones, or with a search, any symbol
// this iOS draws whose name holds the text.
- (void)filterNow {
    _generation++;
    NSString *text = [_search.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL symbols = _sets.selectedSegmentIndex == 1;
    _footer = nil;
    if (text.length) {
        NSArray<NSString *> *pool = symbols ? (_symbols ?: ASMVitrineCommonTabSymbols()) : ASMVitrineEncoreGlyphNames();
        NSPredicate *match = [NSPredicate predicateWithFormat:@"SELF CONTAINS[c] %@", text];
        NSArray<NSString *> *found = [pool filteredArrayUsingPredicate:match];
        _sections = @[found];
        _headers = @[@""];
        if (!found.count) _footer = symbols && !_symbols ? @"Still reading the list of SF Symbols…" : @"No icon has that in its name.";
    } else if (symbols) {
        _sections = @[ASMVitrineCommonTabSymbols()];
        _headers = @[@"Suggested"];
        _footer = @"Search finds any SF Symbol.";
    } else {
        NSArray<NSString *> *common = ASMVitrineCommonTabGlyphs();
        NSMutableArray<NSString *> *rest = [ASMVitrineEncoreGlyphNames() mutableCopy];
        [rest removeObjectsInArray:common];
        _sections = @[common, rest];
        _headers = @[@"Suggested", @"All glyphs"];
        if (!ASMVitrineEncoreGlyphNames().count) _footer = @"This version of Spotify has no glyphs to offer. SF Symbols still work.";
    }
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_sections[(NSUInteger)section].count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = _headers[(NSUInteger)section];
    return title.length && _sections[(NSUInteger)section].count ? ASMVitrineSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    NSString *title = _headers[(NSUInteger)section];
    return title.length && _sections[(NSUInteger)section].count ? ASMVitrineSectionHeaderHeight() : ASMVitrineSectionGap;
}

- (BOOL)isLast:(NSInteger)section {
    return section == (NSInteger)_sections.count - 1;
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return _footer && [self isLast:section] ? ASMVitrineSectionFooter(table, _footer) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return _footer && [self isLast:section] ? ASMVitrineSectionFooterHeight(table, _footer) : CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"icon");
    NSString *name = _sections[(NSUInteger)path.section][(NSUInteger)path.row];
    BOOL symbols = _sets.selectedSegmentIndex == 1;
    BOOL current = symbols == _draft.symbols && [name isEqualToString:_draft.icon];
    ASMVitrineFillCell(cell, name, current ? @"Current icon" : nil, nil, nil);
    // A preview is one of Spotify's views; setting a new accessory takes the old one off the reused cell.
    cell.accessoryView = previewOf(name, symbols, 28);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    _draft.icon = _sections[(NSUInteger)path.section][(NSUInteger)path.row];
    _draft.symbols = _sets.selectedSegmentIndex == 1;
    _draft.iconChosen = YES;
    // A search still up is presented over the page and holds it there, so the pop waits for the search
    // to have gone (harness/addtab, `pick`).
    if (!_search.active) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    _popAfterSearch = YES;
    _search.active = NO;
}

@end

#pragma mark - Add a Tab

typedef NS_ENUM(NSInteger, ASMVitrineAddTabSection) {
    ASMVitrineAddTabSectionName,
    ASMVitrineAddTabSectionCustomize,
    ASMVitrineAddTabSectionRemove,   // editing only
};

@interface ASMVitrineAddTabPage : ASMVitrinePage <UITextFieldDelegate>
- (instancetype)initWithPresets:(NSArray<NSDictionary *> *)presets add:(void (^)(NSDictionary *tab))add;
@end

@implementation ASMVitrineAddTabPage {
    ASMVitrineTabDraft *_draft;
    NSArray<NSDictionary *> *_presets;
    void (^_add)(NSDictionary *tab);
    void (^_remove)(void);   // set while editing a tab, which the sheet then offers to remove
    UITextField *_name;
}

// The same sheet over a tab already on the bar: its name, link and icon filled in, Save in place of Add.
- (instancetype)initWithTab:(NSDictionary *)tab presets:(NSArray<NSDictionary *> *)presets save:(void (^)(NSDictionary *tab))save remove:(void (^)(void))remove {
    if (!(self = [self initWithPresets:presets add:save])) return nil;
    self.title = @"Edit Tab";
    _draft.title = tab[ASMVitrineTabTitle];
    _draft.uri = tab[ASMVitrineTabURI];
    _draft.icon = tab[ASMVitrineTabIcon] ?: @"star";
    _draft.symbols = [tab[ASMVitrineTabIconSet] isEqual:ASMVitrineTabIconSetSymbols];
    // A link picked from the presets now leaves the name and the icon the tab has.
    _draft.iconChosen = YES;
    _remove = [remove copy];
    return self;
}

- (instancetype)initWithPresets:(NSArray<NSDictionary *> *)presets add:(void (^)(NSDictionary *tab))add {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Add a Tab";
    _draft = [ASMVitrineTabDraft new];
    _draft.icon = @"star";
    _add = [add copy];
    NSMutableArray<NSDictionary *> *kept = [NSMutableArray array];
    for (NSDictionary *tab in presets) {
        if (routeOf([NSURL URLWithString:tab[ASMVitrineTabURI]], @"preset") != ASMVitrineLinkRouteNone) [kept addObject:tab];
    }
    _presets = kept;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:_remove ? @"Save" : @"Add" style:UIBarButtonItemStyleDone target:self action:@selector(addTab)];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    _name = [UITextField new];
    _name.placeholder = @"Name";
    _name.accessibilityLabel = @"Name";
    _name.font = ASMVitrineTitleFont();
    _name.textColor = UIColor.whiteColor;
    _name.clearButtonMode = UITextFieldViewModeWhileEditing;
    _name.autocorrectionType = UITextAutocorrectionTypeNo;
    _name.returnKeyType = UIReturnKeyDone;
    _name.delegate = self;
    [_name addTarget:self action:@selector(nameChanged) forControlEvents:UIControlEventEditingChanged];
}

// The pages pushed from here change the draft.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (![_name.text isEqualToString:_draft.title ?: @""]) _name.text = _draft.title;
    self.navigationItem.rightBarButtonItem.enabled = _draft.uri.length > 0;
    [self.tableView reloadData];
}

- (void)nameChanged {
    _draft.title = _name.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
    [field resignFirstResponder];
    return NO;
}

- (void)cancel {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)addTab {
    if (!_draft.uri.length) return;
    NSString *title = [_name.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableDictionary *tab = [@{ASMVitrineTabTitle: title.length ? title : _draft.uri, ASMVitrineTabURI: _draft.uri, ASMVitrineTabIcon: _draft.icon ?: @"star"} mutableCopy];
    if (_draft.symbols) tab[ASMVitrineTabIconSet] = ASMVitrineTabIconSetSymbols;
    ASMVitrineLog(@"add tab: %@", tab);
    void (^add)(NSDictionary *) = _add;
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    if (add) add(tab);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return _remove ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == ASMVitrineAddTabSectionCustomize ? 2 : 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == ASMVitrineAddTabSectionRemove) return nil;
    return ASMVitrineSectionHeader(table, section == ASMVitrineAddTabSectionName ? @"Name" : @"Customize");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == ASMVitrineAddTabSectionRemove ? ASMVitrineSectionGap : ASMVitrineSectionHeaderHeight();
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == ASMVitrineAddTabSectionName) {
        UITableViewCell *cell = ASMVitrineDequeueCell(table, @"name");
        ASMVitrineFillCell(cell, nil, nil, nil, nil);
        if (_name.superview != cell.contentView) {
            _name.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.contentView addSubview:_name];
            [NSLayoutConstraint activateConstraints:@[
                [_name.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [_name.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [_name.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
                [_name.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
                [_name.heightAnchor constraintGreaterThanOrEqualToConstant:44],
            ]];
        }
        return cell;
    }
    if (path.section == ASMVitrineAddTabSectionRemove) {
        UITableViewCell *cell = ASMVitrineDequeueCell(table, @"remove");
        ASMVitrineFillCell(cell, @"Remove Tab", nil, ASMVitrineRed(), nil);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"customize");
    if (path.row == 0) {
        ASMVitrineFillCell(cell, @"Link", _draft.uri ?: @"Choose a page or paste a link", nil, @"link");
        cell.accessoryView = ASMVitrineSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
    } else {
        ASMVitrineFillCell(cell, @"Icon", iconSummary(_draft), nil, @"square.grid.2x2");
        cell.accessoryView = withChevron(previewOf(_draft.icon, _draft.symbols, 24));
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMVitrineAddTabSectionRemove) {
        [self confirmRemove];
        return;
    }
    if (path.section != ASMVitrineAddTabSectionCustomize) {
        [_name becomeFirstResponder];
        return;
    }
    [_name resignFirstResponder];
    UIViewController *page = path.row == 0 ? [[ASMVitrineTabLinkPage alloc] initWithDraft:_draft presets:_presets]
                                           : [[ASMVitrineTabIconPage alloc] initWithDraft:_draft];
    [self.navigationController pushViewController:page animated:YES];
}

// The tab, its link and its icon go with it, so the sheet asks first.
- (void)confirmRemove {
    NSString *name = _draft.title.length ? _draft.title : @"this tab";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:[NSString stringWithFormat:@"Remove %@ from the tab bar?", name]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove Tab" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        void (^remove)(void) = self->_remove;
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        if (remove) remove();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:ASMVitrineAddTabSectionRemove]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

static void presentSheet(UIViewController *owner, ASMVitrineAddTabPage *page) {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
    // Outside Spotify's own stacks the sheet would take the system's appearance, light in light mode.
    ASMVitrinePresentDark(nav);
    UISheetPresentationController *sheet = nav.sheetPresentationController;
    // Tall enough for the name and the two rows under the navigation bar, and Remove Tab while editing; the
    // keyboard lifts it.
    CGFloat height = [page numberOfSectionsInTableView:page.tableView] > 2 ? 400 : 320;
    UISheetPresentationControllerDetent *compact = [UISheetPresentationControllerDetent customDetentWithIdentifier:kCompactDetent resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
        return MIN(height, context.maximumDetentValue);
    }];
    sheet.detents = @[compact, UISheetPresentationControllerDetent.largeDetent];
    sheet.selectedDetentIdentifier = kCompactDetent;
    sheet.prefersGrabberVisible = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    [owner presentViewController:nav animated:YES completion:nil];
}

void ASMVitrinePresentAddTabSheet(UIViewController *owner, NSArray<NSDictionary *> *presets, void (^add)(NSDictionary *tab)) {
    presentSheet(owner, [[ASMVitrineAddTabPage alloc] initWithPresets:presets add:add]);
}

void ASMVitrinePresentEditTabSheet(UIViewController *owner, NSArray<NSDictionary *> *presets, NSDictionary *tab,
                           void (^save)(NSDictionary *tab), void (^remove)(void)) {
    presentSheet(owner, [[ASMVitrineAddTabPage alloc] initWithTab:tab presets:presets save:save remove:remove]);
}
