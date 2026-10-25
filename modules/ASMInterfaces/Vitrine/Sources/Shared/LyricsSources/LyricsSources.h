// Where lyrics come from. Every source answers the same question — what are this track's lines, and
// how finely are they timed — and the chain asks them in the order the Lyrics page puts them in,
// keeping the best answer rather than the first: a source with only plain text does not shut out a
// later one that times every word.
//
// ASMVitrineTTML.m reads the TTML that Apple Music's own lyrics are written in, which is what BiniLyrics and
// Unison serve. It is the only shape carrying a second voice and the (oh, aye) sung under a line; every other source times lines, or the words inside them, and nothing more.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"

// The sources in the order they are asked, as their keys. Unset means the order below, so a source
// added in a later version joins the end of everyone's list instead of shuffling it.
#define ASMVitrineKeyLyricsProviders @"asm.interface.vitrine.lyricsProviders"
// Offers the lyrics card on tracks Spotify itself has no lyrics for.
#define ASMVitrineKeyLyricsAllTracks @"asm.interface.vitrine.lyricsAllTracks"
// Names the source the shown lines came from, on the full screen page.
#define ASMVitrineKeyLyricsCredit @"asm.interface.vitrine.lyricsCredit"
// The language a line's translation is asked for in, as an index into ASMVitrineLyricsTranslationLanguages;
// unset or 0 takes whatever translation the source has.
#define ASMVitrineKeyLyricsTranslationLanguage @"asm.interface.vitrine.lyricsTranslationLanguage"

// A page a credit names someone on: "Uploader: name" and the address it opens.
@interface ASMVitrineLyricsLink : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *url;
@end

// What a source answers with, and what the chain merges several of into one.
@interface ASMVitrineLyricsResult : NSObject
// What the credit names: the source's name, unless it gave a fuller credit of its own.
@property (nonatomic, copy) NSString *provider;
// Who made the lines, linked from the credit; and whether the source's terms ask for the credit to
// show wherever its lines do, Show source or not.
@property (nonatomic, copy) NSArray<ASMVitrineLyricsLink *> *creditLinks;
@property (nonatomic) BOOL creditRequired;
// The source of the text Spotify's own page shows, when it is not the one the lines came from.
@property (nonatomic, copy) NSString *pageProvider;
@property (nonatomic) BOOL synced;                // the lines have starts of their own
@property (nonatomic) BOOL wordTimed;             // the words inside them are timed, not estimated
// Every line as Spotify's lyrics page takes it: ♪ over a break and an empty last line where the
// singing ends. Starts are in milliseconds, all 0 when not synced. nil when a source times words
// but has no text for Spotify's own page.
@property (nonatomic, copy) NSArray<NSNumber *> *starts;
@property (nonatomic, copy) NSArray<NSString *> *texts;
@property (nonatomic, copy) NSArray<ASMVitrineKaraokeLine *> *karaokeLines;
// What the source learned about the track on the way, for the sources asked after it: one that
// matched the track by Spotify's id knows the title and artist the ones searching by name need.
@property (nonatomic, copy) NSString *title, *artist, *album;
@property (nonatomic) NSInteger seconds;
@property (nonatomic) BOOL instrumental;
@end

// What is known about the track when a source is asked. Only trackID is always there; the rest is
// filled in by the player, and by whichever source answered before.
@interface ASMVitrineLyricsQuery : NSObject
@property (nonatomic, copy) NSString *trackID;   // Spotify's base62 id
@property (nonatomic, copy) NSString *title, *artist, *album;
@property (nonatomic) NSInteger seconds;
@end

// The lines as Spotify's own page takes them, ♪ over a break and an empty line at the end.
void ASMVitrineLyricsPageLines(NSArray<ASMVitrineKaraokeLine *> *lines, NSArray<NSNumber *> **starts, NSArray<NSString *> **texts);

// Calls back on the main queue, nil when the source has nothing for the track.
typedef void (^ASMVitrineLyricsAsk)(ASMVitrineLyricsQuery *query, void (^done)(ASMVitrineLyricsResult *result));

@interface ASMVitrineLyricsProvider : NSObject
@property (nonatomic, copy) NSString *key;      // stored in the order, never shown
@property (nonatomic, copy) NSString *name;     // "BiniLyrics", what the credit reads
@property (nonatomic, copy) NSString *detail;   // one line under the name on the Lyrics page
// Searches by title and artist, so it has nothing to ask with until someone has named the track.
// Musixmatch matches by Spotify's id and can go without.
@property (nonatomic) BOOL needsName;
@property (nonatomic, copy) ASMVitrineLyricsAsk ask;
@end

