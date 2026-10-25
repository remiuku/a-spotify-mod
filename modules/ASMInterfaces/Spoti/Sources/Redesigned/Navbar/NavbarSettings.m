#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "Navbar.h"
#import "Shared/Navigation/Links.h"

// What "Add a tab" offers: URIs Spotify's own router resolves to a page of its own, each with the
// name of the SPTEncoreIcon class method that draws its glyph. Playlists was spotify:collection:playlists
// until 0.20, which 9.1.78 knows only from its old iPad sidebar table and has no handler for (#66);
// spotify:playlists is the form its collection URI parser lists, next to spotify:playlists:by-you.
// The picker still asks the dispatcher about each one and leaves out what it has nowhere to send.
static NSArray<NSDictionary *> *tabPresets(void) {
    return @[
        @{ASMSpotiRNavbarTitle: @"Home", ASMSpotiRNavbarURI: @"spotify:home", ASMSpotiRNavbarIcon: @"home"},
        @{ASMSpotiRNavbarTitle: @"Search", ASMSpotiRNavbarURI: @"spotify:search", ASMSpotiRNavbarIcon: @"search"},
        @{ASMSpotiRNavbarTitle: @"Your Library", ASMSpotiRNavbarURI: @"spotify:collection", ASMSpotiRNavbarIcon: @"collection"},
        @{ASMSpotiRNavbarTitle: @"Liked Songs", ASMSpotiRNavbarURI: @"spotify:collection:tracks", ASMSpotiRNavbarIcon: @"heart"},
        @{ASMSpotiRNavbarTitle: @"Playlists", ASMSpotiRNavbarURI: @"spotify:playlists", ASMSpotiRNavbarIcon: @"playlist"},
        @{ASMSpotiRNavbarTitle: @"Albums", ASMSpotiRNavbarURI: @"spotify:collection:albums", ASMSpotiRNavbarIcon: @"album"},
        @{ASMSpotiRNavbarTitle: @"Artists", ASMSpotiRNavbarURI: @"spotify:collection:artists", ASMSpotiRNavbarIcon: @"artist"},
        @{ASMSpotiRNavbarTitle: @"Podcasts", ASMSpotiRNavbarURI: @"spotify:collection:podcasts", ASMSpotiRNavbarIcon: @"podcasts"},
        @{ASMSpotiRNavbarTitle: @"Audiobooks", ASMSpotiRNavbarURI: @"spotify:collection:audiobooks", ASMSpotiRNavbarIcon: @"audiobook"},
        @{ASMSpotiRNavbarTitle: @"Downloads", ASMSpotiRNavbarURI: @"spotify:collection:downloads", ASMSpotiRNavbarIcon: @"downloaded"},
        @{ASMSpotiRNavbarTitle: @"Your Episodes", ASMSpotiRNavbarURI: @"spotify:collection:your-episodes", ASMSpotiRNavbarIcon: @"bookmark"},
        @{ASMSpotiRNavbarTitle: @"Browse", ASMSpotiRNavbarURI: @"spotify:browse", ASMSpotiRNavbarIcon: @"browse"},
        @{ASMSpotiRNavbarTitle: @"New Releases", ASMSpotiRNavbarURI: @"spotify:new-releases", ASMSpotiRNavbarIcon: @"star"},
        @{ASMSpotiRNavbarTitle: @"Made For You", ASMSpotiRNavbarURI: @"spotify:made-for-you", ASMSpotiRNavbarIcon: @"user"},
        @{ASMSpotiRNavbarTitle: @"Concerts", ASMSpotiRNavbarURI: @"spotify:concerts", ASMSpotiRNavbarIcon: @"events"},
        @{ASMSpotiRNavbarTitle: @"Queue", ASMSpotiRNavbarURI: @"spotify:now-playing:queue", ASMSpotiRNavbarIcon: @"queue"},
        @{ASMSpotiRNavbarTitle: @"Create", ASMSpotiRNavbarURI: @"spotify:create-menu", ASMSpotiRNavbarIcon: @"plus"},
    ];
}

