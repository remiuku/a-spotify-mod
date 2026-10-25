// The lyrics engine: timed lines and the player's clock, for the redesign's Apple Music style lyrics
// (Redesigned/Lyrics/ASMVitrineRKaraokeView.h) and the lock screen (Shared/LockScreenLyrics). Spotify only
// times whole lines, and so do many sources; every line says how finely it was really timed
// (ASMVitrineKaraokeTiming), so a line timed by the line lights up whole unless the user asks for the words
// inside it to be estimated (KaraokeTiming.m) and swept. The lines are read from the color-lyrics
// response as it arrives, or handed over by Shared/LyricsSources, and the position from the player's
// state (KaraokeSource.x).
#import <UIKit/UIKit.h>

@class ASMVitrineModRow, ASMVitrineModSection;
// LyricsSettings.m: the Lyrics page's parts (App/Pages.m puts the page together): where lyrics come
// from, naming the source (read by the redesign's lyrics view only), the lock screen, which
// language a line's translation is taken in, of those the lyrics come with, and the one Musixmatch's
// community translations are asked in (the redesign's lyrics being where translations show), whether lines timed only by the line are swept word by word, whether lines in other alphabets show again in Latin letters, and how much later than the song every line shows.
ASMVitrineModSection *ASMVitrineLyricsSourcesSection(BOOL namingSource);
ASMVitrineModRow *ASMVitrineLockScreenLyricsRow(void);
ASMVitrineModRow *ASMVitrineLyricsTranslationLanguageRow(void);
ASMVitrineModRow *ASMVitrineLyricsWordTimingRow(void);
ASMVitrineModRow *ASMVitrineLyricsRomanisedRow(void);
ASMVitrineModRow *ASMVitrineLyricsDelayRow(void);

// Shows a line written in another alphabet (Japanese, Korean, Chinese, Cyrillic, Greek, Thai, Arabic,
// Hebrew, Devanagari...) again under itself in Latin letters, before its translation. Off by default.
// Only the redesign's lyrics view draws it, and it applies at once: the switch posts the notification.
#define ASMVitrineKeyLyricsRomanised @"asm.interface.vitrine.lyricsRomanised"
extern NSNotificationName const ASMVitrineLyricsRomanisedDidChangeNotification;
// Romanise.m: the text in Latin letters, offline; nil where it has no letter of another script, or
// reads the same. `japanese` reads kanji the Japanese way, for a song ASMVitrineLyricsLooksJapanese says is
// (a line of kanji alone would read as Chinese). Safe off the main thread, and kept per text.
NSString *ASMVitrineLyricsRomanised(NSString *text, BOOL japanese);
// Whether any of the lines has kana in it.
@class ASMVitrineKaraokeLine;
BOOL ASMVitrineLyricsLooksJapanese(NSArray<ASMVitrineKaraokeLine *> *lines);

// Sweeps a line timed only by the line word by word, on the estimate of when each word is sung, as if
// the source had timed them. Off, such a line lights up whole as it starts. Off by default: the
// estimate is a guess dressed up as timing.
#define ASMVitrineKeyLyricsSimulateWords @"asm.interface.vitrine.lyricsSimulateWords"

// How finely a line was timed by where it came from. The words of a line timed by the line are still
// there, each with an estimated time, for a page that wants to sweep them anyway; a line with no time
// at all has start and end 0. Ordered finest first, so a line built from timed words is the default.
typedef NS_ENUM(NSUInteger, ASMVitrineKaraokeTiming) {
    ASMVitrineKaraokeTimingWords = 0,   // every word or syllable timed by the source
    ASMVitrineKaraokeTimingLine,        // the line's start (and maybe its end); the words estimated
    ASMVitrineKaraokeTimingNone,        // plain text, nothing timed
};

// Which edge a line is laid against. Apple Music puts a duet's second voice against the far one, so
// the two sides of the song read apart; a track sung by one voice stays leading throughout.
typedef NS_ENUM(NSUInteger, ASMVitrineKaraokeAlign) {
    ASMVitrineKaraokeAlignLeading = 0,
    ASMVitrineKaraokeAlignTrailing,
};

