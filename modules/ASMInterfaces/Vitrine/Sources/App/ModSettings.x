#import "Core/ASMHost.h"
#import "Core/ASMHost.h"
#import "Core/ASMHost.h"
#import "Core/ASMHost.h"
// Settings: a Mod Settings row at the end of Spotify's settings list opens the mod's own page, its rows
// grouped by what they are as the system Settings app groups its own, in cards with no headings: what the
// app looks like (Redesigned UI's switch, Appearance, Tab bar), the screens a page of its own changes
// (Home & Library in the native look, Player, Lyrics, and Albums and Artists in the redesign), the features
// that work under either look (Sing, Spatial voice, Audio effects, AutoMix, Live Activity, AirPods gestures, Listening
// stats), the system's side (Lock screen, Vibrations; Premium, ads & privacy), the advanced pages (Labs, All flags, a
// searchable list of every flag with an override per flag) and Mod, the build, its updates and links. The
// same row leads the side drawer's list (trees/test6.txt), above Your plan, so the page is a tap from
// Home, and holding Home on the tab bar opens it too. The tweaks read the switches when they run, so a
// change shows after Spotify restarts; the tab editor on the Tab bar page applies as soon as the bar lays
// out again.
//
// Tree (trees/settings.txt): SettingsListViewController.view > SettingsListCollectionView of
//   Element_List cells 402x56: 24pt icon at x 12, 13pt white title and 11pt gray subtitle at
//   x 48, 12pt chevron on the right. A pushed page (trees/settings notifications opened.txt) is a
//   UITableView bg #121212: header with an 11pt gray description at (16, 24), 53pt cells with the
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrinePage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Settings/ASMVitrineModPage.h"
#import "Native/Home/Home.h"
#import "Redesigned/Home/Home.h"
#import "Shared/AdBlock/AdBlock.h"
#import "Shared/Flags/Flags.h"
#import "Shared/AudioEffects/AudioEffectsPage.h"
#import "Shared/AutoMix/AutoMix.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Shared/ListeningStats/ListeningStats.h"
#import "Shared/HeadGestures/HeadGestures.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/Sing/Sing.h"
#import "Shared/Haptics/Haptics.h"
#import "App/About/About.h"
#import "App/Onboarding/Onboarding.h"
#import "Redesigned/Album/Album.h"
#import "Redesigned/Artist/Artist.h"
#import "Pages.h"

static const CGFloat kRowHeight = 56;
static char kRowKey, kInsetKey;

// Each part of Spotify on a tile of its own color, as Settings lists its own, so a row is found by its color.
static ASMVitrineModRow *pageRow(NSString *title, NSString *symbol, UIColor *color, UIViewController *(^page)(void)) {
    return ASMVitrineWithTile(ASMVitrinePageRow(title, page), symbol, color);
}

