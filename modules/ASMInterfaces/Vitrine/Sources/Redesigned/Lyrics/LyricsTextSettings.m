// Drag the three texts of a line into size order, largest first.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "LyricsText.h"

@interface ASMVitrineRLyricsTextPage : ASMVitrinePage
@end

@implementation ASMVitrineRLyricsTextPage {
    NSMutableArray<NSNumber *> *_order;
    UIView *_footer;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Text sizes";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _order = [ASMVitrineRLyricsTextOrder() mutableCopy];
    self.tableView.editing = YES;
    _footer = ASMVitrineNote(@"Pronunciation and translation are turned on from the button in the lyrics' corner.");
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

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_order.count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeader(table, @"Largest first");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return ASMVitrineSectionHeaderHeight();
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"text");
    ASMVitrineRLyricsText text = _order[(NSUInteger)path.row].integerValue;
    NSArray<NSString *> *sizes = @[@"Largest", @"Smaller", @"Smallest"];
    NSString *symbol = text == ASMVitrineRLyricsTextLyrics ? @"music.mic" : text == ASMVitrineRLyricsTextPronunciation ? @"character.phonetic" : @"character.bubble";
    ASMVitrineFillCell(cell, ASMVitrineRLyricsTextName(text), sizes[MIN((NSUInteger)path.row, sizes.count - 1)], nil, symbol);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return YES;
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

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSNumber *text = _order[(NSUInteger)from.row];
    [_order removeObjectAtIndex:(NSUInteger)from.row];
    [_order insertObject:text atIndex:(NSUInteger)to.row];
    ASMVitrineRSetLyricsTextOrder(_order);
    [table reloadData];   // the sizes under the names have all moved
}

@end

ASMVitrineModRow *ASMVitrineRLyricsTextSizesRow(void) {
    return ASMVitrinePageRow(@"Text sizes", ^UIViewController *{ return [ASMVitrineRLyricsTextPage new]; });
}