// Times in milliseconds from the start of the track.
@interface ASMVitrineKaraokeWord : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSInteger start, end;
// Set when nothing separates the word from the one before it, as between Japanese, Chinese or Korean
// syllables: the line lays it flush instead of leaving a space for a word break that is not there.
@property (nonatomic) BOOL joined;
@end

// A copy shares the words, the backing and the pronunciation, which nothing changes once a line is
// built; a translation set on the copy leaves the original as it was.
@interface ASMVitrineKaraokeLine : NSObject <NSCopying>
@property (nonatomic, copy) NSArray<ASMVitrineKaraokeWord *> *words;
@property (nonatomic) NSInteger start, end;
// The voice singing the line, named as the source names it ("v1", "v2"), nil when it names none.
// ASMVitrineKaraokeAlignVoices turns these into alignments; nothing else reads it.
@property (nonatomic, copy) NSString *voice;
@property (nonatomic) ASMVitrineKaraokeAlign align;
// How finely the source timed it; the words of a line built here from timed words are timed.
@property (nonatomic) ASMVitrineKaraokeTiming timing;
// The (oh, aye) sung under the line, smaller and dimmer, nil for nearly every line. Its words are
// timed like any other and it is lit by the same sweep, a beat behind the line it hangs off.
@property (nonatomic, strong) ASMVitrineKaraokeLine *backing;
// How the line sounds, written in the Latin alphabet (Apple Music's pronunciation): its words sung
// at the times of the line's own, each starting with the word it spells, and the backing's under the
// backing. nil where the source has none, or where it reads the same as the line.
@property (nonatomic, strong) ASMVitrineKaraokeLine *pronunciation;
// The line in another language, the backing's words with it; nil where the source has none.
@property (nonatomic, copy) NSString *translation;
// The translation came from a translator of the lyrics' menu (LyricsTranslation), not from the lyrics' source.
@property (nonatomic) BOOL translationMade;
@end

// The line as one string, a space between the words that are not joined.
NSString *ASMVitrineKaraokeLineText(ASMVitrineKaraokeLine *line);
// When the singing of a line is over: its own end, or its backing's when that runs on past it.
NSInteger ASMVitrineKaraokeSungEnd(ASMVitrineKaraokeLine *line);
// The one line a place with room for one names as the one being sung at `ms`. Two voices can sing
// over each other, and a line another voice comes in over keeps its place until it is sung out, so
// this is the earliest line still being sung; between lines, the last one begun; -1 before the first.
// The lock screen and the Live Activity show this one.
NSInteger ASMVitrineKaraokeLeadLine(NSArray<ASMVitrineKaraokeLine *> *lines, NSInteger ms);
// Whether the text is written in a script that does not space its words, so the pieces of a line
// are words in their own right rather than halves of one.
BOOL ASMVitrineKaraokeUnspacedScript(NSString *text);
// Gives every line the alignment its voice earns: the voice heard first leads, the next one to be
// named trails, and any after that lead again. A track naming one voice or none is left alone.
void ASMVitrineKaraokeAlignVoices(NSArray<ASMVitrineKaraokeLine *> *lines);

// A color-lyrics body, protobuf or JSON, as lines: timed by the line where Spotify synced it, plain
// (ASMVitrineKaraokeTimingNone) where it did not; nil for a body with no lines.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKaraokeLinesFromBody(NSData *body);
// Lines timed only by their starts, the words inside them estimated; a ♪ or empty text is a break.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKaraokeEstimatedLines(NSArray<NSNumber *> *starts, NSArray<NSString *> *texts);
// Lines with no time at all, for lyrics that come as plain text; a ♪ or empty text is dropped.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKaraokeStaticLines(NSArray<NSString *> *texts);
// The finest timing any of the lines has; ASMVitrineKaraokeTimingNone for none at all.
ASMVitrineKaraokeTiming ASMVitrineKaraokeLinesTiming(NSArray<ASMVitrineKaraokeLine *> *lines);
// The lines in the order they start, lines starting together kept as they came; the array itself when
// it is in order already, which it nearly always is.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKaraokeInTimeOrder(NSArray<ASMVitrineKaraokeLine *> *lines);

NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKaraokeLinesForTrack(NSString *trackID);   // nil until the lyrics came
void ASMVitrineKaraokeKeepLines(NSString *trackID, NSArray<ASMVitrineKaraokeLine *> *lines);
// Posted on the main queue, object the track's id as ASMVitrineKaraokePlayingTrack names it, when lines are kept
// for it, and when a look for its lyrics (ASMVitrineKaraokeLooking) ends with none, so a reader waiting on one
// learns the look is over.
extern NSNotificationName const ASMVitrineKaraokeLinesKeptNotification;
// Whether the track's lyrics are being asked for at this moment, of the sources or of spclient after
// them: the ask in flight, not the pause before a lost one is asked again. A local file's walk can take
// tens of seconds. A walk LyricsSources runs for Spotify's own request is not seen here. Main queue.
BOOL ASMVitrineKaraokeLooking(NSString *trackID);
// The headers spclient needs to answer a request as the signed-in app, read off Spotify's own requests:
// `use` runs at once when one has been seen, else with the first. Never logged or stored. Main queue.
void ASMVitrineSpclientHeaders(void (^use)(NSDictionary<NSString *, NSString *> *headers));
// Asks spclient for a track's lyrics once, with the headers of Spotify's own requests, for when no
// page of Spotify's has asked for them, e.g. with the app in the background.
void ASMVitrineKaraokeRequestLyrics(NSString *trackID);
// Asks Spotify's JSON lyrics for the track once, and keeps its lines only if they are more finely
// timed than the ones kept: the lyrics view was left with plain text, and Spotify may have it timed.
void ASMVitrineKaraokeAskSpotifyForTiming(NSString *trackID);
// Whether EeveeSpotify is injected alongside the mod.
BOOL ASMVitrineEeveeSpotifyInjected(void);
// EeveeSpotify is injected and answers Spotify's lyrics, by its own settings (lyricsSource, and
// patchType in its Reincarnated fork). Both answering the same request froze Spotify after launch, so
// then the mod's sources and its own requests for Spotify's lyrics stand aside (LyricsSources'
// ASMVitrineLyricsEnabled, ASMVitrineKaraokeRequestLyrics). Its settings are read once, as it reads them at launch.
BOOL ASMVitrineEeveeLyricsOn(void);
// The Lyrics page's "Use these sources anyway", for an EeveeSpotify whose settings read wrong.
#define ASMVitrineKeyLyricsBesideEevee @"asm.interface.vitrine.lyrics.besideEevee"
// ASMVitrineEeveeLyricsOn, unless the user asked for the mod's sources beside it.
BOOL ASMVitrineLyricsStandAsideForEevee(void);
// The base62 id, a local file's lyrics key (Shared/LocalFiles), nil before the player reported.
NSString *ASMVitrineKaraokePlayingTrack(void);
NSInteger ASMVitrineKaraokePositionMs(void);     // negative when unknown
// The Lyrics page's Delay: every line shows this many ms later than the song, for headphones that play
// behind it. Whatever times lines against the position compares them with the position less this, and a
// tap on a line seeks to its start plus this. Read at every call, so a change applies at once.
#define ASMVitrineKeyLyricsDelay @"asm.interface.vitrine.lyricsDelay"
NSInteger ASMVitrineKaraokeDelayMs(void);
void ASMVitrineKaraokeSeek(NSInteger ms);
id ASMVitrineKaraokePlayer(void);                // SPTEsperantoPlayer, nil before the app asked it for its state
// A track the player has reported, by its base62 id; nil for one it has not played this session.
@class SPTPlayerTrack;
SPTPlayerTrack *ASMVitrineKaraokeTrackFor(NSString *trackID);
// Keeps a track seen elsewhere, so a source can name it before the player has reported it.
void ASMVitrineKaraokeRememberTrack(SPTPlayerTrack *track);
