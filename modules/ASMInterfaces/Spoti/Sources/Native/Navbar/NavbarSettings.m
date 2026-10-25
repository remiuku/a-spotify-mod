#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "Navbar.h"

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph.
static NSArray<NSDictionary *> *tabPresets(void) {
    return @[
        @{ASMSpotiNavbarTitle: @"Home", ASMSpotiNavbarURI: @"spotify:home", ASMSpotiNavbarIcon: @"home"},
        @{ASMSpotiNavbarTitle: @"Search", ASMSpotiNavbarURI: @"spotify:search", ASMSpotiNavbarIcon: @"search"},
        @{ASMSpotiNavbarTitle: @"Your Library", ASMSpotiNavbarURI: @"spotify:collection", ASMSpotiNavbarIcon: @"collection"},
        @{ASMSpotiNavbarTitle: @"Liked Songs", ASMSpotiNavbarURI: @"spotify:collection:tracks", ASMSpotiNavbarIcon: @"heart"},
        @{ASMSpotiNavbarTitle: @"Playlists", ASMSpotiNavbarURI: @"spotify:playlists", ASMSpotiNavbarIcon: @"playlist"},
        @{ASMSpotiNavbarTitle: @"Albums", ASMSpotiNavbarURI: @"spotify:collection:albums", ASMSpotiNavbarIcon: @"album"},
        @{ASMSpotiNavbarTitle: @"Artists", ASMSpotiNavbarURI: @"spotify:collection:artists", ASMSpotiNavbarIcon: @"artist"},
        @{ASMSpotiNavbarTitle: @"Podcasts", ASMSpotiNavbarURI: @"spotify:collection:podcasts", ASMSpotiNavbarIcon: @"podcasts"},
        @{ASMSpotiNavbarTitle: @"Audiobooks", ASMSpotiNavbarURI: @"spotify:collection:audiobooks", ASMSpotiNavbarIcon: @"audiobook"},
        @{ASMSpotiNavbarTitle: @"Downloads", ASMSpotiNavbarURI: @"spotify:collection:downloads", ASMSpotiNavbarIcon: @"downloaded"},
        @{ASMSpotiNavbarTitle: @"Your Episodes", ASMSpotiNavbarURI: @"spotify:collection:your-episodes", ASMSpotiNavbarIcon: @"bookmark"},
        @{ASMSpotiNavbarTitle: @"Browse", ASMSpotiNavbarURI: @"spotify:browse", ASMSpotiNavbarIcon: @"browse"},
        @{ASMSpotiNavbarTitle: @"New Releases", ASMSpotiNavbarURI: @"spotify:new-releases", ASMSpotiNavbarIcon: @"star"},
        @{ASMSpotiNavbarTitle: @"Made For You", ASMSpotiNavbarURI: @"spotify:made-for-you", ASMSpotiNavbarIcon: @"user"},
        @{ASMSpotiNavbarTitle: @"Concerts", ASMSpotiNavbarURI: @"spotify:concerts", ASMSpotiNavbarIcon: @"events"},
        @{ASMSpotiNavbarTitle: @"Queue", ASMSpotiNavbarURI: @"spotify:now-playing:queue", ASMSpotiNavbarIcon: @"queue"},
        @{ASMSpotiNavbarTitle: @"Create", ASMSpotiNavbarURI: @"spotify:create-menu", ASMSpotiNavbarIcon: @"plus"},
    ];
}

