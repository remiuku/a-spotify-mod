// What the redesign's lyrics show of a line besides its words: the pronunciation and the translation a
// source has for it (Shared/Lyrics/Lyrics.h), each switched on from the lyrics' own menu, and the order
// of sizes the three are set in, from the Lyrics page. The switches apply at once, to every lyrics
// view there is, and are kept for the next song and the next launch.
#import <UIKit/UIKit.h>

// A line's three texts. The order puts them largest first; the lyrics are always among them.
typedef NS_ENUM(NSInteger, ASMVitrineRLyricsText) {
    ASMVitrineRLyricsTextLyrics = 0,
    ASMVitrineRLyricsTextPronunciation,
    ASMVitrineRLyricsTextTranslation,
};

#define ASMVitrineRKeyLyricsPronunciation @"asm.interface.vitrine.redesign.lyricsPronunciation"   // off until switched on
#define ASMVitrineRKeyLyricsTranslation @"asm.interface.vitrine.redesign.lyricsTranslation"       // off until switched on
// The three as the words "lyrics", "pronunciation" and "translation", largest first.
#define ASMVitrineRKeyLyricsTextOrder @"asm.interface.vitrine.redesign.lyricsTextOrder"

// Posted on the main queue when either switch or the order changes.
extern NSNotificationName const ASMVitrineRLyricsTextDidChangeNotification;

// The order, ASMVitrineRLyricsText values largest first; unset is Apple Music's: lyrics, pronunciation, translation.
NSArray<NSNumber *> *ASMVitrineRLyricsTextOrder(void);
void ASMVitrineRSetLyricsTextOrder(NSArray<NSNumber *> *order);
NSString *ASMVitrineRLyricsTextName(ASMVitrineRLyricsText text);
void ASMVitrineRSetLyricsTextShown(ASMVitrineRLyricsText text, BOOL shown);

// LyricsTextSettings.m: the Lyrics page's row for the order, which opens a list of the three to drag.
@class ASMVitrineModRow;
ASMVitrineModRow *ASMVitrineRLyricsTextSizesRow(void);
