// The Presets and Headphones pages the Audio effects page's first card opens. Both stay open after a pick,
// so one preset or one headphone after another can be heard before going back.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "AudioEffectsPage.h"
#import "AudioEffectsPresets.h"

static void showAlert(UIViewController *owner, NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [owner presentViewController:alert animated:YES completion:nil];
}

static void tick(UITableViewCell *cell, BOOL on) {
    if (on) {
        UIImageView *tick = ASMVitrineSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
        tick.tintColor = ASMVitrineAccentMark();
        cell.accessoryView = tick;
    }
    cell.accessibilityTraits = on ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
}

#pragma mark - presets

// A pick replaces every effect's settings, so the first pick each time the page opens saves them first,
// as one of the user's presets under this name, kept at the top of theirs: a tap on it puts them back.
static NSString *const kBeforePresets = @"Before presets";

// The user's presets, the settings from before the last round of picks first.
static NSArray<NSString *> *userPresetNames(void) {
    NSMutableArray<NSString *> *names = [ASMVitrineDSPUserPresetNames() mutableCopy];
    if ([names containsObject:kBeforePresets]) {
        [names removeObject:kBeforePresets];
        [names insertObject:kBeforePresets atIndex:0];
    }
    return names;
}

// The built-in presets, then the user's, then Save. The last one picked is ticked until something else is.
@interface ASMVitrineDSPPresetList : ASMVitrinePage
@end

@implementation ASMVitrineDSPPresetList {
    NSArray<NSString *> *_builtIn, *_mine;
    NSIndexPath *_picked;
    UIView *_footer;
    BOOL _kept;   // the settings from before this page's first pick are saved
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Presets";
    _builtIn = ASMVitrineDSPBuiltInPresetNames();
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _footer = ASMVitrineNote(@"Picking a preset turns Audio effects on and replaces the other effects' settings. A built-in "
                      "preset leaves the Graphic EQ, your headphones' correction, as it is; your own presets keep every "
                      "effect, the Graphic EQ too. What you had before the first pick is kept under Yours as Before presets. "
                      "Swipe left on one of yours to delete it.");
    self.tableView.tableFooterView = _footer;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _footer, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _mine = userPresetNames();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 3;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return (NSInteger)_builtIn.count;
    if (section == 1) return MAX((NSInteger)_mine.count, 1);
    return 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return section == 2 ? nil : ASMVitrineSectionHeader(table, section == 0 ? @"Built in" : @"Yours");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == 2 ? ASMVitrineSectionGap : ASMVitrineSectionHeaderHeight();
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"preset");
    if (path.section == 2) {
        ASMVitrineFillCell(cell, @"Save current settings…", @"Every effect as it is now, under a name", nil, @"square.and.arrow.down");
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    if (path.section == 1 && !_mine.count) {
        ASMVitrineFillCell(cell, @"None saved yet", nil, ASMVitrineGrey(), nil);
        cell.accessibilityTraits = UIAccessibilityTraitNone;
        return cell;
    }
    BOOL builtIn = path.section == 0;
    ASMVitrineFillCell(cell, (builtIn ? _builtIn : _mine)[(NSUInteger)path.row], builtIn ? ASMVitrineDSPBuiltInPresetDetail(path.row) : nil, nil, nil);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    tick(cell, [path isEqual:_picked]);
    return cell;
}

- (BOOL)tableView:(UITableView *)table shouldHighlightRowAtIndexPath:(NSIndexPath *)path {
    return path.section != 1 || _mine.count;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == 2) {
        [self askForName];
        return;
    }
    if (path.section == 1 && !_mine.count) return;
    NSString *name = path.section == 1 ? _mine[(NSUInteger)path.row] : nil;
    // Loading Before presets itself is the way back, so it is never written over by its own pick.
    if (!_kept && ![name isEqualToString:kBeforePresets]) {
        ASMVitrineDSPSaveUserPreset(kBeforePresets);
        _kept = YES;
        _mine = userPresetNames();
    }
    if (path.section == 0) ASMVitrineDSPLoadBuiltInPreset(path.row);
    else if (!ASMVitrineDSPLoadUserPreset(name)) return;
    _picked = name ? [NSIndexPath indexPathForRow:(NSInteger)[_mine indexOfObject:name] inSection:1] : path;
    [table reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)] withRowAnimation:UITableViewRowAnimationNone];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)table trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != 1 || !_mine.count) return nil;
    NSString *name = _mine[(NSUInteger)path.row];
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete"
        handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
            ASMVitrineDSPDeleteUserPreset(name);
            self->_mine = userPresetNames();
            NSIndexPath *picked = self->_picked;
            if (picked.section == 1 && picked.row == path.row) self->_picked = nil;
            else if (picked.section == 1 && picked.row > path.row) self->_picked = [NSIndexPath indexPathForRow:picked.row - 1 inSection:1];
            // The rows under it close up; the last one gives way to the placeholder instead.
            if (self->_mine.count) [self.tableView deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
            else [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
            done(YES);
        }];
    delete.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

