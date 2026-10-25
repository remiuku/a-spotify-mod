// What the redesign's lyrics show of a line besides its words: the pronunciation and the translation a
// source has for it (Shared/Lyrics/Lyrics.h), each switched on from the lyrics' own menu, and the order
// of sizes the three are set in, from the Lyrics page. The switches apply at once, to every lyrics
// view there is, and are kept for the next song and the next launch.
#import <UIKit/UIKit.h>

// A line's three texts. The order puts them largest first; the lyrics are always among them.
typedef NS_ENUM(NSInteger, ASMSpotiRLyricsText) {
    ASMSpotiRLyricsTextLyrics = 0,
    ASMSpotiRLyricsTextPronunciation,
    ASMSpotiRLyricsTextTranslation,
};

#define ASMSpotiRKeyLyricsPronunciation @"asm.interface.spotipw.redesign.lyricsPronunciation"   // off until switched on
#define ASMSpotiRKeyLyricsTranslation @"asm.interface.spotipw.redesign.lyricsTranslation"       // off until switched on
// The three as the words "lyrics", "pronunciation" and "translation", largest first.
#define ASMSpotiRKeyLyricsTextOrder @"asm.interface.spotipw.redesign.lyricsTextOrder"

// Posted on the main queue when either switch or the order changes.
extern NSNotificationName const ASMSpotiRLyricsTextDidChangeNotification;

// The order, ASMSpotiRLyricsText values largest first; unset is Apple Music's: lyrics, pronunciation, translation.
NSArray<NSNumber *> *ASMSpotiRLyricsTextOrder(void);
void ASMSpotiRSetLyricsTextOrder(NSArray<NSNumber *> *order);
NSString *ASMSpotiRLyricsTextName(ASMSpotiRLyricsText text);
void ASMSpotiRSetLyricsTextShown(ASMSpotiRLyricsText text, BOOL shown);

// LyricsTextSettings.m: the Lyrics page's row for the order, which opens a list of the three to drag.
@class ASMSpotiModRow;
ASMSpotiModRow *ASMSpotiRLyricsTextSizesRow(void);
