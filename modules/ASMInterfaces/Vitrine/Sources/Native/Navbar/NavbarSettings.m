#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Navbar.h"
#import "Shared/Navigation/AddTabSheet.h"

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph.
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
    NSArray<NSString *> *stock = ASMVitrineNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in ASMVitrineNavbarLayout()) {
        NSString *ident = entry[ASMVitrineNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[ASMVitrineNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{ASMVitrineNavbarID: ident, ASMVitrineNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [@{ASMVitrineNavbarID: NSUUID.UUID.UUIDString, ASMVitrineNavbarTitle: tab[ASMVitrineTabTitle],
                                    ASMVitrineNavbarURI: tab[ASMVitrineTabURI], ASMVitrineNavbarIcon: tab[ASMVitrineTabIcon]} mutableCopy];
    entry[ASMVitrineNavbarIconSet] = tab[ASMVitrineTabIconSet];
    ASMVitrineSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    ASMVitrineRefreshTabBar();
}

// Split tabs: a switch per tab of the bar, on to set it apart at the trailing end.
@interface ASMVitrineSplitTabsPage : ASMVitrinePage
@end

@implementation ASMVitrineSplitTabsPage {
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
    _split = [NSMutableSet setWithArray:ASMVitrineNavbarSplit()];
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
    BOOL apart = [_split containsObject:entry[ASMVitrineNavbarID]];
    NSString *where = [entry[ASMVitrineNavbarHidden] boolValue] ? @"Hidden" : apart ? @"Apart, on the right" : @"With the others";
    ASMVitrineFillCell(cell, entry[ASMVitrineNavbarTitle], where, nil, nil);
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = ASMVitrineGreen();
    toggle.on = apart;
    toggle.tag = path.row;
    [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)toggled:(UISwitch *)toggle {
    NSString *ident = _entries[(NSUInteger)toggle.tag][ASMVitrineNavbarID];
    if (toggle.on) [_split addObject:ident];
    else [_split removeObject:ident];
    ASMVitrineSetNavbarSplit(_split.allObjects);
    ASMVitrineRefreshTabBar();
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:toggle.tag inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

@end

typedef NS_ENUM(NSInteger, ASMVitrineNavbarSection) {
    ASMVitrineNavbarSectionSwitch,
    ASMVitrineNavbarSectionTabs,
    ASMVitrineNavbarSectionAdd,
    ASMVitrineNavbarSectionSplit,
    ASMVitrineNavbarSectionReset,
    ASMVitrineNavbarSectionCount,
};

// The tabs, in the order the bar shows them: drag to reorder, tap to show or hide, swipe a tab of
// your own away. Spotify's own tabs can only be hidden, never removed. Mod Settings and the welcome
// tour show the same editor.
@interface ASMVitrineNavbarPage : ASMVitrinePage
@end

@implementation ASMVitrineNavbarPage {
    NSMutableArray<NSMutableDictionary *> *_entries;
    UIView *_intro;
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
    _intro = ASMVitrineNote(@"Drag to reorder, tap to show or hide.");
    self.tableView.tableHeaderView = _intro;
    _entries = navbarEntries();
}

- (void)reload {
    _entries = navbarEntries();
    [self.tableView reloadData];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _intro, 24, 0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (void)save {
    ASMVitrineSetNavbarLayout(_entries);
    // A split tab swiped away leaves the split list with it.
    NSArray *idents = [_entries valueForKey:ASMVitrineNavbarID];
    ASMVitrineSetNavbarSplit([ASMVitrineNavbarSplit() filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", idents]]);
    ASMVitrineRefreshTabBar();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMVitrineNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == ASMVitrineNavbarSectionTabs ? (NSInteger)_entries.count : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == ASMVitrineNavbarSectionTabs ? @"Tabs" : nil;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self headerFor:section];
    return title ? ASMVitrineSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if ([self headerFor:section]) return ASMVitrineSectionHeaderHeight();
    return [self tableView:table numberOfRowsInSection:section] ? ASMVitrineSectionGap : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"navbar");
    switch (path.section) {
        case ASMVitrineNavbarSectionSwitch: {
            ASMVitrineFillCell(cell, @"Custom navbar", nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMVitrineGreen();
            toggle.on = ASMVitrineEnabled(ASMVitrineKeyNavbar);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMVitrineNavbarSectionTabs: {
            NSDictionary *entry = _entries[(NSUInteger)path.row];
            BOOL hidden = [entry[ASMVitrineNavbarHidden] boolValue];
            NSString *uri = entry[ASMVitrineNavbarURI];
            ASMVitrineFillCell(cell, entry[ASMVitrineNavbarTitle], hidden ? @"Hidden" : (uri ?: @"Spotify's own tab"),
                     hidden ? ASMVitrineGrey() : nil, hidden ? @"eye.slash" : @"eye");
            break;
        }
        case ASMVitrineNavbarSectionAdd:
            ASMVitrineFillCell(cell, @"Add a tab…", nil, nil, @"plus");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        case ASMVitrineNavbarSectionSplit:
            ASMVitrineFillCell(cell, @"Split tabs", @"Place chosen tabs apart on the right", nil, @"rectangle.split.2x1");
            cell.accessoryView = ASMVitrineSymbolView(@"chevron.right", 13, UIImageSymbolWeightSemibold, 16);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        default:
            ASMVitrineFillCell(cell, @"Use Spotify's order", nil, nil, @"arrow.uturn.backward");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineNavbarSectionTabs;
}

// Spotify's own tabs stay on the list to be switched back on; only the mod's own can go.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != ASMVitrineNavbarSectionTabs) return UITableViewCellEditingStyleNone;
    return _entries[(NSUInteger)path.row][ASMVitrineNavbarURI] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == ASMVitrineNavbarSectionTabs ? to : from;
}

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSMutableDictionary *entry = _entries[(NSUInteger)from.row];
    [_entries removeObjectAtIndex:(NSUInteger)from.row];
    [_entries insertObject:entry atIndex:(NSUInteger)to.row];
    [self save];
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    [_entries removeObjectAtIndex:(NSUInteger)path.row];
    [self save];
    [table deleteRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMVitrineNavbarSectionTabs) {
        NSMutableDictionary *entry = _entries[(NSUInteger)path.row];
        entry[ASMVitrineNavbarHidden] = [entry[ASMVitrineNavbarHidden] boolValue] ? nil : @YES;
        [self save];
        [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == ASMVitrineNavbarSectionAdd) {
        __weak typeof(self) weakSelf = self;
        ASMVitrinePresentAddTabSheet(self, tabPresets(), ^(NSDictionary *tab) {
            appendTab(tab);
            [weakSelf reload];
        });
    } else if (path.section == ASMVitrineNavbarSectionSplit) {
        [self.navigationController pushViewController:[ASMVitrineSplitTabsPage new] animated:YES];
    } else if (path.section == ASMVitrineNavbarSectionReset) {
        [self reset];
    }
}

- (void)toggled:(UISwitch *)toggle {
    ASMVitrineSetEnabled(ASMVitrineKeyNavbar, toggle.on);
    ASMVitrineRefreshTabBar();
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's order"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, the tabs you added go, and no tab is split apart."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMVitrineSetNavbarLayout(@[]);
        ASMVitrineSetNavbarSplit(@[]);
        ASMVitrineRefreshTabBar();
        self->_entries = navbarEntries();
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMVitrineNavbarSettingsPage(void) {
    return [ASMVitrineNavbarPage new];
}

UIViewController *ASMVitrineNavbarEditorPage(void) {
    return [ASMVitrineNavbarPage new];
}