// The list the Navbar page edits: the saved order first, then every tab of Spotify's it does not
// name, in Spotify's order. Entries for tabs Spotify no longer has drop out.
static NSMutableArray<NSMutableDictionary *> *navbarEntries(void) {
    NSArray<NSString *> *stock = ASMSpotiRNavbarStock();
    NSMutableArray<NSMutableDictionary *> *entries = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSDictionary *entry in ASMSpotiRNavbarLayout()) {
        NSString *ident = entry[ASMSpotiRNavbarID];
        if (![ident isKindOfClass:NSString.class] || [seen containsObject:ident]) continue;
        if (!entry[ASMSpotiRNavbarURI] && ![stock containsObject:ident]) continue;
        [seen addObject:ident];
        [entries addObject:[entry mutableCopy]];
    }
    for (NSString *ident in stock) {
        if ([seen containsObject:ident]) continue;
        [entries addObject:[@{ASMSpotiRNavbarID: ident, ASMSpotiRNavbarTitle: ident} mutableCopy]];
    }
    return entries;
}

// A tab of the mod's own carries an identity of its own, so the same page can sit on the bar twice
// and renaming one does not shuffle the order.
static void appendTab(NSDictionary *tab) {
    NSMutableDictionary *entry = [tab mutableCopy];
    entry[ASMSpotiRNavbarID] = NSUUID.UUID.UUIDString;
    ASMSpotiRSetNavbarLayout([navbarEntries() arrayByAddingObject:entry]);
    ASMSpotiRRefreshTabBar();
}

@interface ASMSpotiRTabPickerPage : ASMSpotiPage
@end

// The presets the dispatcher can send somewhere, each verdict logged. When it cannot be asked (not set
// up yet, or 9.1.78's registry is not where it was) every preset stays, as before.
static NSArray<NSDictionary *> *openablePresets(void) {
    NSMutableArray<NSDictionary *> *kept = [NSMutableArray array];
    for (NSDictionary *tab in tabPresets()) {
        NSString *via = nil;
        ASMSpotiLinkRoute route = ASMSpotiSpotifyURIRoute([NSURL URLWithString:tab[ASMSpotiRNavbarURI]], &via);
        ASMSpotiLog(@"navbar: preset %@ -> %@", tab[ASMSpotiRNavbarURI],
              route == ASMSpotiLinkRouteOpens ? via : route == ASMSpotiLinkRouteNone ? @"no handler, left out" : @"unknown");
        if (route != ASMSpotiLinkRouteNone) [kept addObject:tab];
    }
    return kept;
}

@implementation ASMSpotiRTabPickerPage {
    UIView *_footer;
    NSArray<NSDictionary *> *_presets;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Add a Tab";
    _presets = openablePresets();
    return self;
}

// Said here rather than by Spotify's alert on the bar later, every time the tab is tapped.
- (void)refuse:(NSString *)uri {
    NSString *message = [NSString stringWithFormat:@"Spotify has nowhere to open %@, so it would not work as a tab.", uri];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't open that link" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    return section == 0 ? (NSInteger)_presets.count : 1;
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
        NSDictionary *tab = _presets[(NSUInteger)path.row];
        ASMSpotiFillCell(cell, tab[ASMSpotiRNavbarTitle], tab[ASMSpotiRNavbarURI], nil, nil);
    } else {
        ASMSpotiFillCell(cell, @"Any link…", nil, nil, @"link");
    }
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == 0) {
        appendTab(_presets[(NSUInteger)path.row]);
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
        NSString *title = alert.textFields[0].text, *icon = alert.textFields[2].text;
        NSString *uri = ASMSpotiSpotifyURIFromText(alert.textFields[1].text).absoluteString;
        if (!uri.length) return;
        NSString *via = nil;
        ASMSpotiLinkRoute route = ASMSpotiSpotifyURIRoute([NSURL URLWithString:uri], &via);
        ASMSpotiLog(@"navbar: custom %@ -> %@", uri, route == ASMSpotiLinkRouteOpens ? via : route == ASMSpotiLinkRouteNone ? @"no handler" : @"unknown");
        if (route == ASMSpotiLinkRouteNone) {
            [self refuse:uri];
            return;
        }
        appendTab(@{ASMSpotiRNavbarTitle: title.length ? title : uri, ASMSpotiRNavbarURI: uri, ASMSpotiRNavbarIcon: icon.length ? icon : @"star"});
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

typedef NS_ENUM(NSInteger, ASMSpotiRNavbarSection) {
    ASMSpotiRNavbarSectionSwitch,
    ASMSpotiRNavbarSectionTabs,
    ASMSpotiRNavbarSectionAdd,
    ASMSpotiRNavbarSectionReset,
    ASMSpotiRNavbarSectionCount,
};

// The tabs, in the order the bar shows them: drag to reorder, tap to show or hide, swipe a tab of
// your own away. Spotify's own tabs can only be hidden, never removed. Mod Settings and the welcome
// tour show the same editor.
@interface ASMSpotiRNavbarPage : ASMSpotiPage
@end

@implementation ASMSpotiRNavbarPage {
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
    ASMSpotiRSetNavbarLayout(_entries);
    ASMSpotiRRefreshTabBar();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMSpotiRNavbarSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == ASMSpotiRNavbarSectionSwitch) return 2;
    return section == ASMSpotiRNavbarSectionTabs ? (NSInteger)_entries.count : 1;
}