// Every source there is, in the order a fresh install asks them.
NSArray<ASMVitrineLyricsProvider *> *ASMVitrineLyricsAllProviders(void);
ASMVitrineLyricsProvider *ASMVitrineLyricsProviderFor(NSString *key);
// The keys in the user's order, the ones switched off left out. An empty list means the mod leaves
// Spotify's own lyrics alone.
NSArray<NSString *> *ASMVitrineLyricsOrder(void);
void ASMVitrineLyricsSetOrder(NSArray<NSString *> *keys);
BOOL ASMVitrineLyricsEnabled(void);   // any source at all is on

// Asks the sources in order and merges what they give, on the main queue. nil when none had lyrics.
void ASMVitrineLyricsFetch(NSString *trackID, void (^done)(ASMVitrineLyricsResult *result));
// NO once every source has said it has nothing for the track; safe from any thread.
BOOL ASMVitrineLyricsMayHave(NSString *trackID);
// Starts the walk for a track before anyone has asked, so the answer is in when Spotify's request
// comes; a walk already run or running is left alone. Safe from any thread.
void ASMVitrineLyricsPrefetch(NSString *trackID);
// What Spotify's own metadata says of a track: 1 has lyrics, 0 has none, -1 not seen yet. The
// player-track hook notes it; the request hook reads it to send a track Spotify has none for to
// the donor. Safe from any thread.
NSInteger ASMVitrineLyricsSpotifyHas(NSString *trackID);
void ASMVitrineLyricsNoteSpotifyHas(NSString *trackID, BOOL has);
// The remote-config values the lyrics feature forces while a source is on, nil for any other flag:
// the player gives its cards this long to load before it shows the list without the slow ones, and
// a source of the mod's can take longer than Spotify's default to answer.
id ASMVitrineLyricsForcedFlag(NSString *key);
// Set on the requests the mod sends to spclient itself, so the request hook leaves them alone.
extern NSString *const ASMVitrineLyricsOwnRequestKey;
// The name of the source the lines shown for the track came from, nil until they arrive.
NSString *ASMVitrineLyricsCreditFor(NSString *trackID);
void ASMVitrineLyricsSetCredit(NSString *trackID, NSString *name);
// What the walk learned of a credit, by its text: whether it must show, and the links it carries.
// ASMVitrineLyricsCreditLinks takes the credit or any text holding it, as Spotify's "Lyrics provided by ..."
// does. Main queue.
BOOL ASMVitrineLyricsCreditRequired(NSString *credit);
NSArray<ASMVitrineLyricsLink *> *ASMVitrineLyricsCreditLinks(NSString *text);
// Opens one link at once; two or more as an action sheet held to `from`.
void ASMVitrineLyricsOpenCreditLinks(NSArray<ASMVitrineLyricsLink *> *links, UIView *from);
// Turns an install's old Musixmatch switches into an order. Called once, before anything reads one.
void ASMVitrineLyricsMigrateLegacyKeys(void);

// The requests the sources share; each calls back on the main queue, with nil when it failed.
NSURL *ASMVitrineLyricsURL(NSString *base, NSDictionary<NSString *, NSString *> *query);
void ASMVitrineLyricsGetJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root));
// The same with the reply's status and headers, and the body read whatever the status: an error's
// body says why. response is nil when the request never got an answer.
void ASMVitrineLyricsGetJSONReply(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root, NSHTTPURLResponse *response));
void ASMVitrineLyricsGetText(NSURL *url, void (^done)(NSString *text));
// For the one source that is asked a question rather than sent to an address. body is anything
// NSJSONSerialization writes; nothing is sent at all when it is not.
void ASMVitrineLyricsPostJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, id body, void (^done)(id root));
// Every source's reply goes through this, so a walk that lost a request to the network or a busy
// server is not kept as "no lyrics". The two above call it themselves.
void ASMVitrineLyricsNoteReply(NSURLResponse *response, NSError *error);
// What it counts as lost: the network failed, or the server answered 429 or 5xx.
BOOL ASMVitrineLyricsReplyFailed(NSURLResponse *response, NSError *error);

