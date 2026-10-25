#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Settings/ASMSpotiPageStyle.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerSettings.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Shared/Haptics/Haptics.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Redesigned/Kit/ASMSpotiRAccent.h"

NSString *const ASMSpotiRedesignedUIInfo = @"The newest version of spoti.pw, leaning towards Apple Music's style. It is not compatible with the legacy look's settings.\n\nThe legacy look gives you more freedom, yet still looks like Spotify.";

void ASMSpotiSetRedesignedUI(BOOL on) {
    ASMSpotiSetEnabled(ASMSpotiKeyRedesign, on);
}

// The whole look changes hands at launch, so the switch asks for the restart straight away rather than
// leaving Spotify half in the old look.
static void offerRestart(BOOL on) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restart Spotify"
        message:on ? @"The redesign takes over when Spotify starts again. Spotify closes now; open it again to see it." : @"Spotify's own look comes back when Spotify starts again. Spotify closes now; open it again to see it."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { ASMSpotiRestartSpotify(); }]];
    [ASMSpotiTopController() presentViewController:alert animated:YES completion:nil];
}

// Below iOS 26 the row is not a switch: Liquid Glass is the redesign, and the system draws it from
// that version on, so the row reads out what is missing and the card carries the native look's rows alone.
static ASMSpotiModRow *unavailableRow(void) {
    ASMSpotiModRow *row = ASMSpotiStatActionRow(@"Redesigned UI", nil, ^NSString *{ return @"Needs iOS 26"; }, ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Redesigned UI"
            message:[NSString stringWithFormat:@"The redesign is built on Liquid Glass, which iOS 26 draws and no earlier version can. This phone runs iOS %@, so the mod gives you its legacy look instead: Spotify's own screens with everything else the mod adds on them.", UIDevice.currentDevice.systemVersion]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [ASMSpotiTopController() presentViewController:alert animated:YES completion:nil];
    });
    return ASMSpotiWithSymbol(row, @"sparkles");
}

ASMSpotiModSection *ASMSpotiAppearanceSection(void) {
    if (!ASMSpotiRedesignAvailable()) {
        NSMutableArray<ASMSpotiModRow *> *rows = [NSMutableArray arrayWithObject:unavailableRow()];
        [rows addObjectsFromArray:ASMSpotiNativeAppearanceRows()];
        return ASMSpotiNotedSection(@"Appearance", rows, @"Changes apply after you restart Spotify.");
    }
    ASMSpotiModRow *redesign = ASMSpotiOptionRow(@"Redesigned UI", nil, ASMSpotiKeyRedesign);
    redesign.glows = YES;
    redesign.info = ASMSpotiRedesignedUIInfo;
    redesign.changed = ^(BOOL on) {
        ASMSpotiSetRedesignedUI(on);
        offerRestart(on);
    };
    NSMutableArray<ASMSpotiModRow *> *rows = [NSMutableArray arrayWithObject:ASMSpotiWithSymbol(redesign, @"sparkles")];
    [rows addObjectsFromArray:ASMSpotiRedesignedUIStored() ? ASMSpotiRAppearanceRows() : ASMSpotiNativeAppearanceRows()];
    return ASMSpotiNotedSection(@"Appearance", rows, @"Changes apply after you restart Spotify.");
}

UIViewController *ASMSpotiNavbarPage(void) {
    return ASMSpotiRedesignedUIStored() ? ASMSpotiRNavbarSettingsPage() : ASMSpotiNavbarSettingsPage();
}

// Pronunciation, translation and word sweeping exist only in the redesign's lyrics view.
static UIViewController *lyricsPage(void) {
    BOOL redesigned = ASMSpotiRedesignedUIStored();
    NSMutableArray<ASMSpotiModRow *> *more = [NSMutableArray arrayWithObject:ASMSpotiLockScreenLyricsRow()];
    if (!redesigned) [more insertObject:ASMSpotiGlassLyricsRow() atIndex:0];
    NSMutableArray<ASMSpotiModSection *> *sections = [NSMutableArray arrayWithObject:ASMSpotiLyricsSourcesSection(redesigned)];
    if (redesigned) {
        [sections addObject:ASMSpotiSection(@"Display", @[ASMSpotiLyricsWordTimingRow(), ASMSpotiRLyricsTextSizesRow(), ASMSpotiLyricsTranslationLanguageRow()])];
    }
    [sections addObject:ASMSpotiSection(nil, more)];
    return [[ASMSpotiModPage alloc] initWithTitle:@"Lyrics" intro:ASMSpotiRestartNote sections:sections footer:nil];
}

UIViewController *ASMSpotiPlayerSettingsPage(void) {
    ASMSpotiModRow *blocked = ASMSpotiPageRow(@"Blocked artists", ^UIViewController *{ return ASMSpotiArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return ASMSpotiFlag(ASMSpotiKeyArtistBlock, NO) ? @(ASMSpotiBlockedArtists().count).stringValue : @"Off";
    };
    BOOL native = !ASMSpotiRedesignedUIStored();

    NSMutableArray<ASMSpotiModSection *> *sections = [NSMutableArray arrayWithObject:ASMSpotiSection(nil, @[
        ASMSpotiWithSymbol(ASMSpotiPageRow(@"Gestures", ^UIViewController *{ return ASMSpotiGesturesSettingsPage(); }), @"hand.tap"),
        ASMSpotiWithSymbol(ASMSpotiPageRow(@"Lyrics", ^UIViewController *{ return lyricsPage(); }), @"quote.bubble"),
        ASMSpotiWithSymbol(blocked, @"person.crop.circle.badge.xmark"),
    ])];
    NSMutableArray<ASMSpotiModRow *> *pages = [NSMutableArray array];
    if (native) {
        [pages addObject:ASMSpotiWithSymbol(ASMSpotiPageRow(@"Now playing bar", ^UIViewController *{ return ASMSpotiNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled")];
        [pages addObject:ASMSpotiWithSymbol(ASMSpotiPageRow(@"Queue & devices", ^UIViewController *{ return ASMSpotiQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward")];
    } else {
        [pages addObject:ASMSpotiWithSymbol(ASMSpotiPageRow(@"Now playing", ^UIViewController *{ return ASMSpotiRNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled")];
    }
    [pages addObject:ASMSpotiWithSymbol(ASMSpotiPageRow(@"Lock screen widget", ^UIViewController *{ return ASMSpotiLockScreenWidgetPage(); }), @"lock")];
    [sections addObject:ASMSpotiSection(nil, pages)];
    if (native) [sections addObjectsFromArray:ASMSpotiNativePlayerScreenSections()];
    // Vibrations hook Spotify's own controls and its audio, so they answer under either look.
    [sections addObjectsFromArray:ASMSpotiVibrationsSections()];

    return [[ASMSpotiModPage alloc] initWithTitle:@"Player" intro:ASMSpotiRestartNote sections:sections footer:nil];
}