- (void)askForName {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save preset"
        message:@"A preset of the same name is replaced." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Name";
        field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        field.keyboardAppearance = UIKeyboardAppearanceDark;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!name.length) return;
        ASMVitrineDSPSaveUserPreset(name);
        self->_mine = userPresetNames();
        self->_picked = [NSIndexPath indexPathForRow:(NSInteger)[self->_mine indexOfObject:name] inSection:1];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)] withRowAnimation:UITableViewRowAnimationFade];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMVitrineDSPPresetsPage(void) {
    return [ASMVitrineDSPPresetList new];
}

#pragma mark - headphones

// AutoEq's headphones under a search field, the one in use ticked, with None above them. A tap downloads its
// GraphicEQ and turns the Graphic EQ on with it; None turns it off again. Pulling down fetches the list again.
// Above the field, Use for <the output playing now> remembers the pick for that output (AutoEq.m), and the
// outputs remembered so far are listed with their corrections, a swipe removing one. The field sits right over
// the list it searches, and while it is in use only the list stays under it, the way Settings' search does.
@interface ASMVitrineDSPHeadphoneList : ASMVitrinePage <UISearchBarDelegate>
@end

static const CGFloat kSearchTop = 8;   // the field's gap from the card over it

typedef NS_ENUM(NSInteger, ASMVitrineDSPHeadphoneSection) {
    ASMVitrineDSPHeadphoneOutput,       // Use for <output>, while an output is known and no search is on
    ASMVitrineDSPHeadphoneRemembered,   // the remembered outputs, while there are any and no search is on
    ASMVitrineDSPHeadphoneSearch,       // no rows: the search field is its header
    ASMVitrineDSPHeadphoneNone,         // while no search is on
    ASMVitrineDSPHeadphoneMessage,      // loading, or why the list did not come
    ASMVitrineDSPHeadphoneAll,
    ASMVitrineDSPHeadphoneSections,
};

@implementation ASMVitrineDSPHeadphoneList {
    NSArray<ASMVitrineAutoEqHeadphone *> *_all, *_shown;
    NSString *_message;          // loading, or why the list did not come
    BOOL _failed;
    NSString *_applying;         // the path being downloaded
    NSArray<NSDictionary<NSString *, NSString *> *> *_remembered;
    UISearchBar *_search;
    UIView *_searchHeader, *_header, *_footer;
    BOOL _searching;             // the field in use, so only the list shows under it
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Headphones";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITableView *table = self.tableView;
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _search = [UISearchBar new];
    _search.placeholder = @"Search headphones";
    _search.searchBarStyle = UISearchBarStyleMinimal;
    _search.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _search.keyboardAppearance = UIKeyboardAppearanceDark;
    _search.delegate = self;
    // The table insets the header to the cards' width; the bar reaches past them by the room it keeps
    // around its field, so the field lines up with the cards.
    _searchHeader = [UIView new];
    _search.translatesAutoresizingMaskIntoConstraints = NO;
    [_searchHeader addSubview:_search];
    [NSLayoutConstraint activateConstraints:@[
        [_search.leadingAnchor constraintEqualToAnchor:_searchHeader.leadingAnchor constant:-8],
        [_search.trailingAnchor constraintEqualToAnchor:_searchHeader.trailingAnchor constant:8],
        [_search.topAnchor constraintEqualToAnchor:_searchHeader.topAnchor constant:kSearchTop],
        [_search.heightAnchor constraintEqualToConstant:44],
    ]];
    _header = ASMVitrineNote(@"Corrections that make your headphones sound neutral, measured by AutoEq. Picking one turns Audio effects and the Graphic EQ on with it.");
    table.tableHeaderView = _header;
    _footer = ASMVitrineNote(@"From AutoEq by Jaakko Pasanen, MIT License. Pull down to fetch the list again.");
    table.tableFooterView = _footer;
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    _remembered = ASMVitrineAutoEqRememberedOutputs();
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(outputsChanged) name:ASMVitrineAutoEqOutputsChangedNotification object:nil];
    [self load:NO];
}

// Another output connected, or a pick changed what one remembers.
- (void)outputsChanged {
    _remembered = ASMVitrineAutoEqRememberedOutputs();
    [self reload:UITableViewRowAnimationNone];
}