- (NSString *)headerFor:(NSInteger)section {
    return section == ASMSpotiRNavbarSectionTabs ? @"Tabs" : nil;
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
        case ASMSpotiRNavbarSectionSwitch: {
            BOOL labels = path.row == 1;
            ASMSpotiFillCell(cell, labels ? @"Hide labels" : @"Custom navbar", labels ? @"Icons only" : nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMSpotiGreen();
            toggle.tag = path.row;
            toggle.on = labels ? ASMSpotiHidden(ASMSpotiRKeyNavbarHideLabels) : ASMSpotiEnabled(ASMSpotiRKeyNavbar);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMSpotiRNavbarSectionTabs: {
            NSDictionary *entry = _entries[(NSUInteger)path.row];
            BOOL hidden = [entry[ASMSpotiRNavbarHidden] boolValue];
            NSString *uri = entry[ASMSpotiRNavbarURI];
            ASMSpotiFillCell(cell, entry[ASMSpotiRNavbarTitle], hidden ? @"Hidden" : (uri ?: @"Spotify's own tab"),
                     hidden ? ASMSpotiGrey() : nil, hidden ? @"eye.slash" : @"eye");
            break;
        }
        case ASMSpotiRNavbarSectionAdd:
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
    return path.section == ASMSpotiRNavbarSectionTabs;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMSpotiRNavbarSectionTabs;
}

// Spotify's own tabs stay on the list to be switched back on; only the mod's own can go.
- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != ASMSpotiRNavbarSectionTabs) return UITableViewCellEditingStyleNone;
    return _entries[(NSUInteger)path.row][ASMSpotiRNavbarURI] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == ASMSpotiRNavbarSectionTabs ? to : from;
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
    if (path.section == ASMSpotiRNavbarSectionTabs) {
        NSMutableDictionary *entry = _entries[(NSUInteger)path.row];
        entry[ASMSpotiRNavbarHidden] = [entry[ASMSpotiRNavbarHidden] boolValue] ? nil : @YES;
        [self save];
        [table reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
    } else if (path.section == ASMSpotiRNavbarSectionAdd) {
        [self.navigationController pushViewController:[ASMSpotiRTabPickerPage new] animated:YES];
    } else if (path.section == ASMSpotiRNavbarSectionReset) {
        [self reset];
    }
}

- (void)toggled:(UISwitch *)toggle {
    ASMSpotiSetEnabled(toggle.tag == 1 ? ASMSpotiRKeyNavbarHideLabels : ASMSpotiRKeyNavbar, toggle.on);
    ASMSpotiRRefreshTabBar();
}

- (void)reset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Use Spotify's order"
                                                                  message:@"Every tab of Spotify's comes back where Spotify put it, and the tabs you added go."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMSpotiRSetNavbarLayout(@[]);
        ASMSpotiRRefreshTabBar();
        self->_entries = navbarEntries();
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *ASMSpotiRNavbarSettingsPage(void) {
    return [ASMSpotiRNavbarPage new];
}

UIViewController *ASMSpotiRNavbarEditorPage(void) {
    return [ASMSpotiRNavbarPage new];
}
