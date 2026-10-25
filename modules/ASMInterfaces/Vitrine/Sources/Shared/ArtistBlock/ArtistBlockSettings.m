// The Blocked artists page: the switch, whether a featured credit counts, blocking someone off the
// track playing now, and the list, swiped to unblock. The hook reads all of it per track, so a change
// needs no restart.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "ArtistBlock.h"

typedef NS_ENUM(NSInteger, ASMVitrineArtistSection) {
    ASMVitrineArtistSectionSwitch,
    ASMVitrineArtistSectionMode,
    ASMVitrineArtistSectionAdd,
    ASMVitrineArtistSectionList,
    ASMVitrineArtistSectionCount,
};

@interface ASMVitrineArtistBlockPage : ASMVitrinePage
@end

@implementation ASMVitrineArtistBlockPage {
    NSArray<NSDictionary *> *_blocked;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Blocked Artists";
    _blocked = ASMVitrineBlockedArtists();
    return self;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    ASMVitrineInsetForBars(self.tableView);
}

- (void)reload {
    _blocked = ASMVitrineBlockedArtists();
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return ASMVitrineArtistSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == ASMVitrineArtistSectionMode) return 2;
    if (section == ASMVitrineArtistSectionList) return MAX((NSInteger)_blocked.count, 1);
    return 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == ASMVitrineArtistSectionMode) return ASMVitrineSectionHeader(table, @"Skip when the artist is");
    if (section == ASMVitrineArtistSectionList) return ASMVitrineSectionHeader(table, @"Blocked");
    return nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == ASMVitrineArtistSectionMode || section == ASMVitrineArtistSectionList ? ASMVitrineSectionHeaderHeight() : ASMVitrineSectionGap;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"artist");
    switch (path.section) {
        case ASMVitrineArtistSectionSwitch: {
            ASMVitrineFillCell(cell, @"Skip blocked artists", nil, nil, nil);
            UISwitch *toggle = [UISwitch new];
            toggle.onTintColor = ASMVitrineGreen();
            toggle.on = ASMVitrineFlag(ASMVitrineKeyArtistBlock, NO);
            [toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ASMVitrineArtistSectionMode: {
            BOOL featured = path.row == 1;
            ASMVitrineFillCell(cell, featured ? @"Main or featured" : @"The main artist",
                       featured ? @"Any credit on the track" : @"The first name on the track", nil, nil);
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            if (featured == ASMVitrineFlag(ASMVitrineKeyArtistBlockFeatured, NO)) {
                UIImageView *tick = ASMVitrineSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
                tick.tintColor = ASMVitrineGreen();
                cell.accessoryView = tick;
            }
            break;
        }
        case ASMVitrineArtistSectionAdd:
            ASMVitrineFillCell(cell, @"Block from what's playing…", nil, nil, @"person.crop.circle.badge.xmark");
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        default:
            if (!_blocked.count) {
                ASMVitrineFillCell(cell, @"No one yet", nil, ASMVitrineGrey(), nil);
                break;
            }
            NSDictionary *artist = _blocked[(NSUInteger)path.row];
            ASMVitrineFillCell(cell, artist[ASMVitrineArtistName], artist[ASMVitrineArtistURI], nil, nil);
            break;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return path.section == ASMVitrineArtistSectionList && _blocked.count > 0;
}

- (NSString *)tableView:(UITableView *)table titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)path {
    return @"Unblock";
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if (style != UITableViewCellEditingStyleDelete) return;
    ASMVitrineUnblockArtist(_blocked[(NSUInteger)path.row][ASMVitrineArtistURI]);
    [self reload];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMVitrineArtistSectionMode) {
        ASMVitrineSetEnabled(ASMVitrineKeyArtistBlockFeatured, path.row == 1);
        [self reload];
    } else if (path.section == ASMVitrineArtistSectionAdd) {
        [self pickFromPlaying:[table cellForRowAtIndexPath:path]];
    }
}

- (void)pickFromPlaying:(UIView *)source {
    NSArray<NSDictionary *> *artists = ASMVitrinePlayingArtists();
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
        BOOL blocked = ASMVitrineArtistBlocked(artist[ASMVitrineArtistURI]);
        NSString *title = index == 0 ? artist[ASMVitrineArtistName] : [NSString stringWithFormat:@"%@ (featured)", artist[ASMVitrineArtistName]];
        UIAlertAction *action = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            ASMVitrineBlockArtist(artist);
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
    ASMVitrineSetEnabled(ASMVitrineKeyArtistBlock, toggle.on);
}

@end

UIViewController *ASMVitrineArtistBlockSettingsPage(void) {
    return [ASMVitrineArtistBlockPage new];
}
