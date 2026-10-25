// Where lyrics come from. Every source answers the same question — what are this track's lines, and
// how finely are they timed — and the chain asks them in the order the Lyrics page puts them in,
// keeping the best answer rather than the first: a source with only plain text does not shut out a
// later one that times every word.
//
// ASMSpotiTTML.m reads the TTML that Apple Music's own lyrics are written in, which is what BiniLyrics and
// Unison serve. It and Spicy Lyrics are the only shapes carrying a second voice and the (oh, aye)
// sung under a line; every other source times lines, or the words inside them, and nothing more.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"

// The sources in the order they are asked, as their keys. Unset means the order below, so a source
// added in a later version joins the end of everyone's list instead of shuffling it.
#define ASMSpotiKeyLyricsProviders @"asm.interface.spotipw.lyricsProviders"
// Offers the lyrics card on tracks Spotify itself has no lyrics for.
#define ASMSpotiKeyLyricsAllTracks @"asm.interface.spotipw.lyricsAllTracks"
// Names the source the shown lines came from, on the full screen page.
#define ASMSpotiKeyLyricsCredit @"asm.interface.spotipw.lyricsCredit"
// The language a line's translation is asked for in, as an index into ASMSpotiLyricsTranslationLanguages;
// unset or 0 takes whatever translation the source has.
#define ASMSpotiKeyLyricsTranslationLanguage @"asm.interface.spotipw.lyricsTranslationLanguage"

// What a source answers with, and what the chain merges several of into one.
@interface ASMSpotiLyricsResult : NSObject
@property (nonatomic, copy) NSString *provider;   // the key of the source the lines came from
@property (nonatomic) BOOL synced;                // the lines have starts of their own
@property (nonatomic) BOOL wordTimed;             // the words inside them are timed, not estimated
// Every line as Spotify's lyrics page takes it: ♪ over a break and an empty last line where the
// singing ends. Starts are in milliseconds, all 0 when not synced. nil when a source times words
// but has no text for Spotify's own page.
@property (nonatomic, copy) NSArray<NSNumber *> *starts;
@property (nonatomic, copy) NSArray<NSString *> *texts;
@property (nonatomic, copy) NSArray<ASMSpotiKaraokeLine *> *karaokeLines;
// What the source learned about the track on the way, for the sources asked after it: one that
// matched the track by Spotify's id knows the title and artist the ones searching by name need.
@property (nonatomic, copy) NSString *title, *artist, *album;
@property (nonatomic) NSInteger seconds;
@property (nonatomic) BOOL instrumental;
@end

// What is known about the track when a source is asked. Only trackID is always there; the rest is
// filled in by the player, and by whichever source answered before.
@interface ASMSpotiLyricsQuery : NSObject
@property (nonatomic, copy) NSString *trackID;   // Spotify's base62 id
@property (nonatomic, copy) NSString *title, *artist, *album;
@property (nonatomic) NSInteger seconds;
@end

// The lines as Spotify's own page takes them, ♪ over a break and an empty line at the end.
void ASMSpotiLyricsPageLines(NSArray<ASMSpotiKaraokeLine *> *lines, NSArray<NSNumber *> **starts, NSArray<NSString *> **texts);

// Calls back on the main queue, nil when the source has nothing for the track.
typedef void (^ASMSpotiLyricsAsk)(ASMSpotiLyricsQuery *query, void (^done)(ASMSpotiLyricsResult *result));

@interface ASMSpotiLyricsProvider : NSObject
@property (nonatomic, copy) NSString *key;      // stored in the order, never shown
@property (nonatomic, copy) NSString *name;     // "BiniLyrics", what the credit reads
@property (nonatomic, copy) NSString *detail;   // one line under the name on the Lyrics page
// Searches by title and artist, so it has nothing to ask with until someone has named the track.
// Musixmatch and Spicy Lyrics match by Spotify's id and can go without.
@property (nonatomic) BOOL needsName;
@property (nonatomic, copy) ASMSpotiLyricsAsk ask;
@end

// Every source there is, in the order a fresh install asks them.
NSArray<ASMSpotiLyricsProvider *> *ASMSpotiLyricsAllProviders(void);
ASMSpotiLyricsProvider *ASMSpotiLyricsProviderFor(NSString *key);
// The keys in the user's order, the ones switched off left out. An empty list means the mod leaves
// Spotify's own lyrics alone.
NSArray<NSString *> *ASMSpotiLyricsOrder(void);
void ASMSpotiLyricsSetOrder(NSArray<NSString *> *keys);
BOOL ASMSpotiLyricsEnabled(void);   // any source at all is on

