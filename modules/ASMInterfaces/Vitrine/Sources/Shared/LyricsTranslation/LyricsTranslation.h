// A song's lines translated into any language by Gemini, on the user's own API key, at a tap in the
// lyrics' corner menu. The key lives in the Keychain, not in the settings, so a settings export never
// carries it. Only the lyrics' text and the language go out, to Google's Gemini API.
#import <UIKit/UIKit.h>

@class ASMVitrineKaraokeLine, ASMVitrineModRow;

BOOL ASMVitrineGeminiKeySet(void);

// Posted on the main thread when the saved translations are deleted or Translate any song changes: the lyrics
// page syncs its song again and redraws.
extern NSNotificationName const ASMVitrineLyricsTranslationsDidChangeNotification;

// On: the translate menu is offered for every song, not only those found in another language.
#define ASMVitrineKeyLyricsTranslateEverySong @"asm.interface.vitrine.lyrics.translateEverySong"
ASMVitrineModRow *ASMVitrineTranslateEverySongRow(void);

// One translation per line, in order, or nil and a message to show. Main queue. The same song in the
// same language is asked once a launch.
void ASMVitrineLyricsTranslateWithGemini(NSString *trackID, NSArray<ASMVitrineKaraokeLine *> *lines, NSString *languageTag,
                                 void (^done)(NSArray<NSString *> *translations, NSString *error));

// "“Title” by Artist" for a track the player or the local files know, for a translator's instructions; else nil.
NSString *ASMVitrineLyricsSongName(NSString *trackID);

// The language a translation is asked in: the Lyrics page's, else the phone's own.
NSString *ASMVitrineLyricsGeminiLanguage(void);

// Gemini's reply read: one translation per line when it has exactly `count`, else nil and in `problem`
// why not (the key, the limit, a filter, a recitation stop, a line count that does not match).
NSArray<NSString *> *ASMVitrineGeminiTranslationsIn(id root, NSInteger status, NSError *error, NSUInteger count, NSString **problem);

// The Lyrics page's row: shows whether a key is set, and sets or removes it.
ASMVitrineModRow *ASMVitrineGeminiKeyRow(void);

// On the iPhone itself (OnDeviceTranslation.swift): Apple's Translate, with both languages downloaded in the
// Translate app, and Apple Intelligence's model. Each gives one translation per line ("" for a line with no
// words), or nil and a message to show, on the main queue.
@interface ASMVitrineOnDeviceTranslation : NSObject
@property (class, readonly) BOOL translationAvailable;
+ (BOOL)appleIntelligenceAvailable:(NSString *)languageTag;
+ (void)translate:(NSArray<NSString *> *)lines to:(NSString *)languageTag done:(void (^)(NSArray<NSString *> *lines, NSString *error))done;
// Apple Intelligence works through the song a batch at a time: `progress` gets the lines so far, "" for the rest.
+ (void)translateWithAppleIntelligence:(NSArray<NSString *> *)lines to:(NSString *)languageTag song:(NSString *)song
                              progress:(void (^)(NSArray<NSString *> *lines))progress
                                  done:(void (^)(NSArray<NSString *> *lines, NSString *error))done;
@end

// SavedTranslations.m: a song's translations kept on disk by track and language, matched to lines by their text.
// The saved ones are the truth for translations made here: syncing fills the lines with no translation from them,
// and takes a made translation off a line that has none saved (after Delete). Main thread.
void ASMVitrineLyricsSyncSavedTranslation(NSString *track, NSString *language, NSArray<ASMVitrineKaraokeLine *> *lines);
void ASMVitrineLyricsSaveTranslation(NSString *track, NSString *language, NSArray<ASMVitrineKaraokeLine *> *lines);
// The Lyrics page's row: how many songs are kept, and a tap to delete them.
ASMVitrineModRow *ASMVitrineSavedTranslationsRow(void);
