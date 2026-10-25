#import "Core/ASMVitrineCore.h"
#import "Shared/AppIcon/AppIcon.h"
#import "Shared/Fonts/Fonts.h"
#import "Shared/LyricsTranslation/LyricsTranslation.h"
#import "Redesigned/Player/Player.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LyricsMeanings/Meanings.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/Sing/Sing.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Shared/LiveActivity/LiveActivity.h"
#import "Shared/Lossless/ASMVitrineLossless.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Lyrics/LyricsLook.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Redesigned/Kit/ASMVitrineRAccent.h"

NSString *const ASMVitrineRedesignedUIInfo = @"The newest version of Vitrine, leaning toward Apple Music's style. It is not compatible with the legacy look's settings.\n\nThe legacy look gives you more freedom, yet still looks like Spotify.";

// Below iOS 26 the redesign also needs ASMVitrineKeyRedesignUntested (Core/ASMVitrineUIMode.h): whoever calls this has
// shown the warning. Turning it off takes that back, so turning it on again warns again.
void ASMVitrineSetRedesignedUI(BOOL on) {
    ASMVitrineSetEnabled(ASMVitrineKeyRedesign, on);
    ASMVitrineSetEnabled(ASMVitrineKeyRedesignUntested, on && !ASMVitrineRedesignAvailable());
}

NSString *ASMVitrineRedesignUntestedWarning(void) {
    return [NSString stringWithFormat:@"The redesign is built on iOS 26's Liquid Glass. iOS %@ draws a blur in its place, and nobody has tested the redesign there: pages can be laid out wrongly, and Spotify can freeze as it starts. If Spotify does not start with it, the next launch goes back to Legacy.",
            UIDevice.currentDevice.systemVersion];
}

// The whole look changes hands at launch, so the switch asks for the restart straight away rather than
// leaving Spotify half in the old look.
static void offerRestart(BOOL on) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restart Spotify"
        message:on ? @"The redesign takes over when Spotify starts again. Spotify closes now; open it again to see it." : @"Spotify's own look comes back when Spotify starts again. Spotify closes now; open it again to see it."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { ASMVitrineRestartSpotify(); }]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

// Below iOS 26 the switch stores the warning's key, not the look's: it is on only once the warning has
// been accepted, which restarts Spotify at once, so the switch never reads on for a look that is not coming.
static ASMVitrineModRow *untestedRow(void) {
    ASMVitrineModRow *row = ASMVitrineOptionRow(@"Redesigned UI", [NSString stringWithFormat:@"Untested on iOS %@", UIDevice.currentDevice.systemVersion], ASMVitrineKeyRedesignUntested);
    row.glows = YES;
    row.info = ASMVitrineRedesignedUIInfo;
    row.changed = ^(BOOL on) {
        if (!on) {
            ASMVitrineSetRedesignedUI(NO);
            offerRestart(NO);
            return;
        }
        ASMVitrineSetEnabled(ASMVitrineKeyRedesignUntested, NO);   // the page reloads to off; the warning's button turns it on
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Turn on the redesign?"
            message:[ASMVitrineRedesignUntestedWarning() stringByAppendingString:@"\n\nSpotify restarts to turn it on."]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Turn On and Restart" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            ASMVitrineSetRedesignedUI(YES);
            ASMVitrineRestartSpotify();
        }]];
        [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
    };
    return ASMVitrineWithTile(row, @"sparkles", UIColor.systemIndigoColor);
}

ASMVitrineModRow *ASMVitrineRedesignedUIRow(void) {
    if (!ASMVitrineRedesignAvailable()) return untestedRow();
    ASMVitrineModRow *redesign = ASMVitrineOptionRow(@"Redesigned UI", nil, ASMVitrineKeyRedesign);
    redesign.glows = YES;
    redesign.info = ASMVitrineRedesignedUIInfo;
    redesign.changed = ^(BOOL on) {
        ASMVitrineSetRedesignedUI(on);
        offerRestart(on);
    };
    return ASMVitrineWithTile(redesign, @"sparkles", UIColor.systemIndigoColor);
}

// The stored look's own rows, then the font and the app icon, which work under either look on any iOS.
// Redesigned UI itself leads Mod Settings' main page.
UIViewController *ASMVitrineAppearancePage(void) {
    NSMutableArray<ASMVitrineModRow *> *everywhere = [NSMutableArray arrayWithArray:ASMVitrineAppFontRows()];
    ASMVitrineModRow *icon = ASMVitrineAppIconRow();
    if (icon) [everywhere addObject:icon];
    return [[ASMVitrineModPage alloc] initWithTitle:@"Appearance" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineSection(nil, ASMVitrineRedesignedUIStored() ? ASMVitrineRAppearanceRows() : ASMVitrineNativeAppearanceRows()),
        ASMVitrineSection(nil, everywhere),
    ] footer:nil];
}

UIViewController *ASMVitrineNavbarPage(void) {
    return ASMVitrineRedesignedUIStored() ? ASMVitrineRNavbarSettingsPage() : ASMVitrineNavbarSettingsPage();
}