// ASMVitrineTTML.m. Apple Music's TTML as timed lines, the voices already turned into alignments and each
// line's translation and pronunciation added where the head has them; nil when the document holds no
// line the page could show.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineTTMLLines(NSString *xml);
// The letters and digits of a text alone, lowercased: a pronunciation or a translation equal to its
// line's this way reads the same as the line and is left out.
NSString *ASMVitrineLyricsBareText(NSString *text);
// A line's pronunciation: timed `words` where the source has them, else `plain` estimated across the
// line's own time; nil when it has neither or reads the same as `of`.
ASMVitrineKaraokeLine *ASMVitrineLyricsPronunciation(NSArray<ASMVitrineKaraokeWord *> *words, NSString *plain, ASMVitrineKaraokeLine *of);

// The languages a translation can be asked for in, as language tags ("en", "es"), the first one ""
// for whatever the source has; ASMVitrineKeyLyricsTranslationLanguage indexes it, so it only ever grows at
// the end. Their names, in English, for the Lyrics page.
NSArray<NSString *> *ASMVitrineLyricsTranslationLanguages(void);
NSArray<NSString *> *ASMVitrineLyricsTranslationLanguageNames(void);
// The tag of the language asked for, nil for whatever the source has.
NSString *ASMVitrineLyricsTranslationLanguage(void);


// The sources themselves, each in its own file.
extern ASMVitrineLyricsAsk ASMVitrineBiniLyricsAsk;
extern ASMVitrineLyricsAsk ASMVitrineMusixmatchAsk;
// Musixmatch's community translations of a track into `language`, by ASMVitrineMusixmatchLineKey of each original
// line, or nil when there are none. Main queue, and at once when the answer is in. Asked once per
// track and language a launch, again only after an answer cut short.
void ASMVitrineMusixmatchTranslations(NSString *trackID, NSString *language, void (^done)(NSDictionary<NSString *, NSString *> *byLine));
NSString *ASMVitrineMusixmatchLineKey(NSString *text);
// Copies of the lines with the translations matched in, in a new array; nil when none matched.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineMusixmatchTranslatedLines(NSArray<ASMVitrineKaraokeLine *> *lines, NSDictionary<NSString *, NSString *> *byLine);
extern ASMVitrineLyricsAsk ASMVitrineUnisonAsk;
extern ASMVitrineLyricsAsk ASMVitrineNetEaseAsk;
extern ASMVitrineLyricsAsk ASMVitrineLrcLibAsk;
extern ASMVitrineLyricsAsk ASMVitrineSpicyLyricsAsk;
extern ASMVitrineLyricsAsk ASMVitrineQQMusicAsk;
extern ASMVitrineLyricsAsk ASMVitrineKuGouAsk;

// LrcLib.m. Timed LRC as a synced result, nil when no line in it is timed.
ASMVitrineLyricsResult *ASMVitrineLyricsLRCResult(NSString *lrc);
// NetEase.m. Word timed lines from NetEase's yrc, or with krc from KuGou's KRC text; nil for none.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineLyricsPieceLines(NSString *body, BOOL krc);
// QQMusic.m, for it and KuGou. A title as the two are matched by: lowercased, without spaces,
// punctuation or symbols, ideographic and full width ones included. The artist without whoever is
// featured ("A feat. B" is A). Whether a credited name and the track's artist name the same one: the
// key of either holds the other's, the featured artists left out.
NSString *ASMVitrineLyricsMatchKey(NSString *text);
NSString *ASMVitrineLyricsLeadArtist(NSString *artist);
BOOL ASMVitrineLyricsSameArtist(NSString *credited, NSString *artist);
// What the two catalogs are asked as: a browser.
#define ASMVitrineLyricsBrowserAgent @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
// KuGou.m. A download's base64 content as lines, nil when it is not KRC or holds no timed line.
NSArray<ASMVitrineKaraokeLine *> *ASMVitrineKuGouLines(NSString *content);

// SpicyLyrics.m. Its key in the order; whether the user's own API key is in the Keychain; what keeps
// it from answering, for its row on the sources page ("Needs a key", why the key was refused), nil
// while nothing does; the Lyrics page's row that sets or removes the key; and an API response as
// lines, nil when it has none.
extern NSString *const ASMVitrineSpicyLyricsKey;
BOOL ASMVitrineSpicyLyricsKeySet(void);
NSString *ASMVitrineSpicyLyricsStatus(void);
@class ASMVitrineModRow;
ASMVitrineModRow *ASMVitrineSpicyLyricsKeyRow(void);
ASMVitrineLyricsResult *ASMVitrineSpicyLyricsResult(id root);

UIViewController *ASMVitrineLyricsSourcesPage(void);   // the ordered list on the Lyrics page