// Every section but the field's: reloading the header the field is in would take the keyboard away mid-word.
- (void)reload:(UITableViewRowAnimation)animation {
    NSMutableIndexSet *sections = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, ASMVitrineDSPHeadphoneSections)];
    [sections removeIndex:ASMVitrineDSPHeadphoneSearch];
    [self.tableView reloadSections:sections withRowAnimation:animation];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _header, 4, 8);
    ASMVitrineFitNote(self.tableView, _footer, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (void)refresh {
    [self load:YES];
}

- (void)load:(BOOL)refresh {
    if (!_all) _message = @"Loading AutoEq's list…";
    _failed = NO;
    // From viewDidLoad the table has not asked for its rows yet, and will.
    if (self.tableView.window) [self reload:UITableViewRowAnimationNone];
    ASMVitrineAutoEqLoadIndex(refresh, ^(NSArray<ASMVitrineAutoEqHeadphone *> *headphones, NSString *error) {
        [self.refreshControl endRefreshing];
        if (headphones) self->_all = headphones;
        self->_failed = error != nil;
        self->_message = error ? [NSString stringWithFormat:@"%@. Tap to try again.", error] : nil;
        [self filter];
    });
}

- (void)filter {
    _shown = ASMVitrineAutoEqSearch(_all ?: @[], _search.text);
    BOOL searching = _search.isFirstResponder || _search.text.length > 0;
    BOOL changed = searching != _searching;
    _searching = searching;
    // No fade: one over thousands of rows leaves the cards half drawn while the field moves up.
    [self reload:UITableViewRowAnimationNone];
    // What went from over the field could have taken it off the screen.
    if (changed && searching) {
        [self.tableView scrollRectToVisible:[self.tableView rectForHeaderInSection:ASMVitrineDSPHeadphoneSearch] animated:YES];
    }
}

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {
    [self filter];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)bar {
    [self filter];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)bar {
    [self filter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar {
    [bar resignFirstResponder];
}

// Whether a headphone's correction is what the Graphic EQ plays, rather than nothing or the user's own curve.
static BOOL headphoneInUse(void) {
    return ASMVitrineDSPSwitch(ASMVitrineKeyDSPGraphicEq) && ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone).length;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMVitrineDSPHeadphoneSections;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case ASMVitrineDSPHeadphoneMessage: return _message ? 1 : 0;
        case ASMVitrineDSPHeadphoneOutput: return ASMVitrineAutoEqOutputUID() && !_searching ? 1 : 0;
        case ASMVitrineDSPHeadphoneRemembered: return _searching ? 0 : (NSInteger)_remembered.count;
        case ASMVitrineDSPHeadphoneSearch: return 0;
        case ASMVitrineDSPHeadphoneNone: return _searching ? 0 : 1;
        default: return _all && !_shown.count && _search.text.length ? 1 : (NSInteger)_shown.count;
    }
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == ASMVitrineDSPHeadphoneSearch) return _searchHeader;
    return section == ASMVitrineDSPHeadphoneRemembered && [self tableView:table numberOfRowsInSection:section] ? ASMVitrineSectionHeader(table, @"Remembered outputs") : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if (section == ASMVitrineDSPHeadphoneSearch) return kSearchTop + 44 + 4;
    if ([self tableView:table numberOfRowsInSection:section] == 0) return CGFLOAT_MIN;
    return section == ASMVitrineDSPHeadphoneRemembered ? ASMVitrineSectionHeaderHeight() : ASMVitrineSectionGap;
}

- (NSString *)outputFooter {
    NSString *name = ASMVitrineAutoEqOutputName();
    return [NSString stringWithFormat:@"With this on, the correction you pick is kept for %@. It comes back each time audio plays through "
            "%@, and goes off on outputs with none remembered.", name, name];
}

- (UIView *)tableView:(UITableView *)table viewForFooterInSection:(NSInteger)section {
    return section == ASMVitrineDSPHeadphoneOutput && [self tableView:table numberOfRowsInSection:section] ? ASMVitrineSectionFooter(table, [self outputFooter]) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return section == ASMVitrineDSPHeadphoneOutput && [self tableView:table numberOfRowsInSection:section] ? ASMVitrineSectionFooterHeight(table, [self outputFooter]) : CGFLOAT_MIN;
}

