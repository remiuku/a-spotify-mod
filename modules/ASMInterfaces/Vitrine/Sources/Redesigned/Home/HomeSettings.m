// The redesign's Home page of Mod Settings: Top picks and where its cards come from, what stays on Home, and
// one switch per shelf Home has shown lately (HomeShelves.m). Every switch is read as Home lays out, so a
// change needs a restart (ASMVitrineRestartNote).
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Home.h"

static NSString *const kFirstShelf = @"First shelf";

UIViewController *ASMVitrineRHomeSettingsPage(void) {
    NSArray<NSString *> *shelves = ASMVitrineRHomeShelvesSeen();
    NSArray<NSString *> *sources = [@[kFirstShelf] arrayByAddingObjectsFromArray:shelves];
    ASMVitrineModRow *from = ASMVitrineMenuRow(@"Cards from", sources, ^NSString *{ return ASMVitrineRHomeTopPicksFrom() ?: kFirstShelf; }, ^(NSInteger index) {
        if (index == 0) [NSUserDefaults.standardUserDefaults removeObjectForKey:ASMVitrineRKeyHomeTopPicksFrom];
        else [NSUserDefaults.standardUserDefaults setObject:sources[(NSUInteger)index] forKey:ASMVitrineRKeyHomeTopPicksFrom];
    });
    ASMVitrineModRow *look = ASMVitrineSwitchRow(@"Home look", @"Top picks, the tinted shortcut pills and the title's glass pill; off, Home as the redesign had it", ASMVitrineRKeyHomeLook);
    ASMVitrineModRow *topPicks = ASMVitrineRHomeTopPicksRow();
    topPicks.waitsOn = ASMVitrineRKeyHomeLook;
    from.waitsOn = ASMVitrineRKeyHomeTopPicks;
    ASMVitrineModRow *colour = ASMVitrineSwitchRow(@"Color behind Top picks", nil, ASMVitrineRKeyHomeTopPicksColour);
    colour.waitsOn = ASMVitrineRKeyHomeTopPicks;

    NSMutableArray<ASMVitrineModRow *> *rows = [NSMutableArray array];
    for (NSString *identity in shelves) [rows addObject:ASMVitrineShownRow(identity, nil, ASMVitrineRHomeShelfHideKey(identity))];
    if (!rows.count) [rows addObject:ASMVitrineStatRow(@"None seen yet", ^NSString *{ return @""; })];

    return [[ASMVitrineModPage alloc] initWithTitle:@"Home" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineNotedSection(nil, @[look, topPicks, from, colour],
                       @"A shelf Home does not show today leaves Top picks off until it is back."),
        ASMVitrineSection(@"On Home", @[
            ASMVitrineShownRow(@"Shortcuts", nil, ASMVitrineRKeyHomeHideShortcuts),
            ASMVitrineShownRow(@"DJ", nil, ASMVitrineRKeyHomeHideDJ),
            ASMVitrineOptionRow(@"Song suggestions", @"Spotify's carousel of songs to try, when Home offers one", ASMVitrineRKeyHomeSongSuggestions),
            ASMVitrineOptionRow(@"Video and playlist previews", @"The cards that play as Home scrolls", ASMVitrineRKeyHomePreviews),
        ]),
        ASMVitrineNotedSection(@"Shelves", rows, @"The shelves Home has shown in the last 30 days. A shelf is known by its heading, so one "
                                         @"Spotify names differently in another language is listed again."),
    ] footer:nil];
}
