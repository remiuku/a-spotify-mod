// A font family of the user's own for Fonts.x: the .ttf, .otf, .ttc or .otc files of one family picked together in
// Files are copied into Application Support, registered with Core Text for this process and named by the
// family name read from them. Like every other font choice it takes over when Spotify starts again, and
// Fonts.x registers the files again on each launch.
#import <CoreText/CoreText.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Shared/Fonts/Fonts.h"

static NSURL *fontFolder(void) {
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [[support URLByAppendingPathComponent:@"Vitrine" isDirectory:YES] URLByAppendingPathComponent:@"Font" isDirectory:YES];
}

// The family name of every face in the file, "" for a face without one; empty when Core Text finds no font. A
// collection gives one per face.
static NSArray<NSString *> *familiesIn(NSURL *url) {
    NSArray *faces = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (id face in faces) {
        NSString *name = CFBridgingRelease(CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)face, kCTFontFamilyNameAttribute));
        [names addObject:name ?: @""];
    }
    return names;
}

// The one family name all the faces share, or nil when they differ, one has none, or there are no faces.
NSString *ASMVitrineFontSingleFamily(NSArray<NSString *> *names) {
    NSSet<NSString *> *distinct = [NSSet setWithArray:names];
    return distinct.count == 1 && distinct.anyObject.length ? distinct.anyObject : nil;
}

// An import from before families is one file under ASMVitrineKeyAppFontFile and a PostScript name under
// ASMVitrineKeyAppFontName. It becomes a list of one file and its family name, on first use after the update.
static void migrate(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSString *file = [store stringForKey:ASMVitrineKeyAppFontFile];
    if (!file.length) return;
    NSString *family = familiesIn([fontFolder() URLByAppendingPathComponent:file.lastPathComponent]).firstObject;
    if (family.length) {
        [store setObject:@[file] forKey:ASMVitrineKeyAppFontFiles];
        [store setObject:family forKey:ASMVitrineKeyAppFontName];
    }
    [store removeObjectForKey:ASMVitrineKeyAppFontFile];
}

// The imported files still in the folder.
static NSArray<NSURL *> *storedFiles(void) {
    migrate();
    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (NSString *file in [NSUserDefaults.standardUserDefaults arrayForKey:ASMVitrineKeyAppFontFiles]) {
        NSURL *url = [fontFolder() URLByAppendingPathComponent:file.lastPathComponent];
        if ([NSFileManager.defaultManager fileExistsAtPath:url.path]) [urls addObject:url];
    }
    return urls;
}

static NSString *importedFamily(void) {
    return storedFiles().count ? [NSUserDefaults.standardUserDefaults stringForKey:ASMVitrineKeyAppFontName] : nil;
}

// A face iOS already carries under the same name (Chalkduster, say) is refused as a duplicate and is there
// all the same, so what counts is whether the family has faces afterward. Files that are gone are skipped.
NSString *ASMVitrineRegisterCustomFont(void) {
    NSString *family = importedFamily();
    for (NSURL *url in storedFiles()) {
        CFErrorRef error = NULL;
        if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error)) {
            NSError *failure = CFBridgingRelease(error);
            ASMVitrineLog(@"fonts: %@ not registered: %@", url.lastPathComponent, failure.localizedDescription);
        }
    }
    return family && [UIFont fontNamesForFamilyName:family].count ? family : nil;
}

// The imported files unregistered and deleted, and the choice forgotten.
static void removeImported(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    for (NSURL *url in storedFiles()) {
        CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
        [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
    for (NSString *key in @[ASMVitrineKeyAppFontFiles, ASMVitrineKeyAppFontName]) [store removeObjectForKey:key];
    if (ASMVitrineAppFontChosen() == ASMVitrineAppFontCustom) ASMVitrineSetInt(ASMVitrineKeyAppFont, ASMVitrineAppFontSpotify);
}

static void tell(NSString *title, NSString *message, BOOL restart) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    if (restart) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { ASMVitrineRestartSpotify(); }]];
    } else {
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    }
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

