// The Lyrics page's parts; App/Pages.m assembles the page.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Lyrics.h"
#import "Shared/LocalFiles/LocalLyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

ASMVitrineModSection *ASMVitrineLyricsSourcesSection(BOOL namingSource) {
    ASMVitrineModRow *sources = ASMVitrinePageRow(@"Sources", ^UIViewController *{ return ASMVitrineLyricsSourcesPage(); });
    sources.value = ^NSString *{
        // The first one asked and how many follow it, short enough to sit beside the title.
        NSArray<NSString *> *order = ASMVitrineLyricsOrder();
        if (!order.count) return @"Off";
        NSString *first = ASMVitrineLyricsProviderFor(order.firstObject).name;
        return order.count == 1 ? first : [NSString stringWithFormat:@"%@ +%lu", first, (unsigned long)order.count - 1];
    };
    ASMVitrineModRow *imported = ASMVitrinePageRow(@"Imported LRC files", ^UIViewController *{ return ASMVitrineImportedLRCPage(); });
    imported.value = ^NSString *{
        NSUInteger count = ASMVitrineImportedLRCFiles().count;
        return count ? @(count).stringValue : @"None";
    };
    NSMutableArray<ASMVitrineModRow *> *rows = [NSMutableArray arrayWithObjects:sources, imported,
        ASMVitrineSwitchRow(@"Lyrics for every track", @"Even where Spotify has none", ASMVitrineKeyLyricsAllTracks), ASMVitrineSpicyLyricsKeyRow(), nil];
    // Spicy Lyrics' terms ask for its credit wherever its lines show (Shared/LyricsSources/SpicyLyrics.m), so the switch
    // says so, or its credit under the lyrics reads as the switch not working (issue #20).
    if (namingSource) [rows addObject:ASMVitrineOptionRow(@"Show source", @"Spicy Lyrics is always credited after the last line: its terms ask for it", ASMVitrineKeyLyricsCredit)];
    if (ASMVitrineEeveeLyricsOn()) {
        [rows addObject:ASMVitrineOptionRow(@"Use these sources anyway", @"Only if EeveeSpotify's lyrics are really off", ASMVitrineKeyLyricsBesideEevee)];
        return ASMVitrineNotedSection(@"Sources", rows, @"EeveeSpotify's lyrics are on, so it answers Spotify's lyrics and these sources stay "
                                                @"off: both answering froze Spotify after launch. Turn its lyrics off in its own "
                                                @"settings to use these.");
    }
    return ASMVitrineSection(@"Sources", rows);
}

ASMVitrineModRow *ASMVitrineLockScreenLyricsRow(void) {
    return ASMVitrineOptionRow(@"Lock screen lyrics", @"Current line in place of the artist", ASMVitrineKeyLockScreenLyrics);
}

ASMVitrineModRow *ASMVitrineLyricsTranslationLanguageRow(void) {
    ASMVitrineModRow *row = ASMVitrineChoiceRow(@"Translation language", nil, ASMVitrineKeyLyricsTranslationLanguage, ASMVitrineLyricsTranslationLanguageNames(), 0);
    row.choiceFooter = @"A language brings Musixmatch's community translations to lyrics that have none, "
                       @"which sends Musixmatch each song's ID. Any shows the first translation the lyrics come with. "
                       @"It is also the language the lyrics' translate menu translates into, offered only for songs in another one; "
                       @"with Any, the iPhone's own language.";
    return row;
}

// Only the redesign's lyrics view draws it, and every one there is redrawn as the switch flips.
ASMVitrineModRow *ASMVitrineLyricsRomanisedRow(void) {
    ASMVitrineModRow *row = ASMVitrineOptionRow(@"Romanized lyrics", @"Lines in other alphabets, again in Latin letters", ASMVitrineKeyLyricsRomanised);
    row.changed = ^(BOOL on) {
        [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineLyricsRomanisedDidChangeNotification object:nil];
    };
    return row;
}

// Only the redesign's lyrics view sweeps words.
ASMVitrineModRow *ASMVitrineLyricsWordTimingRow(void) {
    return ASMVitrineOptionRow(@"Simulate word timing", nil, ASMVitrineKeyLyricsSimulateWords);
}

// Read wherever lines are timed, so it applies as the thumb moves.
ASMVitrineModRow *ASMVitrineLyricsDelayRow(void) {
    return ASMVitrineSliderRow(@"Delay", nil, 0, 1000, 25, ^double { return ASMVitrineKaraokeDelayMs(); },
                       ^(double value) { ASMVitrineSetInt(ASMVitrineKeyLyricsDelay, lround(value)); },
                       ^NSString *(double value) { return [NSString stringWithFormat:@"%ld ms", lround(value)]; });
}
