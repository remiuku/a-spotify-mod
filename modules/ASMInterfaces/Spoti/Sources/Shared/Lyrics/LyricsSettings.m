// The Lyrics page's parts; App/Pages.m assembles the page.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Lyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "Shared/LyricsSources/LyricsSources.h"

ASMSpotiModSection *ASMSpotiLyricsSourcesSection(BOOL namingSource) {
    ASMSpotiModRow *sources = ASMSpotiPageRow(@"Sources", ^UIViewController *{ return ASMSpotiLyricsSourcesPage(); });
    sources.value = ^NSString *{
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSString *key in ASMSpotiLyricsOrder()) [names addObject:ASMSpotiLyricsProviderFor(key).name];
        return names.count ? [names componentsJoinedByString:@", "] : @"Off";
    };
    NSMutableArray<ASMSpotiModRow *> *rows = [NSMutableArray arrayWithObjects:sources,
        ASMSpotiOptionRow(@"Lyrics for every track", @"Even where Spotify has none", ASMSpotiKeyLyricsAllTracks), nil];
    if (namingSource) [rows addObject:ASMSpotiOptionRow(@"Show source", nil, ASMSpotiKeyLyricsCredit)];
    return ASMSpotiSection(@"Sources", rows);
}

ASMSpotiModRow *ASMSpotiLockScreenLyricsRow(void) {
    return ASMSpotiOptionRow(@"Lock screen lyrics", @"Current line in place of the artist", ASMSpotiKeyLockScreenLyrics);
}

ASMSpotiModRow *ASMSpotiLyricsTranslationLanguageRow(void) {
    ASMSpotiModRow *row = ASMSpotiChoiceRow(@"Translation language", nil, ASMSpotiKeyLyricsTranslationLanguage, ASMSpotiLyricsTranslationLanguageNames(), 0);
    row.choiceFooter = @"Used when the lyrics come with translations. Any shows the first.";
    return row;
}

// Only the redesign's lyrics view sweeps words.
ASMSpotiModRow *ASMSpotiLyricsWordTimingRow(void) {
    return ASMSpotiOptionRow(@"Simulate word timing", nil, ASMSpotiKeyLyricsSimulateWords);
}