// The list the Navbar page edits: the saved order first, then every tab of Spotify's it does not
// name, in Spotify's order. Entries for tabs Spotify no longer has drop out.
static NSMutableArray<NSMutableDictionary *> *navbarEntries(void) {
    NSArray<NSString *> *stock = ASMSpotiNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in ASMSpotiNavbarLayout()) {
        NSString *ident = entry[ASMSpotiNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[ASMSpotiNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{ASMSpotiNavbarID: ident, ASMSpotiNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [tab mutableCopy];
    entry[ASMSpotiNavbarID] = NSUUID.UUID.UUIDString;
    ASMSpotiSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    ASMSpotiRefreshTabBar();
}

@interface ASMSpotiTabPickerPage : ASMSpotiPage
@end

@implementation ASMSpotiTabPickerPage {
    UIView *_footer;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Add a Tab";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _footer = ASMSpotiNote(@"Paste a share link or a spotify: URI. Icons: home, search, collection, heart, "
                   "playlist, album, artist, podcasts, audiobook, downloaded, bookmark, browse, star, "
                   "user, events, queue, plus, radio, gears, spotifyLogo.");
    self.tableView.tableFooterView = _footer;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMSpotiFitNote(self.tableView, _footer, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMSpotiInsetForBars(self.tableView);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 2;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)tabPresets().count : 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return ASMSpotiSectionHeader(table, section == 0 ? @"Spotify's pages" : @"Anywhere else");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMSpotiSectionHeaderHeight;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"pick");
    if (path.section == 0) {
        NSDictionary *tab = tabPresets()[(NSUInteger)path.row];
        ASMSpotiFillCell(cell, tab[ASMSpotiNavbarTitle], tab[ASMSpotiNavbarURI], nil, nil);
    } else {
        ASMSpotiFillCell(cell, @"Any link…", nil, nil, @"link");
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        appendTab(tabPresets()[(NSUInteger)path.row]);
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Any link" message:@"Where the tab goes, and the glyph on it." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.placeholder = @"Name"; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"spotify:playlist:…";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Icon";
        field.text = @"star";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *title = alert.textFields[0].text, *uri = alert.textFields[1].text, *icon = alert.textFields[2].text;
        if (!uri.length) return;
        appendTab(@{ASMSpotiNavbarTitle: title.length ? title : uri, ASMSpotiNavbarURI: uri, ASMSpotiNavbarIcon: icon.length ? icon : @"star"});
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

typedef NS_ENUM(NSInteger, ASMSpotiNavbarSection) {
    ASMSpotiNavbarSectionSwitch,
    ASMSpotiNavbarSectionTabs,
    ASMSpotiNavbarSectionAdd,
    ASMSpotiNavbarSectionReset,
    ASMSpotiNavbarSectionCount,
};

// The tabs, in the order the bar shows them: drag to reorder, tap to show or hide, swipe a tab of
// your own away. Spotify's own tabs can only be hidden, never removed. Mod Settings and the welcome
// tour show the same editor.
@interface ASMSpotiNavbarPage : ASMSpotiPage
@end

@implementation ASMSpotiNavbarPage {
    NSMutableArray<NSMutableDictionary *> *_entries;
    UIView *_intro;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Navbar";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.editing = YES;
    _intro = ASMSpotiNote(@"Drag to reorder, tap to show or hide.");
    self.tableView.tableHeaderView = _intro;
    _entries = navbarEntries();
}

// The Add page writes straight to the layout, so the list is read again on the way back.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _entries = navbarEntries();
    [self.tableView reloadData];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMSpotiFitNote(self.tableView, _intro, 24, 0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMSpotiInsetForBars(self.tableView);
}

- (void)save {
    ASMSpotiSetNavbarLayout(_entries);
    ASMSpotiRefreshTabBar();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMSpotiNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == ASMSpotiNavbarSectionTabs ? (NSInteger)_entries.count : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == ASMSpotiNavbarSectionTabs ? @"Tabs" : nil;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    NSString *title = [self headerFor:section];
    return title ? ASMSpotiSectionHeader(table, title) : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if ([self headerFor:section]) return ASMSpotiSectionHeaderHeight;
    return [self tableView:table numberOfRowsInSection:section] ? ASMSpotiSectionGap : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"navbar");
    switch (path.section) {
        case ASMSpotiNavbarSectionSwitch: {
            ASMSpotiFillCell(cell, @"Custom navbar", nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMSpotiGreen();
            toggle.on = ASMSpotiEnabled(ASMSpotiKeyNavbar);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMSpotiNavbarSectionTabs: {
            NSDictionary *entry = _entries[(NSUInteger)path.row];
            BOOL hidden = [entry[ASMSpotiNavbarHidden] boolValue];
            NSString *uri = entry[ASMSpotiNavbarURI];
            ASMSpotiFillCell(cell, entry[ASMSpotiNavbarTitle], hidden ? @"Hidden" : (uri ?: @"Spotify's own tab"),
                     hidden ? ASMSpotiGrey() : nil, hidden ? @"eye.slash" : @"eye");
            break;
        }
        case ASMSpotiNavbarSectionAdd:
            ASMSpotiFillCell(cell, @"Add a tab…", nil, nil, @"plus");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        default:
            ASMSpotiFillCell(cell, @"Use Spotify's order", nil, nil, @"arrow.uturn.backward");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMSpotiNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMSpotiNavbarSectionTabs;
}

// Spotify's own tabs stay on the list to be switched back on; only the mod's own can go.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != ASMSpotiNavbarSectionTabs) return UITableViewCellEditingStyleNone;
    return _entries[(NSUInteger)path.row][ASMSpotiNavbarURI] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == ASMSpotiNavbarSectionTabs ? to : from;
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
    if (path.section == ASMSpotiNavbarSectionTabs) {
        NSMutableDictionary *entry = _entries[(NSUInteger)path.row];
        entry[ASMSpotiNavbarHidden] = [entry[ASMSpotiNavbarHidden] boolValue] ? nil : @YES;
        [self save];
        [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == ASMSpotiNavbarSectionAdd) {
        [self.navigationController pushViewController:[ASMSpotiTabPickerPage new] animated:YES];
    } else if (path.section == ASMSpotiNavbarSectionReset) {
        [self reset];
    }
}

- (void)toggled:(UISwitch *)toggle {
    ASMSpotiSetEnabled(ASMSpotiKeyNavbar, toggle.on);
    ASMSpotiRefreshTabBar();
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's order"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, and the tabs you added go."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMSpotiSetNavbarLayout(@[]);
        ASMSpotiRefreshTabBar();
        self->_entries = navbarEntries();
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMSpotiNavbarSettingsPage(void) {
    return [ASMSpotiNavbarPage new];
}

UIViewController *ASMSpotiNavbarEditorPage(void) {
    return [ASMSpotiNavbarPage new];
}
