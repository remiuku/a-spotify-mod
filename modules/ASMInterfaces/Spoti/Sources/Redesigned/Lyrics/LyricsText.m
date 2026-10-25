// What a line shows besides its words, as stored: the two switches of the lyrics menu and the order of
// sizes of the Lyrics page (LyricsText.h). The page itself is LyricsTextSettings.m.
#import "Core/ASMSpotiCore.h"
#import "LyricsText.h"

NSNotificationName const ASMSpotiRLyricsTextDidChangeNotification = @"asm.interface.spotipw.redesign.lyricsTextDidChange";

static NSString *keyOf(ASMSpotiRLyricsText text) {
    switch (text) {
        case ASMSpotiRLyricsTextLyrics: return @"lyrics";
        case ASMSpotiRLyricsTextPronunciation: return @"pronunciation";
        case ASMSpotiRLyricsTextTranslation: return @"translation";
    }
    return nil;
}

NSString *ASMSpotiRLyricsTextName(ASMSpotiRLyricsText text) {
    switch (text) {
        case ASMSpotiRLyricsTextLyrics: return @"Lyrics";
        case ASMSpotiRLyricsTextPronunciation: return @"Pronunciation";
        case ASMSpotiRLyricsTextTranslation: return @"Translation";
    }
    return nil;
}

// A stored order is taken only as a full set of the three; anything else is Apple Music's.
NSArray<NSNumber *> *ASMSpotiRLyricsTextOrder(void) {
    NSArray<NSNumber *> *fallback = @[@(ASMSpotiRLyricsTextLyrics), @(ASMSpotiRLyricsTextPronunciation), @(ASMSpotiRLyricsTextTranslation)];
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:ASMSpotiRKeyLyricsTextOrder];
    if (![stored isKindOfClass:NSArray.class] || [stored count] != fallback.count) return fallback;
    NSMutableArray<NSNumber *> *order = [NSMutableArray array];
    for (id key in stored) {
        for (NSNumber *text in fallback) {
            if ([key isEqual:keyOf(text.integerValue)] && ![order containsObject:text]) [order addObject:text];
        }
    }
    return order.count == fallback.count ? order : fallback;
}

void ASMSpotiRSetLyricsTextOrder(NSArray<NSNumber *> *order) {
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (NSNumber *text in order) [keys addObject:keyOf(text.integerValue)];
    [NSUserDefaults.standardUserDefaults setObject:keys forKey:ASMSpotiRKeyLyricsTextOrder];
    [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiRLyricsTextDidChangeNotification object:nil];
}

void ASMSpotiRSetLyricsTextShown(ASMSpotiRLyricsText text, BOOL shown) {
    ASMSpotiSetEnabled(text == ASMSpotiRLyricsTextTranslation ? ASMSpotiRKeyLyricsTranslation : ASMSpotiRKeyLyricsPronunciation, shown);
    [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiRLyricsTextDidChangeNotification object:nil];
}