// Pronunciation, romanized lines, translation, word sweeping and line meanings exist only in the redesign's lyrics view.
static UIViewController *lyricsPage(void) {
    BOOL redesigned = ASMVitrineRedesignedUIStored();
    NSMutableArray<ASMVitrineModRow *> *more = [NSMutableArray arrayWithObject:ASMVitrineLockScreenLyricsRow()];
    if (!redesigned) [more insertObject:ASMVitrineGlassLyricsRow() atIndex:0];
    ASMVitrineModRow *sing = ASMVitrinePageRow(@"Karaoke", ^UIViewController *{ return ASMVitrineSingSettingsPage(); });
    sing.value = ^NSString *{ return ASMVitrineSingSummary(); };
    NSMutableArray<ASMVitrineModSection *> *sections = [NSMutableArray arrayWithObjects:ASMVitrineSection(nil, @[ASMVitrineWithTile(sing, @"music.mic", UIColor.systemRedColor)]),
                                                ASMVitrineLyricsSourcesSection(redesigned), nil];
    ASMVitrineModSection *timing = ASMVitrineNotedSection(@"Timing", @[ASMVitrineLyricsDelayRow()],
        @"Every line shows this much later than the song, for Bluetooth headphones that play a little behind the lyrics. Applies at once.");
    if (redesigned) {
        [sections addObjectsFromArray:@[
            ASMVitrineSection(@"Display", @[ASMVitrineRLyricsTextSizesRow(), ASMVitrineLyricsWordTimingRow(), ASMVitrineLyricsRomanisedRow(),
                ASMVitrineSwitchRow(@"Hide the controls", @"A few seconds after the last touch, the lyrics take the whole player", ASMVitrineRKeyLyricsAutoHide),
                ASMVitrineSwitchRow(@"Landscape lyrics", @"Turn the phone with the lyrics open", ASMVitrineRKeyLyricsLandscape)]),
            timing,
            ASMVitrineSection(@"Translation", @[ASMVitrineLyricsTranslationLanguageRow(), ASMVitrineTranslateEverySongRow(), ASMVitrineGeminiKeyRow(), ASMVitrineSavedTranslationsRow()]),
            ASMVitrineSection(nil, @[ASMVitrineLyricsMeaningsRow()]),
        ]];
    } else {
        [sections addObject:timing];
    }
    [sections addObject:ASMVitrineSection(nil, more)];
    // The redesign's page leads with its lyrics playing in the look the page sets, and that look's presets.
    if (redesigned) return ASMVitrineRLyricsSettingsPage(@"Lyrics", @"The look applies at once. The settings below apply after you restart Spotify.", sections);
    return [[ASMVitrineModPage alloc] initWithTitle:@"Lyrics" intro:ASMVitrineRestartNote sections:sections footer:nil];
}

// Lyrics has its own row on Mod Settings' main page, beside Sing.
UIViewController *ASMVitrineLyricsSettingsPage(void) {
    return lyricsPage();
}

UIViewController *ASMVitrinePlayerSettingsPage(void) {
    ASMVitrineModRow *blocked = ASMVitrinePageRow(@"Blocked artists", ^UIViewController *{ return ASMVitrineArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return ASMVitrineFlag(ASMVitrineKeyArtistBlock, NO) ? @(ASMVitrineBlockedArtists().count).stringValue : @"Off";
    };
    BOOL native = !ASMVitrineRedesignedUIStored();

    // AirPods gestures, the lock screen widget and Vibrations have rows of their own on Mod Settings' main page.
    NSMutableArray<ASMVitrineModSection *> *sections = [NSMutableArray arrayWithObject:ASMVitrineSection(nil, @[
        ASMVitrineWithTile(ASMVitrinePageRow(@"Gestures", ^UIViewController *{ return ASMVitrineGesturesSettingsPage(); }), @"hand.tap", UIColor.systemBlueColor),
        ASMVitrineWithTile(blocked, @"person.crop.circle.badge.xmark", UIColor.systemRedColor),
    ])];
    if (native) {
        [sections addObject:ASMVitrineSection(nil, @[
            ASMVitrineWithTile(ASMVitrinePageRow(@"Now playing bar", ^UIViewController *{ return ASMVitrineNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled", UIColor.systemPinkColor),
            ASMVitrineWithTile(ASMVitrinePageRow(@"Queue & devices", ^UIViewController *{ return ASMVitrineQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward", UIColor.systemIndigoColor),
        ])];
        [sections addObjectsFromArray:ASMVitrineNativePlayerScreenSections()];
    }
    // Switch to video is the same chip of Spotify's player under either look.
    [sections addObject:ASMVitrineSection(native ? nil : @"Hide on the player", @[
        ASMVitrineHideRow(@"Switch to video", @"The chip over the title of a song with a music video", ASMVitrineKeyHideVideoSwitch),
    ])];

    [sections addObject:ASMVitrineNotedSection(@"Lossless", @[
        ASMVitrineOptionRow(@"Lossless files", @"Your own FLACs in place of Spotify's stream", ASMVitrineKeyLossless),
    ], @"Put FLAC or ALAC files in Files › Spotify › Lossless. A file plays when its title and length match the song "
       @"and its sound matches what Spotify plays, from about 4 s after the song starts or you seek. Spotify still "
       @"streams its own copy, at its lowest quality while the next song has a file. Karaoke and speeds other than "
       @"1x keep Spotify's sound. Applies after you restart Spotify.")];

    // The redesign's page leads with a card of its player and the background's control, the background's
    // rows and the Mini player section under it.
    if (!native) return ASMVitrineRPlayerSettingsPage(sections);
    return [[ASMVitrineModPage alloc] initWithTitle:@"Player" intro:ASMVitrineRestartNote sections:sections footer:nil];
}
