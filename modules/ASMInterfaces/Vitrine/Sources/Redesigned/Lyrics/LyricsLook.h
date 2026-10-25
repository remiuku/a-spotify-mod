// How the redesign's lyrics are set, from the Lyrics page: the size of the words, the room between two
// lines, how strongly the lines away from the one sung blur, and how strongly a held word glows and its
// letters wave. A preset sets all five, the sheet of sliders each one; they apply at once to every lyrics
// view there is, the Lyrics page's own preview among them (LyricsLookSettings.m).
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"

// size and spacing in points; blur, glow and wave as shares of Apple Music's, 1 being theirs and 0 none.
typedef struct {
    CGFloat size, spacing, blur, glow, wave;
} ASMVitrineRLyricsLook;

// The five as one dictionary; unset is the first preset, Apple Music's.
#define ASMVitrineRKeyLyricsLook @"asm.interface.vitrine.redesign.lyricsLook"

// Posted on the main queue when the look changes; the object is whoever changed it, nil for none named.
extern NSNotificationName const ASMVitrineRLyricsLookDidChangeNotification;

ASMVitrineRLyricsLook ASMVitrineRLyricsLookNow(void);
void ASMVitrineRSetLyricsLook(ASMVitrineRLyricsLook look, id changer);

// The presets, by name, Apple Music's first.
NSArray<NSString *> *ASMVitrineRLyricsLookPresetNames(void);
ASMVitrineRLyricsLook ASMVitrineRLyricsLookPreset(NSUInteger index);
// The preset the look is, or -1 for a look of the sliders' own.
NSInteger ASMVitrineRLyricsLookPresetIndex(ASMVitrineRLyricsLook look);

// A few lines of the preview's own, words timed, one held long enough to glow and wave, and how long
// they take to come round again.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineRLyricsSampleLines(void);
NSInteger ASMVitrineRLyricsSampleLength(void);

// LyricsLookSettings.m: the Lyrics page in the redesign, leading with the preview, the presets under it
// and their sliders in a sheet, then `sections`.
@class ASMVitrineModSection;
UIViewController *ASMVitrineRLyricsSettingsPage(NSString *title, NSString *intro, NSArray<ASMVitrineModSection *> *sections);
