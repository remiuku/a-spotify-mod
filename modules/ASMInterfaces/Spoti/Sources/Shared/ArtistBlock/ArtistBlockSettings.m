// The Blocked artists page: the switch, whether a featured credit counts, blocking someone off the
// track playing now, and the list, swiped to unblock. The hook reads all of it per track, so a change
// needs no restart.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "ArtistBlock.h"

typedef NS_ENUM(NSInteger, ASMSpotiArtistSection) {
    ASMSpotiArtistSectionSwitch,
    ASMSpotiArtistSectionMode,
    ASMSpotiArtistSectionAdd,
    ASMSpotiArtistSectionList,
    ASMSpotiArtistSectionCount,
};

@interface ASMSpotiArtistBlockPage : ASMSpotiPage
@end

@implementation ASMSpotiArtistBlockPage {
    NSArray<NSDictionary *> *_blocked;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Blocked Artists";
    _blocked = ASMSpotiBlockedArtists();
    return self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMSpotiInsetForBars(self.tableView);
}

- (void)reload {
    _blocked = ASMSpotiBlockedArtists();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMSpotiArtistSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == ASMSpotiArtistSectionMode) return 2;
    if (section == ASMSpotiArtistSectionList) return MAX((NSInteger)_blocked.count, 1);
    return 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == ASMSpotiArtistSectionMode) return ASMSpotiSectionHeader(table, @"Skip when the artist is");
    if (section == ASMSpotiArtistSectionList) return ASMSpotiSectionHeader(table, @"Blocked");
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == ASMSpotiArtistSectionMode || section == ASMSpotiArtistSectionList ? ASMSpotiSectionHeaderHeight : ASMSpotiSectionGap;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMSpotiDequeueCell(table, @"artist");
    switch (path.section) {
        case ASMSpotiArtistSectionSwitch: {
            ASMSpotiFillCell(cell, @"Skip blocked artists", nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMSpotiGreen();
            toggle.on = ASMSpotiFlag(ASMSpotiKeyArtistBlock, NO);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMSpotiArtistSectionMode: {
            BOOL featured = path.row == 1;
            ASMSpotiFillCell(cell, featured ? @"Main or featured" : @"The main artist",
                       featured ? @"Any credit on the track" : @"The first name on the track", nil, nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            if (featured == ASMSpotiFlag(ASMSpotiKeyArtistBlockFeatured, NO)) {
                UIImageView *tick = ASMSpotiSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
                tick.tintColor = ASMSpotiGreen();
                cell.accessoryView = tick;
            }
            break;
        }
        case ASMSpotiArtistSectionAdd:
            ASMSpotiFillCell(cell, @"Block from what's playing…", nil, nil, @"person.crop.circle.badge.xmark");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        default:
            if (!_blocked.count) {
                ASMSpotiFillCell(cell, @"No one yet", nil, ASMSpotiGrey(), nil);
                break;
            }
            NSDictionary *artist = _blocked[(NSUInteger)path.row];
            ASMSpotiFillCell(cell, artist[ASMSpotiArtistName], artist[ASMSpotiArtistURI], nil, nil);
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMSpotiArtistSectionList && _blocked.count > 0;
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Unblock";
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    ASMSpotiUnblockArtist(_blocked[(NSUInteger)path.row][ASMSpotiArtistURI]);
    [self reload];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMSpotiArtistSectionMode) {
        ASMSpotiSetEnabled(ASMSpotiKeyArtistBlockFeatured, path.row == 1);
        [self reload];
    } else if (path.section == ASMSpotiArtistSectionAdd) {
        [self pickFromPlaying:[table cellForRowAtIndexPath:path]];
    }
}

- (void)pickFromPlaying:(UIView *)source {
    NSArray<NSDictionary *> *artists = ASMSpotiPlayingArtists();
    if (!artists.count) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Nothing playing"
                                                                      message:@"Play a track by the artist first, then come back here."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Block"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [artists enumerateObjectsUsingBlock:^(NSDictionary *artist, NSUInteger index, BOOL *stop) {
        BOOL blocked = ASMSpotiArtistBlocked(artist[ASMSpotiArtistURI]);
        NSString *title = index == 0 ? artist[ASMSpotiArtistName] : [NSString stringWithFormat:@"%@ (featured)", artist[ASMSpotiArtistName]];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            ASMSpotiBlockArtist(artist);
            [self reload];
        }];
        action.enabled = !blocked;
        [sheet addAction:action];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = source;
    sheet.popoverPresentationController.sourceRect = source.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)toggled:(UISwitch *)toggle {
    ASMSpotiSetEnabled(ASMSpotiKeyArtistBlock, toggle.on);
}

@end

UIViewController *ASMSpotiArtistBlockSettingsPage(void) {
    return [ASMSpotiArtistBlockPage new];
}