// The files are checked and copied aside before the ones in use are touched, so files Core Text will not read,
// of more than one family, or that fail to copy change nothing.
static void import(NSArray<NSURL *> *picked) {
    NSMutableArray<NSURL *> *scoped = [NSMutableArray array];
    NSMutableArray<NSString *> *families = [NSMutableArray array];
    BOOL fonts = YES;
    for (NSURL *url in picked) {
        if ([url startAccessingSecurityScopedResource]) [scoped addObject:url];
        NSArray<NSString *> *names = familiesIn(url);
        fonts = fonts && names.count;
        [families addObjectsFromArray:names];
    }
    NSString *family = fonts ? ASMVitrineFontSingleFamily(families) : nil;
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *incoming = [fontFolder() URLByAppendingPathComponent:@"Incoming" isDirectory:YES];
    NSMutableArray<NSString *> *copied = [NSMutableArray array];
    if (family) {
        [files removeItemAtURL:incoming error:nil];
        [files createDirectoryAtURL:incoming withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSURL *url in picked) {
            NSString *file = url.lastPathComponent;
            if ([files copyItemAtURL:url toURL:[incoming URLByAppendingPathComponent:file] error:nil]) [copied addObject:file];
        }
    }
    for (NSURL *url in scoped) [url stopAccessingSecurityScopedResource];
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if (family && copied.count == picked.count) {
        removeImported();
        for (NSString *file in copied) {
            NSURL *target = [fontFolder() URLByAppendingPathComponent:file];
            [files removeItemAtURL:target error:nil];
            [files moveItemAtURL:[incoming URLByAppendingPathComponent:file] toURL:target error:nil];
        }
        [files removeItemAtURL:incoming error:nil];
        [store setObject:copied forKey:ASMVitrineKeyAppFontFiles];
        [store setObject:family forKey:ASMVitrineKeyAppFontName];
        if (ASMVitrineRegisterCustomFont()) {
            ASMVitrineSetInt(ASMVitrineKeyAppFont, ASMVitrineAppFontCustom);
            tell(@"Font imported", [NSString stringWithFormat:@"%@ becomes the app's font when Spotify starts again.", family], YES);
            return;
        }
    }
    [files removeItemAtURL:incoming error:nil];
    if (family && copied.count == picked.count) removeImported();   // copied in but Core Text took none of it
    tell(@"Font not imported", fonts && !family ? @"These files are more than one family. Pick the files of one family together."
                                               : @"Choose valid .ttf, .otf, .ttc or .otc font files.", NO);
}

@interface ASMVitrineFontPicker : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, copy) void (^done)(void);   // the page's refresh, once the files are in or refused
@end

@implementation ASMVitrineFontPicker

- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    // The alert waits for the picker to be gone, or it has nothing to present over.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (urls.count) import(urls);
        if (self.done) self.done();
    });
}

@end

static void pickFont(void (^done)(void)) {
    static ASMVitrineFontPicker *delegate;
    if (!delegate) delegate = [ASMVitrineFontPicker new];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFont] asCopy:YES];
    delegate.done = done;
    picker.delegate = delegate;
    picker.allowsMultipleSelection = YES;
    [ASMVitrineTopController() presentViewController:picker animated:YES completion:nil];
}

#pragma mark - the page

// Each choice is drawn in its own font. Core Text makes it, so the font chosen now (Fonts.x hooks UIFont) does
// not dress every row in itself.
static UIFont *previewFont(NSString *nameOrFamily, BOOL family, CGFloat size) {
    CTFontRef font = NULL;
    if (family) {
        CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)@{(id)kCTFontFamilyNameAttribute: nameOrFamily});
        font = CTFontCreateWithFontDescriptor(descriptor, size, NULL);
        CFRelease(descriptor);
    } else if (nameOrFamily) {
        font = CTFontCreateWithName((__bridge CFStringRef)nameOrFamily, size, NULL);
    }
    return font ? (__bridge_transfer UIFont *)font : nil;
}

static UIFont *builtInFont(ASMVitrineAppFont choice, CGFloat size) {
    if (choice == ASMVitrineAppFontSpotify) return previewFont(@"SpotifyMixUI-Regular", NO, size);
    UIFontDescriptor *system = ((__bridge_transfer UIFont *)CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, size, NULL)).fontDescriptor;
    UIFontDescriptorSystemDesign design = choice == ASMVitrineAppFontRounded ? UIFontDescriptorSystemDesignRounded
        : choice == ASMVitrineAppFontSerif ? UIFontDescriptorSystemDesignSerif
        : choice == ASMVitrineAppFontMono ? UIFontDescriptorSystemDesignMonospaced : UIFontDescriptorSystemDesignDefault;
    UIFontDescriptor *descriptor = [system fontDescriptorWithDesign:design] ?: system;
    return (__bridge_transfer UIFont *)CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)descriptor, size, NULL);
}

static NSString *chosenLabel(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    ASMVitrineAppFont font = ASMVitrineAppFontChosen();
    if (font == ASMVitrineAppFontCustom) return importedFamily() ?: @"Your font";
    if (font == ASMVitrineAppFontFamily) return [store stringForKey:ASMVitrineKeyAppFontFamily] ?: ASMVitrineAppFontNames()[0];
    return ASMVitrineAppFontNames()[font];
}

typedef NS_ENUM(NSInteger, ASMVitrineFontSection) { ASMVitrineFontBuiltIn, ASMVitrineFontMore, ASMVitrineFontYours };

@interface ASMVitrineFontPage : ASMVitrinePage
@end

@implementation ASMVitrineFontPage {
    NSArray<NSString *> *_families;
    UIView *_footer;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Font";
    _families = ASMVitrineAppFontFamilies();
    ASMVitrineRegisterCustomFont();   // so the imported family can be drawn here, whichever font is chosen
    return self;
}