// Asks the sources in order and merges what they give, on the main queue. nil when none had lyrics.
void ASMSpotiLyricsFetch(NSString *trackID, void (^done)(ASMSpotiLyricsResult *result));
// NO once every source has said it has nothing for the track; safe from any thread.
BOOL ASMSpotiLyricsMayHave(NSString *trackID);
// Starts the walk for a track before anyone has asked, so the answer is in when Spotify's request
// comes; a walk already run or running is left alone. Safe from any thread.
void ASMSpotiLyricsPrefetch(NSString *trackID);
// What Spotify's own metadata says of a track: 1 has lyrics, 0 has none, -1 not seen yet. The
// player-track hook notes it; the request hook reads it to send a track Spotify has none for to
// the donor. Safe from any thread.
NSInteger ASMSpotiLyricsSpotifyHas(NSString *trackID);
void ASMSpotiLyricsNoteSpotifyHas(NSString *trackID, BOOL has);
// The remote-config values the lyrics feature forces while a source is on, nil for any other flag:
// the player gives its cards this long to load before it shows the list without the slow ones, and
// a source of the mod's can take longer than Spotify's default to answer.
id ASMSpotiLyricsForcedFlag(NSString *key);
// Set on the requests the mod sends to spclient itself, so the request hook leaves them alone.
extern NSString *const ASMSpotiLyricsOwnRequestKey;
// The name of the source the lines shown for the track came from, nil until they arrive.
NSString *ASMSpotiLyricsCreditFor(NSString *trackID);
void ASMSpotiLyricsSetCredit(NSString *trackID, NSString *name);
// Turns an install's old Musixmatch switches into an order. Called once, before anything reads one.
void ASMSpotiLyricsMigrateLegacyKeys(void);

// The requests the sources share; each calls back on the main queue, with nil when it failed.
NSURL *ASMSpotiLyricsURL(NSString *base, NSDictionary<NSString *, NSString *> *query);
void ASMSpotiLyricsGetJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root));
void ASMSpotiLyricsGetText(NSURL *url, void (^done)(NSString *text));
// For the one source that is asked a question rather than sent to an address. body is anything
// NSJSONSerialization writes; nothing is sent at all when it is not.
void ASMSpotiLyricsPostJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, id body, void (^done)(id root));
// Every source's reply goes through this, so a walk that lost a request to the network or a busy
// server is not kept as "no lyrics". The two above call it themselves.
void ASMSpotiLyricsNoteReply(NSURLResponse *response, NSError *error);

// ASMSpotiTTML.m. Apple Music's TTML as timed lines, the voices already turned into alignments and each
// line's translation and pronunciation added where the head has them; nil when the document holds no
// line the page could show.
NSArray<ASMSpotiKaraokeLine *> *ASMSpotiTTMLLines(NSString *xml);

// The languages a translation can be asked for in, as language tags ("en", "es"), the first one ""
// for whatever the source has; ASMSpotiKeyLyricsTranslationLanguage indexes it, so it only ever grows at
// the end. Their names, in English, for the Lyrics page.
NSArray<NSString *> *ASMSpotiLyricsTranslationLanguages(void);
NSArray<NSString *> *ASMSpotiLyricsTranslationLanguageNames(void);
// The tag of the language asked for, nil for whatever the source has.
NSString *ASMSpotiLyricsTranslationLanguage(void);


// The sources themselves, each in its own file.
extern ASMSpotiLyricsAsk ASMSpotiBiniLyricsAsk;
extern ASMSpotiLyricsAsk ASMSpotiMusixmatchAsk;
extern ASMSpotiLyricsAsk ASMSpotiUnisonAsk;
extern ASMSpotiLyricsAsk ASMSpotiNetEaseAsk;
extern ASMSpotiLyricsAsk ASMSpotiLrcLibAsk;
extern ASMSpotiLyricsAsk ASMSpotiSpicyLyricsAsk;

UIViewController *ASMSpotiLyricsSourcesPage(void);   // the ordered list on the Lyrics page
