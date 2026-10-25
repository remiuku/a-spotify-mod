// Drag sources into the order they are asked; the ones below the line are off.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "LyricsSources.h"

typedef NS_ENUM(NSInteger, ASMSpotiSourcesSection) {
    ASMSpotiSourcesSectionOn = 0,
    ASMSpotiSourcesSectionOff,
    ASMSpotiSourcesSectionCount,
};

@interface ASMSpotiSourcesPage : ASMSpotiPage
@end

@implementation ASMSpotiSourcesPage {
    NSMutableArray<NSString *> *_on;    // keys, in the order they are asked
    NSMutableArray<NSString *> *_off;
    UIView *_footer;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Lyrics sources";
    return self;
}

- (void)read {
    _on = [ASMSpotiLyricsOrder() mutableCopy];
    _off = [NSMutableArray array];
    for (ASMSpotiLyricsProvider *provider in ASMSpotiLyricsAllProviders()) {
        if (![_on containsObject:provider.key]) [_off addObject:provider.key];
    }
}

- (void)save {
    ASMSpotiLyricsSetOrder(_on);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self read];
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    _footer = ASMSpotiNote(@"Asked top to bottom until one has word timing. Spicy Lyrics is sent your Spotify "
                      "access token; the others get only the track, never your account.");
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

- (NSMutableArray<NSString *> *)keysIn:(NSInteger)section {
    return section == ASMSpotiSourcesSectionOn ? _on : _off;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMSpotiSourcesSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self keysIn:section].count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == ASMSpotiSourcesSectionOn) return ASMSpotiSectionHeader(table, _on.count ? @"Asked in this order" : @"None on");
    return _off.count ? ASMSpotiSectionHeader(table, @"Off") : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == ASMSpotiSourcesSectionOn || _off.count ? ASMSpotiSectionHeaderHeight : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"source");
    ASMSpotiLyricsProvider *provider = ASMSpotiLyricsProviderFor([self keysIn:path.section][(NSUInteger)path.row]);
    BOOL on = path.section == ASMSpotiSourcesSectionOn;
    // The asked ones are numbered, so the order reads as an order rather than a list.
    NSString *title = on ? [NSString stringWithFormat:@"%ld. %@", (long)path.row + 1, provider.name] : provider.name;
    ASMSpotiFillCell(cell, title, provider.detail, on ? nil : ASMSpotiGrey(), on ? @"checkmark.circle.fill" : @"circle");
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMSpotiSourcesSectionOn;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)table shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path {
    return NO;
}

// Dragging stays inside the order; a source is switched on and off by tapping it, not by dropping
// it into the other section, so an order is never lost to a stray drag.
- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == ASMSpotiSourcesSectionOn ? to : from;
}

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSString *key = _on[(NSUInteger)from.row];
    [_on removeObjectAtIndex:(NSUInteger)from.row];
    [_on insertObject:key atIndex:(NSUInteger)to.row];
    [self save];
    [table reloadData];   // the numbers in front of the names have all moved
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSString *key = [self keysIn:path.section][(NSUInteger)path.row];
    if (path.section == ASMSpotiSourcesSectionOn) {
        [_on removeObject:key];
        // Back to where it sits among the sources that are off, in the order they all come in.
        NSUInteger at = 0;
        for (ASMSpotiLyricsProvider *provider in ASMSpotiLyricsAllProviders()) {
            if ([provider.key isEqualToString:key]) break;
            if ([_off containsObject:provider.key]) at++;
        }
        [_off insertObject:key atIndex:at];
    } else {
        [_off removeObject:key];
        [_on addObject:key];
    }
    [self save];
    [table reloadData];
}

@end

UIViewController *ASMSpotiLyricsSourcesPage(void) {
    return [ASMSpotiSourcesPage new];
}
