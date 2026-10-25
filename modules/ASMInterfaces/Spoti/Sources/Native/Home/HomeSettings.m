#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Home.h"
#import "Native/Playlist/Playlist.h"
#import "Native/Artist/Artist.h"
#import "Native/Album/Album.h"

static ASMSpotiModRow *choiceRow(NSString *title, NSString *subtitle, ASMSpotiHomeChoice choice) {
    return ASMSpotiChoiceRow(title, subtitle, ASMSpotiHomeChoiceKey(choice), ASMSpotiHomeChoiceNames(choice),
                       ASMSpotiHomeChoiceDefault(choice));
}

UIViewController *ASMSpotiHomeGradientPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Gradient"
                                      intro:@"Turning it on or off applies after you restart Spotify."
                                   sections:@[
        ASMSpotiSection(@"Gradient", @[
            ASMSpotiOptionRow(@"Show", nil, ASMSpotiKeyHomeGradient),
            choiceRow(@"Colour", nil, ASMSpotiHomeChoiceTint),
            choiceRow(@"Strength", nil, ASMSpotiHomeChoiceStrength),
            choiceRow(@"Height", nil, ASMSpotiHomeChoiceHeight),
        ]),
    ] footer:nil];
}

static UIViewController *libraryPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Library" intro:nil sections:@[
        ASMSpotiSection(@"Library", @[
            ASMSpotiFlagRow(@"Denser rows", @"ios-feature-yourlibaryx.denser_rows_enabled"),
            ASMSpotiFlagRow(@"Sort playlists by recently updated", @"ios-feature-yourlibaryx.recently_updated_playlists_sort_enabled"),
            ASMSpotiFlagRow(@"Sort artists by recently updated", @"ios-feature-yourlibaryx.recently_updated_artists_sort_enabled"),
            ASMSpotiFlagRow(@"Recents", @"ios-feature-yourlibaryx.recents_enabled"),
            ASMSpotiFlagRow(@"Recents sort order", @"ios-feature-yourlibaryx.recents_sort_order_enabled"),
            ASMSpotiFlagRow(@"Library settings", @"ios-feature-yourlibaryx.library_settings_enabled"),
            ASMSpotiFlagRow(@"Library Pro", @"ios-feature-yourlibaryx.your_library_pro_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *ASMSpotiHomeSettingsPage(void) {
    // The row reads its own state out, so the section says which colour is set without being opened.
    ASMSpotiModRow *gradient = ASMSpotiPageRow(@"Gradient", ^UIViewController *{ return ASMSpotiHomeGradientPage(); });
    gradient.value = ^NSString *{
        if (!ASMSpotiFlag(ASMSpotiKeyHomeGradient, NO)) return @"Off";
        return ASMSpotiHomeChoiceNames(ASMSpotiHomeChoiceTint)[(NSUInteger)ASMSpotiHomeChoiceValue(ASMSpotiHomeChoiceTint)];
    };

    NSArray<ASMSpotiModSection *> *sections = @[
        ASMSpotiSection(nil, @[
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"Playlists", ^UIViewController *{ return ASMSpotiPlaylistSettingsPage(); }), @"music.note.list"),
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"Library", ^UIViewController *{ return libraryPage(); }), @"books.vertical"),
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"Album", ^UIViewController *{ return ASMSpotiAlbumSettingsPage(); }), @"square.stack"),
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"Artist", ^UIViewController *{ return ASMSpotiArtistSettingsPage(); }), @"music.mic"),
        ]),
        ASMSpotiSection(@"Home", @[
            ASMSpotiWithSymbol(gradient, @"rectangle.tophalf.inset.filled"),
            ASMSpotiFlagRow(@"Pull to refresh", @"ios-home-evopage-impl.pull_to_refresh_enabled"),
        ]),
        ASMSpotiSection(@"Hide on Home", @[
            ASMSpotiHideRow(@"Filter pills", nil, ASMSpotiHideHomePills),
            ASMSpotiHideRow(@"Shortcuts grid", nil, ASMSpotiHideHomeShortcuts),
            ASMSpotiHideRow(@"Promo cards", nil, ASMSpotiHideHomePromo),
            ASMSpotiHideRow(@"Preview cards", nil, ASMSpotiHideHomePreviews),
            ASMSpotiHideRow(@"DJ card", nil, ASMSpotiHideHomeDJ),
            ASMSpotiKillRow(@"DJ button", @"ios-home-evopage-impl.idj_show_dj_button"),
            ASMSpotiKillRow(@"DJ beta badge", @"ios-home-evopage-impl.dj_mdc_beta_badge_enabled"),
        ]),
    ];
    return [[ASMSpotiModPage alloc] initWithTitle:@"Home & Library" intro:nil sections:sections footer:nil];
}