// A one-face import says why bold comes out regular; otherwise the note says how to bring the bold along.
- (void)refreshFooter {
    NSString *own = self.styleCount == 1
        ? @"A font of your own is a .ttf or .otf file from Files. This one has a single style, so bold text comes out regular. Pick all the files of a family together to keep bold. "
        : @"A font of your own comes from Files: a .ttf or .otf file, or all the files of one family picked together, so bold and italic stay. ";
    _footer = ASMVitrineNote([own stringByAppendingString:@"Text Spotify draws itself may keep its own font. Changes apply after you restart Spotify."]);
    self.tableView.tableFooterView = _footer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self refreshFooter];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    ASMVitrineFitNote(self.tableView, _footer, 8, 24);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refresh];
}

- (void)refresh {
    [self refreshFooter];
    [self.tableView reloadData];
}

// The imported family, while there is one, then the row that adds one.
- (NSString *)importedName {
    return importedFamily();
}

// How many faces the imported family has on this iPhone.
- (NSUInteger)styleCount {
    NSString *name = self.importedName;
    return name ? [UIFont fontNamesForFamilyName:name].count : 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return 3;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == ASMVitrineFontBuiltIn) return (NSInteger)ASMVitrineAppFontNames().count;
    if (section == ASMVitrineFontMore) return (NSInteger)_families.count;
    return self.importedName.length ? 2 : 1;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    return section == ASMVitrineFontBuiltIn ? nil : ASMVitrineSectionHeader(table, section == ASMVitrineFontMore ? @"More fonts" : @"Your fonts");
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == ASMVitrineFontBuiltIn ? ASMVitrineSectionGap : ASMVitrineSectionHeaderHeight();
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = ASMVitrineDequeueCell(table, @"font");
    CGFloat size = ASMVitrineTitleFont().pointSize;
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    ASMVitrineAppFont chosen = ASMVitrineAppFontChosen();
    NSString *title, *subtitle = nil;
    UIFont *font;
    BOOL selected;
    if (path.section == ASMVitrineFontBuiltIn) {
        title = ASMVitrineAppFontNames()[(NSUInteger)path.row];
        font = builtInFont(path.row, size);
        selected = chosen == path.row;
    } else if (path.section == ASMVitrineFontMore) {
        title = _families[(NSUInteger)path.row];
        font = previewFont(title, YES, size);
        selected = chosen == ASMVitrineAppFontFamily && [title isEqualToString:[store stringForKey:ASMVitrineKeyAppFontFamily]];
    } else if (path.row == 0 && self.importedName.length) {
        title = self.importedName;
        font = previewFont(title, YES, size);
        selected = chosen == ASMVitrineAppFontCustom;
        subtitle = [NSString stringWithFormat:@"%lu style%@", (unsigned long)self.styleCount, self.styleCount == 1 ? @"" : @"s"];
    } else {
        ASMVitrineFillCell(cell, @"Add a font file", nil, ASMVitrineGreen(), nil);
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    ASMVitrineFillCell(cell, title, subtitle, nil, nil);
    UIListContentConfiguration *content = (UIListContentConfiguration *)cell.contentConfiguration;
    if (font) content.textProperties.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:font maximumPointSize:18];
    cell.contentConfiguration = content;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (selected) {
        UIImageView *tick = ASMVitrineSymbolView(@"checkmark", 13, UIImageSymbolWeightSemibold, 16);
        tick.tintColor = ASMVitrineGreen();
        cell.accessoryView = tick;
    }
    cell.accessibilityTraits = selected ? UIAccessibilityTraitButton | UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section == ASMVitrineFontBuiltIn) {
        ASMVitrineSetInt(ASMVitrineKeyAppFont, path.row);
    } else if (path.section == ASMVitrineFontMore) {
        [NSUserDefaults.standardUserDefaults setObject:_families[(NSUInteger)path.row] forKey:ASMVitrineKeyAppFontFamily];
        ASMVitrineSetInt(ASMVitrineKeyAppFont, ASMVitrineAppFontFamily);
    } else if (path.row == 0 && self.importedName.length) {
        ASMVitrineSetInt(ASMVitrineKeyAppFont, ASMVitrineAppFontCustom);
    } else {
        __weak ASMVitrineFontPage *page = self;
        pickFont(^{ [page refresh]; });
        return;
    }
    [table reloadData];
}

// Swiping the imported family away deletes its files; Default comes back if it was the choice.
- (UISwipeActionsConfiguration *)tableView:(UITableView *)table trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section != ASMVitrineFontYours || path.row != 0 || !self.importedName.length) return nil;
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete"
        handler:^(UIContextualAction *action, UIView *view, void (^done)(BOOL)) {
            removeImported();
            [self refresh];
            done(YES);
        }];
    delete.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

@end

NSArray<ASMVitrineModRow *> *ASMVitrineAppFontRows(void) {
    ASMVitrineModRow *font = ASMVitrinePageRow(@"Font", ^UIViewController *{ return [ASMVitrineFontPage new]; });
    font.value = ^NSString *{ return chosenLabel(); };
    return @[font];
}
