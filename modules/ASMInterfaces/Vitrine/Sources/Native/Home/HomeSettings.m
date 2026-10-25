#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Home.h"
#import "Native/Playlist/Playlist.h"
#import "Native/Artist/Artist.h"
#import "Native/Album/Album.h"

static ASMVitrineModRow *choiceRow(NSString *title, NSString *subtitle, ASMVitrineHomeChoice choice) {
    return ASMVitrineChoiceRow(title, subtitle, ASMVitrineHomeChoiceKey(choice), ASMVitrineHomeChoiceNames(choice),
                       ASMVitrineHomeChoiceDefault(choice));
}

UIViewController *ASMVitrineHomeGradientPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Gradient"
                                      intro:@"Turning it on or off applies after you restart Spotify."
                                   sections:@[
        ASMVitrineSection(@"Gradient", @[
            ASMVitrineOptionRow(@"Show", nil, ASMVitrineKeyHomeGradient),
            choiceRow(@"Color", nil, ASMVitrineHomeChoiceTint),
            choiceRow(@"Strength", nil, ASMVitrineHomeChoiceStrength),
            choiceRow(@"Height", nil, ASMVitrineHomeChoiceHeight),
        ]),
    ] footer:nil];
}

static UIViewController *libraryPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Library" intro:nil sections:@[
        ASMVitrineSection(@"Library", @[
            ASMVitrineFlagRow(@"Denser rows", @"ios-feature-yourlibaryx.denser_rows_enabled"),
            ASMVitrineFlagRow(@"Sort playlists by recently updated", @"ios-feature-yourlibaryx.recently_updated_playlists_sort_enabled"),
            ASMVitrineFlagRow(@"Sort artists by recently updated", @"ios-feature-yourlibaryx.recently_updated_artists_sort_enabled"),
            ASMVitrineFlagRow(@"Recents", @"ios-feature-yourlibaryx.recents_enabled"),
            ASMVitrineFlagRow(@"Recents sort order", @"ios-feature-yourlibaryx.recents_sort_order_enabled"),
            ASMVitrineFlagRow(@"Library settings", @"ios-feature-yourlibaryx.library_settings_enabled"),
            ASMVitrineFlagRow(@"Library Pro", @"ios-feature-yourlibaryx.your_library_pro_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *ASMVitrineHomeSettingsPage(void) {
    // The row reads its own state out, so the section says which color is set without being opened.
    ASMVitrineModRow *gradient = ASMVitrinePageRow(@"Gradient", ^UIViewController *{ return ASMVitrineHomeGradientPage(); });
    gradient.value = ^NSString *{
        if (!ASMVitrineFlag(ASMVitrineKeyHomeGradient, NO)) return @"Off";
        return ASMVitrineHomeChoiceNames(ASMVitrineHomeChoiceTint)[(NSUInteger)ASMVitrineHomeChoiceValue(ASMVitrineHomeChoiceTint)];
    };

    NSArray<ASMVitrineModSection *> *sections = @[
        ASMVitrineSection(nil, @[
            ASMVitrineWithSymbol(ASMVitrinePageRow(@"Playlists", ^UIViewController *{ return ASMVitrinePlaylistSettingsPage(); }), @"music.note.list"),
            ASMVitrineWithSymbol(ASMVitrinePageRow(@"Library", ^UIViewController *{ return libraryPage(); }), @"books.vertical"),
            ASMVitrineWithSymbol(ASMVitrinePageRow(@"Album", ^UIViewController *{ return ASMVitrineAlbumSettingsPage(); }), @"square.stack"),
            ASMVitrineWithSymbol(ASMVitrinePageRow(@"Artist", ^UIViewController *{ return ASMVitrineArtistSettingsPage(); }), @"music.mic"),
        ]),
        ASMVitrineSection(@"Home", @[
            ASMVitrineWithSymbol(gradient, @"rectangle.tophalf.inset.filled"),
            ASMVitrineFlagRow(@"Pull to refresh", @"ios-home-evopage-impl.pull_to_refresh_enabled"),
        ]),
        ASMVitrineSection(@"Hide on Home", @[
            ASMVitrineHideRow(@"Filter pills", nil, ASMVitrineHideHomePills),
            ASMVitrineHideRow(@"Shortcuts grid", nil, ASMVitrineHideHomeShortcuts),
            ASMVitrineHideRow(@"Promo cards", nil, ASMVitrineHideHomePromo),
            ASMVitrineHideRow(@"Preview cards", nil, ASMVitrineHideHomePreviews),
            ASMVitrineHideRow(@"DJ card", nil, ASMVitrineHideHomeDJ),
            ASMVitrineKillRow(@"DJ button", @"ios-home-evopage-impl.idj_show_dj_button"),
            ASMVitrineKillRow(@"DJ beta badge", @"ios-home-evopage-impl.dj_mdc_beta_badge_enabled"),
        ]),
    ];
    return [[ASMVitrineModPage alloc] initWithTitle:@"Home & Library" intro:nil sections:sections footer:nil];
}