static UIViewController *modSettingsPage(void) {
    // Opening the page is the only thing that asks; the cache keeps it to once every six hours.
    ASMVitrineCheckForUpdate(NO);
    NSMutableArray<ASMVitrineModSection *> *sections = [NSMutableArray array];
    // A build the lock screen cannot open leads the page, above the tweaks: it is the one thing here
    // that no switch can put right, and it is worth reading before anything else.
    ASMVitrineModRow *signing = ASMVitrineSigningWarningRow();
    NSMutableArray<ASMVitrineModRow *> *warnings = [NSMutableArray arrayWithArray:ASMVitrineEnvironmentWarningRows()];
    if (signing) [warnings insertObject:signing atIndex:0];
    // A free Apple ID's week runs out with no warning from iOS, so its date waits here too, not only under Mod.
    if (ASMVitrineSigningWeekLong()) [warnings addObject:ASMVitrineWithSymbol(ASMVitrineSigningExpiryRow(), @"clock.badge.exclamationmark")];
    if (warnings.count) [sections addObject:ASMVitrineSection(nil, warnings)];

    // The rows of one look are asked again as Redesigned UI is flipped, so the page shows what the restart brings.
    BOOL (^redesigned)(void) = ^BOOL { return ASMVitrineRedesignedUIStored(); };
    BOOL (^native)(void) = ^BOOL { return !ASMVitrineRedesignedUIStored(); };

    // The tile colors are the system palette's, in dark mode except where ASMVitrineColorRGB gives a lighter or deeper shade.
    [sections addObject:ASMVitrineNotedSection(nil, @[
        ASMVitrineRedesignedUIRow(),
        pageRow(@"Appearance", @"paintpalette.fill", UIColor.systemPurpleColor, ^UIViewController *{ return ASMVitrineAppearancePage(); }),
        pageRow(@"Tab bar", @"rectangle.bottomthird.inset.filled", UIColor.systemGrayColor, ^UIViewController *{ return ASMVitrineNavbarPage(); }),
    ], ASMVitrineRestartNote)];

    // Home & Library holds only the native look's switches; the redesign has its album and artist pages instead.
    ASMVitrineModRow *albums = pageRow(@"Albums", @"square.stack.fill", ASMVitrineColorRGB(0x34C759), ^UIViewController *{ return ASMVitrineRAlbumSettingsPage(); });
    albums.visible = redesigned;
    ASMVitrineModRow *artists = pageRow(@"Artists", @"music.mic", ASMVitrineColorRGB(0x30B0C7), ^UIViewController *{ return ASMVitrineRArtistSettingsPage(); });
    artists.visible = redesigned;
    ASMVitrineModRow *home = pageRow(@"Home & Library", @"house.fill", UIColor.systemBrownColor, ^UIViewController *{ return ASMVitrineHomeSettingsPage(); });
    home.visible = native;
    ASMVitrineModRow *redesignedHome = pageRow(@"Home", @"house.fill", UIColor.systemBrownColor, ^UIViewController *{ return ASMVitrineRHomeSettingsPage(); });
    redesignedHome.visible = redesigned;
    [sections addObject:ASMVitrineSection(nil, @[
        redesignedHome,
        home,
        pageRow(@"Player", @"play.fill", UIColor.systemPinkColor, ^UIViewController *{ return ASMVitrinePlayerSettingsPage(); }),
        pageRow(@"Lyrics", @"quote.bubble.fill", UIColor.systemOrangeColor, ^UIViewController *{ return ASMVitrineLyricsSettingsPage(); }),
        albums,
        artists,
    ])];

    // Sing and the audio effects work on the sound, so both looks have them; Audio effects says how many are on.
    ASMVitrineModRow *sing = pageRow(@"Karaoke", @"mic.fill", ASMVitrineColorRGB(0x8C42B3), ^UIViewController *{ return ASMVitrineSingSettingsPage(); });
    ASMVitrineModRow *audioEffects = pageRow(@"Audio effects", @"slider.vertical.3", UIColor.systemRedColor, ^UIViewController *{ return ASMVitrineDSPSettingsPage(); });
    audioEffects.value = ^NSString *{ return ASMVitrineDSPSummary(); };
    // Spatial voice is Sing's too, and shows where the iPhone reads headphone motion, as on Sing's page.
    ASMVitrineModRow *spatial = pageRow(@"Spatial voice", @"person.wave.2.fill", ASMVitrineColorRGB(0x5856D6), ^UIViewController *{ return ASMVitrineSpatialVoiceSettingsPage(); });
    spatial.visible = ^BOOL { return ASMVitrineSingSpatialAvailable(); };
    // AutoMix sets Spotify's own Automix and Crossfade, which its player does under either look.
    ASMVitrineModRow *autoMix = pageRow(@"AutoMix", @"arrow.triangle.merge", ASMVitrineColorRGB(0xF05D6C), ^UIViewController *{ return ASMVitrineAutoMixSettingsPage(); });
    autoMix.value = ^NSString *{ return ASMVitrineAutoMixSummary(); };
    NSMutableArray<ASMVitrineModRow *> *features = [NSMutableArray arrayWithObjects:sing, spatial, audioEffects, autoMix, nil];
    // The Live Activity works under both looks, where ActivityKit's card does.
    if (@available(iOS 17.0, *)) {
        ASMVitrineModRow *liveActivity = pageRow(@"Live Activity", @"iphone", UIColor.systemOrangeColor, ^UIViewController *{ return ASMVitrineLiveActivitySettingsPage(); });
        [features addObject:liveActivity];
    }
    [features addObjectsFromArray:@[
        pageRow(@"AirPods gestures", @"airpods", UIColor.systemCyanColor, ^UIViewController *{ return ASMVitrineHeadGesturesSettingsPage(); }),
        pageRow(@"Listening stats", @"chart.bar.fill", UIColor.systemBlueColor, ^UIViewController *{ return ASMVitrineListeningStatsPage(); }),
    ]];
    [sections addObject:ASMVitrineSection(nil, features)];

    ASMVitrineModRow *mod = pageRow(@"Mod", @"info.circle", ASMVitrineColorRGB(0x7D7D81), ^UIViewController *{ return ASMVitrineAboutPage(); });
    mod.value = ^NSString *{ return @(ASMVitrine_VERSION); };
    [sections addObjectsFromArray:@[
        ASMVitrineSection(nil, @[
            pageRow(@"Lock screen", @"lock.iphone", ASMVitrineColorRGB(0x32ADE6), ^UIViewController *{ return ASMVitrineLockScreenWidgetPage(); }),
            // Vibrations hook Spotify's own controls and its audio, so they answer under either look.
            pageRow(@"Vibrations", @"waveform", UIColor.systemGreenColor, ^UIViewController *{ return ASMVitrineVibrationsSettingsPage(); }),
            pageRow(@"Premium, ads & privacy", @"hand.raised.fill", UIColor.systemBlueColor, ^UIViewController *{ return ASMVitrineAdsSettingsPage(); }),
        ]),
        ASMVitrineSection(nil, @[
            pageRow(@"Labs", @"testtube.2", UIColor.systemGreenColor, ^UIViewController *{ return ASMVitrineLabsPage(); }),
            pageRow(@"All flags", @"flag.fill", UIColor.systemOrangeColor, ^UIViewController *{ return ASMVitrineAllFlagsPage(); }),
        ]),
        ASMVitrineSection(nil, @[mod]),
    ]];
    ASMVitrineModPage *page = [[ASMVitrineModPage alloc] initWithTitle:@"Vitrine" intro:nil sections:sections footer:nil];
    page.tiles = YES;
    return page;
}

