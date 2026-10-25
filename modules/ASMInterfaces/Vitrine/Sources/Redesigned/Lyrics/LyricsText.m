// What a line shows besides its words, as stored: the two switches of the lyrics menu and the order of
// sizes of the Lyrics page (LyricsText.h). The page itself is LyricsTextSettings.m.
#import "Core/ASMVitrineCore.h"
#import "LyricsText.h"

NSNotificationName const ASMVitrineRLyricsTextDidChangeNotification = @"asm.interface.vitrine.redesign.lyricsTextDidChange";

static NSString *keyOf(ASMVitrineRLyricsText text) {
    switch (text) {
        case ASMVitrineRLyricsTextLyrics: return @"lyrics";
        case ASMVitrineRLyricsTextPronunciation: return @"pronunciation";
        case ASMVitrineRLyricsTextTranslation: return @"translation";
    }
    return nil;
}

NSString *ASMVitrineRLyricsTextName(ASMVitrineRLyricsText text) {
    switch (text) {
        case ASMVitrineRLyricsTextLyrics: return @"Lyrics";
        case ASMVitrineRLyricsTextPronunciation: return @"Pronunciation";
        case ASMVitrineRLyricsTextTranslation: return @"Translation";
    }
    return nil;
}

// A stored order is taken only as a full set of the three; anything else is Apple Music's.
NSArray<NSNumber *> *ASMVitrineRLyricsTextOrder(void) {
    NSArray<NSNumber *> *fallback = @[@(ASMVitrineRLyricsTextLyrics), @(ASMVitrineRLyricsTextPronunciation), @(ASMVitrineRLyricsTextTranslation)];
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:ASMVitrineRKeyLyricsTextOrder];
    if (![stored isKindOfClass:NSArray.class] || [stored count] != fallback.count) return fallback;
    NSMutableArray<NSNumber *> *order = [NSMutableArray array];
    for (id key in stored) {
        for (NSNumber *text in fallback) {
            if ([key isEqual:keyOf(text.integerValue)] && ![order containsObject:text]) [order addObject:text];
        }
    }
    return order.count == fallback.count ? order : fallback;
}

void ASMVitrineRSetLyricsTextOrder(NSArray<NSNumber *> *order) {
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (NSNumber *text in order) [keys addObject:keyOf(text.integerValue)];
    [NSUserDefaults.standardUserDefaults setObject:keys forKey:ASMVitrineRKeyLyricsTextOrder];
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineRLyricsTextDidChangeNotification object:nil];
}

void ASMVitrineRSetLyricsTextShown(ASMVitrineRLyricsText text, BOOL shown) {
    ASMVitrineSetEnabled(text == ASMVitrineRLyricsTextTranslation ? ASMVitrineRKeyLyricsTranslation : ASMVitrineRKeyLyricsPronunciation, shown);
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineRLyricsTextDidChangeNotification object:nil];
}