// A remembered output's correction, by name.
static NSString *correctionName(NSString *path) {
    return path.length ? ASMVitrineAutoEqNameOf(path) : @"None";
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"headphone");
    cell.accessoryView = nil;
    if (path.section == ASMVitrineDSPHeadphoneOutput) {
        NSString *uid = ASMVitrineAutoEqOutputUID();
        BOOL remembered = ASMVitrineAutoEqOutputRemembered(uid);
        NSString *current = correctionName(headphoneInUse() ? ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone) : nil);
        ASMVitrineFillCell(cell, [NSString stringWithFormat:@"Use for %@", ASMVitrineAutoEqOutputName()],
                   remembered ? [NSString stringWithFormat:@"%@ while it plays", current] : [NSString stringWithFormat:@"Remember %@ for this output", current], nil, nil);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *toggle = [UISwitch new];
        toggle.onTintColor = ASMVitrineGreen();
        toggle.on = remembered;
        [toggle addTarget:self action:@selector(useToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.accessibilityTraits = UIAccessibilityTraitNone;
        return cell;
    }
    if (path.section == ASMVitrineDSPHeadphoneRemembered) {
        NSDictionary<NSString *, NSString *> *output = _remembered[(NSUInteger)path.row];
        BOOL now = [output[@"uid"] isEqualToString:ASMVitrineAutoEqOutputUID()];
        ASMVitrineFillCell(cell, output[@"name"], now ? [NSString stringWithFormat:@"%@ · playing now", correctionName(output[@"path"])] : correctionName(output[@"path"]), nil, nil);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessibilityTraits = UIAccessibilityTraitNone;
        cell.accessibilityHint = @"Swipe left to remove";
        return cell;
    }
    cell.accessibilityHint = nil;
    if (path.section == ASMVitrineDSPHeadphoneMessage) {
        ASMVitrineFillCell(cell, _message, nil, _failed ? ASMVitrineRed() : ASMVitrineGrey(), _failed ? @"exclamationmark.triangle.fill" : nil);
        cell.selectionStyle = _failed ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        return cell;
    }
    cell.accessibilityValue = nil;
    if (path.section == ASMVitrineDSPHeadphoneNone) {
        ASMVitrineFillCell(cell, @"None", nil, nil, nil);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        tick(cell, !headphoneInUse());
        return cell;
    }
    if (!_shown.count) {
        ASMVitrineFillCell(cell, @"No headphones match", nil, ASMVitrineGrey(), nil);
        cell.accessibilityTraits = UIAccessibilityTraitNone;
        return cell;
    }
    ASMVitrineAutoEqHeadphone *headphone = _shown[(NSUInteger)path.row];
    ASMVitrineFillCell(cell, headphone.name, headphone.source, nil, nil);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if ([headphone.path isEqualToString:_applying]) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.color = ASMVitrineGrey();
        spinner.accessibilityLabel = @"Applying";
        [spinner startAnimating];
        cell.accessoryView = spinner;
        // The cell is what VoiceOver reads, not the spinner in it.
        cell.accessibilityValue = @"Applying";
        return cell;
    }
    tick(cell, headphoneInUse() && [headphone.path isEqualToString:ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone)]);
    return cell;
}

- (BOOL)tableView:(UITableView *)table shouldHighlightRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == ASMVitrineDSPHeadphoneMessage) return _failed;
    if (path.section == ASMVitrineDSPHeadphoneOutput || path.section == ASMVitrineDSPHeadphoneRemembered) return NO;
    return (path.section == ASMVitrineDSPHeadphoneNone || _shown.count > 0) && !_applying;
}

- (void)useToggled:(UISwitch *)toggle {
    ASMVitrineAutoEqRememberOutput(toggle.on);
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)table trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != ASMVitrineDSPHeadphoneRemembered) return nil;
    NSString *uid = _remembered[(NSUInteger)path.row][@"uid"];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Remove"
        handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
            ASMVitrineAutoEqForgetOutput(uid);
            done(YES);
        }];
    remove.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMVitrineDSPHeadphoneMessage) {
        if (_failed) [self load:YES];
        return;
    }
    if (_applying || path.section == ASMVitrineDSPHeadphoneOutput || path.section == ASMVitrineDSPHeadphoneRemembered) return;
    if (path.section == ASMVitrineDSPHeadphoneNone) {
        // Only a headphone's correction is taken off: a curve of the user's own, with no headphone, stays.
        ASMVitrineAutoEqTakeOff();
        [self reload:UITableViewRowAnimationNone];
        return;
    }
    if (!_shown.count) return;
    ASMVitrineAutoEqHeadphone *headphone = _shown[(NSUInteger)path.row];
    _applying = headphone.path;
    [self reload:UITableViewRowAnimationNone];
    ASMVitrineAutoEqApply(headphone, ^(NSString *error) {
        self->_applying = nil;
        [self reload:UITableViewRowAnimationNone];
        if (error) showAlert(self, [NSString stringWithFormat:@"Could not apply %@", headphone.name], error);
    });
}

@end

UIViewController *ASMVitrineDSPHeadphonesPage(void) {
    return [ASMVitrineDSPHeadphoneList new];
}

NSString *ASMVitrineDSPHeadphoneSummary(void) {
    NSString *path = ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone);
    return path.length && ASMVitrineDSPSwitch(ASMVitrineKeyDSPGraphicEq) ? ASMVitrineAutoEqNameOf(path) : @"None";
}