#pragma mark - row in the settings list and the side drawer

// The last row of Spotify's settings list, chevron and all, or the first of the side drawer's,
// drawn like the drawer's own rows: no chevron, icon and title 4pt further in.
@interface ASMVitrineModSettingsRow : UIControl
@property (nonatomic) BOOL drawer;
@end

@implementation ASMVitrineModSettingsRow {
    UIImageView *_icon;
    UILabel *_title;
    UIImageView *_chevron;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _icon = ASMVitrineSymbolView(@"slider.horizontal.3", 20, UIImageSymbolWeightRegular, 24);
    _title = [UILabel new];
    _title.text = @"Mod Settings";
    _title.textColor = UIColor.whiteColor;
    _chevron = ASMVitrineSymbolView(@"chevron.right", 11, UIImageSymbolWeightSemibold, 12);
    for (UIView *v in @[_icon, _title, _chevron]) [self addSubview:v];
    [self addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _title.font = ASMVitrineSpotifyListFont();
    CGFloat width = self.bounds.size.width, height = self.bounds.size.height, lead = self.drawer ? 4 : 0;
    _icon.frame = CGRectMake(12 + lead, (height - 24) / 2, 24, 24);
    _title.frame = CGRectMake(48 + lead, 0, width - 96, height);
    _chevron.frame = CGRectMake(width - 24, (height - 12) / 2, 12, 12);
    _chevron.hidden = self.drawer;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.5 : 1;
}

static UINavigationController *navigationIn(UIViewController *page) {
    if ([page isKindOfClass:UINavigationController.class]) return (UINavigationController *)page;
    for (UIViewController *child in page.childViewControllers) {
        UINavigationController *found = navigationIn(child);
        if (found) return found;
    }
    return nil;
}

// The drawer is presented over the app, so its row closes it first and pushes onto the stack it
// was covering, the way the drawer's own rows open their pages.
- (void)open {
    UIViewController *owner = nil;
    for (UIResponder *r = self; r && !owner; r = r.nextResponder) {
        if ([r isKindOfClass:UIViewController.class]) owner = (UIViewController *)r;
    }
    UIViewController *presenting = self.drawer ? owner.presentingViewController : nil;
    if (!presenting) {
        ASMVitrineShowPage(owner, modSettingsPage());
        return;
    }
    [presenting dismissViewControllerAnimated:YES completion:^{
        ASMVitrineShowPage(navigationIn(presenting).topViewController ?: presenting, modSettingsPage());
    }];
}

@end

// The tab bar's controller holds no stack itself; the selected tab's sits among its parent's children.
void ASMVitrineOpenModSettings(UIView *source) {
    ASMHostAction(@"openSettings");
}

// At the end of the settings list, or above the first row of the drawer's, with the inset for it
// added again whenever Spotify resets the inset.
static void placeRow(UICollectionView *list, ASMVitrineModSettingsRow *row) {
    ASMVitrineAdoptFonts(list, row);
    CGFloat bottom = list.contentSize.height;
    row.hidden = !row.drawer && bottom <= 0;
    row.frame = CGRectMake(0, row.drawer ? -kRowHeight : bottom, list.bounds.size.width, kRowHeight);

    UIEdgeInsets inset = list.contentInset;
    NSValue *applied = objc_getAssociatedObject(list, &kInsetKey);
    if (applied && UIEdgeInsetsEqualToEdgeInsets(inset, applied.UIEdgeInsetsValue)) return;
    if (row.drawer) inset.top += kRowHeight;
    else inset.bottom += kRowHeight;
    objc_setAssociatedObject(list, &kInsetKey, [NSValue valueWithUIEdgeInsets:inset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    list.contentInset = inset;
}

// Media quality, Playback, Account and most of the rest of settings are the same controller class
// as the list they were opened from, which is why the row turned up at the end of all of them.
// What is on the navigation stack is not that controller though: every page in the app is wrapped
// in a MusicAppPageHostingViewController (trees/settings notifications opened.txt), and Spotify
// pushes a settings sub page as a page of its own, leaving the list it came from on the stack
// underneath. So the settings list inside the lowest wrapper that holds one is the list the row
// belongs at the end of, and a controller with no stack to be found on keeps the row rather than
// losing it.
static UIViewController *settingsListIn(UIViewController *page, Class kind) {
    if ([page isKindOfClass:kind]) return page;
    for (UIViewController *child in page.childViewControllers) {
        UIViewController *found = settingsListIn(child, kind);
        if (found) return found;
    }
    return nil;
}

static BOOL isSettingsRoot(UIViewController *list) {
    for (UIViewController *page in list.navigationController.viewControllers) {
        UIViewController *found = settingsListIn(page, list.class);
        if (found) return found == list;
    }
    return YES;
}

%hook _TtC21Settings_PlatformImpl26SettingsListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    BOOL root = isSettingsRoot((UIViewController *)self);
    for (UIView *sub in ((UIViewController *)self).view.subviews) {
        if (![sub isKindOfClass:UICollectionView.class]) continue;
        ASMVitrineModSettingsRow *row = objc_getAssociatedObject(sub, &kRowKey);
        // A page that laid itself out before it was on the stack looked like the list for as long
        // as that took; the row goes again as soon as it can be seen for what it is.
        if (!root) {
            [row removeFromSuperview];
            objc_setAssociatedObject(sub, &kRowKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            continue;
        }
        if (row) continue;
        row = [[ASMVitrineModSettingsRow alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(sub, &kRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [sub addSubview:row];
    }
}
%end

// The drawer's list (trees/test6.txt: SideDrawerListCollectionView under the profile header, Your
// plan its first cell) is one of several collection views on the page, so it is found by name, and
// its class is kept for the list's own layout below to know it by. Spotify 9.1.78's private class is
// looked up at launch, so the list gets its row on its first layout, even before its controller's.
static NSString *const kDrawerList = @"_TtC23SideDrawer_ListPageImplP33_1D8CA7A9CC41E8D184AF8B9AAE4E684E28SideDrawerListCollectionView";
static Class asm_vitrine_drawerList;

// Spotify can take the list's subviews away and fill it again while keeping the list itself, so a
// row that has lost its place is put back rather than a second one made.
static void attachDrawerRow(UICollectionView *list) {
    ASMVitrineModSettingsRow *row = objc_getAssociatedObject(list, &kRowKey);
    if (!row) {
        row = [[ASMVitrineModSettingsRow alloc] initWithFrame:CGRectZero];
        row.drawer = YES;
        objc_setAssociatedObject(list, &kRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (row.superview != list) [list addSubview:row];
}

%hook _TtC23SideDrawer_ListPageImpl18ListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    ASMVitrineForEachView(((UIViewController *)self).view, ^(UIView *v) {
        if (![v isKindOfClass:UICollectionView.class] || ![NSStringFromClass(v.class) containsString:@"SideDrawerListCollectionView"]) return;
        asm_vitrine_drawerList = v.class;
        attachDrawerRow((UICollectionView *)v);
    });
}
%end

// The lists lay out after their controllers and again whenever their content changes. The drawer's
// can fill after its controller laid out, so its row is made or put back there too. Either list's row
// that Spotify took away with the list's subviews is put back before it is placed.
%hook UICollectionView
- (void)layoutSubviews {
    %orig;
    if (asm_vitrine_drawerList && [self isKindOfClass:asm_vitrine_drawerList]) attachDrawerRow(self);
    ASMVitrineModSettingsRow *row = objc_getAssociatedObject(self, &kRowKey);
    if (!row) return;
    if (row.superview != self) [self addSubview:row];
    placeRow(self, row);
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    asm_vitrine_drawerList = NSClassFromString(kDrawerList);
    %init;
    ASMVitrineRequireClasses(@[@"_TtC21Settings_PlatformImpl26SettingsListViewController", @"_TtC23SideDrawer_ListPageImpl18ListViewController"]);
    ASMVitrineRegisterPages();
    ASMVitrineCheckSigningOnce();
    ASMVitrineWatchForUpdates();
}
