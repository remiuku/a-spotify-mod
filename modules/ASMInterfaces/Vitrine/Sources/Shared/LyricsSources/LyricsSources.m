// The chain: every source in the order the Lyrics page puts them in, asked one after another, the
// first with timed lyrics answering for the track.
//
// Stopping at the first answer is what makes the lyrics card under the player appear at all. For a
// track Spotify has no lyrics of its own for, the card is only offered when the answer to Spotify's
// lyrics request arrives within about a second of the player building its list of cards; a walk that
// went on through every source for word timing took three seconds and more, and the card never came.
// So the order is the priority, as it reads on the Lyrics page: a source further down is only asked
// when those above it had nothing timed, and then only for what they lacked.
#import "Core/ASMVitrineCore.h"
#import "LyricsSources.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LocalFiles/LocalFiles.h"
#import "Shared/LocalFiles/LocalLyrics.h"
#import "Settings/ASMVitrineSourcesPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Headers/SPTPlayer.h"
#import <stdatomic.h>

static const NSTimeInterval kTimeout = 6;
static const NSUInteger kKeptTracks = 40;

// What the switches were called while Musixmatch was the only source; read once, to carry an
// existing install's settings over to the order.
static NSString *const kLegacyMusixmatch = @"asm.interface.vitrine.musixmatchLyrics";
static NSString *const kLegacyAllTracks = @"asm.interface.vitrine.musixmatchAllTracks";
static NSString *const kLegacyNetEase = @"asm.interface.vitrine.neteaseWordTiming";

@implementation ASMVitrineLyricsLink
@end

@implementation ASMVitrineLyricsResult
@end

@implementation ASMVitrineLyricsQuery
@end

@implementation ASMVitrineLyricsProvider
@end

#pragma mark - the requests the sources share

// Every request any source has lost to the network or to a server too busy to answer, counted so a
// walk can tell "no source has lyrics" from "a source could not say". Only the first is kept.
static _Atomic NSUInteger asm_vitrine_failures;

BOOL ASMVitrineLyricsReplyFailed(NSURLResponse *response, NSError *error) {
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    return error || status == 429 || status >= 500;
}

void ASMVitrineLyricsNoteReply(NSURLResponse *response, NSError *error) {
    if (ASMVitrineLyricsReplyFailed(response, error)) atomic_fetch_add(&asm_vitrine_failures, 1);
}

NSURL *ASMVitrineLyricsURL(NSString *base, NSDictionary<NSString *, NSString *> *query) {
    NSURLComponents *url = [NSURLComponents componentsWithString:base];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [query enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [items addObject:[NSURLQueryItem queryItemWithName:name value:value]];
    }];
    url.queryItems = items;
    return url.URL;
}

static NSMutableURLRequest *requestFor(NSURL *url, NSDictionary<NSString *, NSString *> *headers) {
    if (!url) return nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:kTimeout];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        [request setValue:value forHTTPHeaderField:name];
    }];
    return request;
}

// The body whatever the status, and the reply it came with; nil for both when there was none.
static void sendForReply(NSURLRequest *request, void (^done)(NSData *body, NSHTTPURLResponse *response)) {
    if (!request) {
        dispatch_async(dispatch_get_main_queue(), ^{ done(nil, nil); });
        return;
    }
    NSURL *url = request.URL;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *reply = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        ASMVitrineLyricsNoteReply(response, error);
        if (error || reply.statusCode >= 400) ASMVitrineLog(@"lyrics: %@ answered %ld, error %@", url.host, (long)reply.statusCode, error);
        dispatch_async(dispatch_get_main_queue(), ^{ done(data, reply); });
    }] resume];
}

static void send(NSURLRequest *request, void (^done)(NSData *body)) {
    sendForReply(request, ^(NSData *body, NSHTTPURLResponse *reply) {
        done(reply.statusCode >= 400 ? nil : body);
    });
}

static id jsonIn(NSData *body) {
    return body.length ? [NSJSONSerialization JSONObjectWithData:body options:0 error:nil] : nil;
}

void ASMVitrineLyricsGetJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root)) {
    send(requestFor(url, headers), ^(NSData *body) {
        done(jsonIn(body));
    });
}

void ASMVitrineLyricsGetJSONReply(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root, NSHTTPURLResponse *response)) {
    sendForReply(requestFor(url, headers), ^(NSData *body, NSHTTPURLResponse *reply) {
        done(jsonIn(body), reply);
    });
}

void ASMVitrineLyricsGetText(NSURL *url, void (^done)(NSString *text)) {
    send(requestFor(url, nil), ^(NSData *body) {
        done(body.length ? [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] : nil);
    });
}

void ASMVitrineLyricsPostJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, id body, void (^done)(id root)) {
    NSData *written = [NSJSONSerialization isValidJSONObject:body]
        ? [NSJSONSerialization dataWithJSONObject:body options:0 error:nil] : nil;
    NSMutableURLRequest *request = written ? requestFor(url, headers) : nil;
    request.HTTPMethod = @"POST";
    request.HTTPBody = written;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    send(request, ^(NSData *answer) {
        done(jsonIn(answer));
    });
}

// A pause this long between two lines gets a ♪, so Spotify's page does not hold the last one.
static const NSInteger kBreakMs = 3000;

void ASMVitrineLyricsPageLines(NSArray<ASMVitrineKaraokeLine *> *lines, NSArray<NSNumber *> **starts, NSArray<NSString *> **texts) {
    NSMutableArray<NSNumber *> *at = [NSMutableArray array];
    NSMutableArray<NSString *> *said = [NSMutableArray array];
    ASMVitrineKaraokeLine *last = nil;
    for (ASMVitrineKaraokeLine *line in lines) {
        if (last && line.start - last.end >= kBreakMs) {
            [at addObject:@(last.end)];
            [said addObject:@"♪"];
        }
        NSString *text = ASMVitrineKaraokeLineText(line);
        // The backing vocals read on the same line on Spotify's own page, which has one row a line.
        if (line.backing) text = [text stringByAppendingFormat:@" %@", ASMVitrineKaraokeLineText(line.backing)];
        [at addObject:@(line.start)];
        [said addObject:text];
        last = line;
    }
    if (last) {
        [at addObject:@(last.end)];
        [said addObject:@""];
    }
    *starts = at;
    *texts = said;
}

#pragma mark - which sources there are, and in what order

NSArray<ASMVitrineLyricsProvider *> *ASMVitrineLyricsAllProviders(void) {
    static NSArray<ASMVitrineLyricsProvider *> *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMVitrineLyricsProvider *(^make)(NSString *, NSString *, NSString *, ASMVitrineLyricsAsk) =
        ^(NSString *key, NSString *name, NSString *detail, ASMVitrineLyricsAsk ask) {
            ASMVitrineLyricsProvider *provider = [ASMVitrineLyricsProvider new];
            provider.key = key;
            provider.name = name;
            provider.detail = detail;
            // A source that matches by Spotify's own track id has everything it needs from the
            // start; the rest wait for the player to name the track before they can search.
            provider.needsName = ![key isEqualToString:@"musixmatch"] && ![key isEqualToString:ASMVitrineSpicyLyricsKey];
            provider.ask = ask;
            return provider;
        };
        all = @[
            make(@"binilyrics", @"BiniLyrics", @"Apple Music word timing", ASMVitrineBiniLyricsAsk),
            make(@"musixmatch", @"Musixmatch", @"Spotify's licensed catalog", ASMVitrineMusixmatchAsk),
            make(@"unison", @"Unison", @"Hand-timed, few tracks", ASMVitrineUnisonAsk),
            make(@"netease", @"NetEase", @"Word timing, censored", ASMVitrineNetEaseAsk),
            make(@"lrclib", @"LRCLIB", @"Line timing, open fallback", ASMVitrineLrcLibAsk),
            make(ASMVitrineSpicyLyricsKey, @"Spicy Lyrics", @"Community word syncs, your own key", ASMVitrineSpicyLyricsAsk),
            make(@"qqmusic", @"QQ Music", @"Line timing, Chinese catalog", ASMVitrineQQMusicAsk),
            make(@"kugou", @"KuGou", @"Word timing, Chinese catalog", ASMVitrineKuGouAsk),
            make(ASMVitrineImportedLRCKey, @"Imported LRC", @"Your own .lrc files", ASMVitrineImportedLRCAsk),
        ];
    });
    return all;
}

ASMVitrineLyricsProvider *ASMVitrineLyricsProviderFor(NSString *key) {
    for (ASMVitrineLyricsProvider *provider in ASMVitrineLyricsAllProviders()) {
        if ([provider.key isEqualToString:key]) return provider;
    }
    return nil;
}

// An install from before the order existed keeps what it had: the sources it was using, in the only
// order there was. Nothing is switched on for it that it had not already asked for.
static NSArray<NSString *> *fromLegacyKeys(void) {
    if (!ASMVitrineFlag(kLegacyMusixmatch, NO)) return @[];
    NSMutableArray<NSString *> *order = [NSMutableArray arrayWithObject:@"musixmatch"];
    if (ASMVitrineFlag(kLegacyNetEase, NO)) [order addObject:@"netease"];
    return order;
}

// With nothing stored and nothing to carry over, every source is on: the user's own files first, word
// timing ahead of line timing, and the two Chinese catalogs last, asked only once the rest have missed.
// Spicy Lyrics passes straight on without its key.
static NSArray<NSString *> *defaultOrder(void) {
    return @[ASMVitrineImportedLRCKey, ASMVitrineSpicyLyricsKey, @"binilyrics", @"musixmatch", @"unison", @"netease", @"lrclib", @"qqmusic", @"kugou"];
}

NSArray<NSString *> *ASMVitrineLyricsOrder(void) {
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:ASMVitrineKeyLyricsProviders];
    NSArray *legacy = fromLegacyKeys();
    NSArray *keys = [stored isKindOfClass:NSArray.class] ? stored : legacy.count ? legacy : defaultOrder();
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id key in keys) {
        if ([key isKindOfClass:NSString.class] && ASMVitrineLyricsProviderFor(key) && ![order containsObject:key]) [order addObject:key];
    }
    return order;
}

void ASMVitrineLyricsSetOrder(NSArray<NSString *> *keys) {
    [NSUserDefaults.standardUserDefaults setObject:keys ?: @[] forKey:ASMVitrineKeyLyricsProviders];
}

// With EeveeSpotify injected, its own lyrics answer Spotify's requests and the mod's stand aside: two
// tweaks holding and answering the same request froze Spotify after launch.
BOOL ASMVitrineLyricsEnabled(void) {
    return ASMVitrineLyricsOrder().count > 0 && !ASMVitrineLyricsStandAsideForEevee();
}

#pragma mark - what is known about the track

// The player knows every track it has played by name, which is what every source but Musixmatch
// searches by. The track is looked up by id rather than compared with the one playing now: a lyrics
// request often lands a beat before the player moves on to its track, and comparing then left the
// query nameless. A track the player has not reported starts with nothing, and the first source
// that matches by id fills the rest in.
static ASMVitrineLyricsQuery *queryFor(NSString *trackID) {
    ASMVitrineLyricsQuery *query = [ASMVitrineLyricsQuery new];
    query.trackID = trackID;
    // A local file is named by its own key: its tags, and the names the user gave it over them.
    NSDictionary *local = ASMVitrineLocalFileInfo(trackID);
    if (local) {
        query.title = local[@"title"];
        query.artist = local[@"artist"];
        query.album = local[@"album"];
        query.seconds = [local[@"seconds"] integerValue];
        return query;
    }
    SPTPlayerTrack *track = ASMVitrineKaraokeTrackFor(trackID);
    if (!track) return query;
    query.title = track.trackTitle;
    query.artist = track.artistName;
    NSDictionary<NSString *, NSString *> *metadata = track.metadata;
    id album = metadata[@"album_title"];
    id length = metadata[@"duration"];
    if ([album isKindOfClass:NSString.class]) query.album = album;
    if ([length respondsToSelector:@selector(integerValue)]) query.seconds = [length integerValue] / 1000;
    return query;
}

static void learnFrom(ASMVitrineLyricsQuery *query, ASMVitrineLyricsResult *result) {
    if (!query.title.length && result.title.length) query.title = result.title;
    if (!query.artist.length && result.artist.length) query.artist = result.artist;
    if (!query.album.length && result.album.length) query.album = result.album;
    if (query.seconds <= 0 && result.seconds > 0) query.seconds = result.seconds;
}

#pragma mark - the walk

// Main queue only, except asm_vitrine_missing and asm_vitrine_credits.
static NSMutableDictionary<NSString *, id> *asm_vitrine_kept;
static NSMutableDictionary<NSString *, NSMutableArray *> *asm_vitrine_waiting;
static NSMutableSet<NSString *> *asm_vitrine_missing;
static NSMutableDictionary<NSString *, NSString *> *asm_vitrine_credits;
// Spotify's own has_lyrics per track, as its metadata said. The player's metadata is read many
// times a second while a list scrolls, so a value already noted costs one lookup and no write.
static NSMutableDictionary<NSString *, NSNumber *> *asm_vitrine_spotifyHas;
static const NSUInteger kNotedTracks = 200;

static void setUp(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        asm_vitrine_kept = [NSMutableDictionary dictionary];
        asm_vitrine_waiting = [NSMutableDictionary dictionary];
        asm_vitrine_missing = [NSMutableSet set];
        asm_vitrine_credits = [NSMutableDictionary dictionary];
        asm_vitrine_spotifyHas = [NSMutableDictionary dictionary];
    });
}

// Whether the source's lines are better than what the walk already has: any lines beat none, and
// finer timing beats coarser — words timed beat a line's start, which beats plain text. Read off the
// lines themselves, which say how they were really timed, rather than off what the source claimed.
static BOOL betterLines(ASMVitrineLyricsResult *merged, ASMVitrineLyricsResult *fresh) {
    if (!fresh.karaokeLines.count) return NO;
    return !merged.karaokeLines.count || ASMVitrineKaraokeLinesTiming(fresh.karaokeLines) < ASMVitrineKaraokeLinesTiming(merged.karaokeLines);
}

static NSString *timingName(NSArray<ASMVitrineKaraokeLine *> *lines) {
    switch (ASMVitrineKaraokeLinesTiming(lines)) {
        case ASMVitrineKaraokeTimingWords: return @"word timed";
        case ASMVitrineKaraokeTimingLine: return @"line timed";
        default: return @"untimed";
    }
}

// The same for the text Spotify's own page shows: any text beats none, timed beats untimed.
static BOOL betterTexts(ASMVitrineLyricsResult *merged, ASMVitrineLyricsResult *fresh) {
    if (!fresh.texts.count) return NO;
    return !merged.texts.count || (fresh.synced && !merged.synced);
}

// How long a lyrics request waits for the player to name its track before the walk starts without a
// name. The request routinely lands a few hundred milliseconds before the player reports the track
// it belongs to, and a walk started in that gap passes over every source that searches by name.
static const NSTimeInterval kNameWait = 1.5, kNamePoll = 0.1;

static BOOL named(ASMVitrineLyricsQuery *query) {
    return query.title.length && query.artist.length;
}

// The credits that carry links or must show, by their text, as their sources answered. Main queue.
static NSMutableDictionary<NSString *, ASMVitrineLyricsResult *> *asm_vitrine_noted;
static const NSUInteger kNotedCredits = 100;

static void noteCredit(ASMVitrineLyricsResult *result) {
    if (!result.provider.length || !(result.creditRequired || result.creditLinks.count)) return;
    if (!asm_vitrine_noted) asm_vitrine_noted = [NSMutableDictionary dictionary];
    if (asm_vitrine_noted.count >= kNotedCredits) [asm_vitrine_noted removeAllObjects];
    asm_vitrine_noted[result.provider] = result;
}

BOOL ASMVitrineLyricsCreditRequired(NSString *credit) {
    return credit && asm_vitrine_noted[credit].creditRequired;
}

NSArray<ASMVitrineLyricsLink *> *ASMVitrineLyricsCreditLinks(NSString *text) {
    if (!text.length) return nil;
    ASMVitrineLyricsResult *exact = asm_vitrine_noted[text];
    if (exact) return exact.creditLinks;
    // The longest credit the text holds, so "Spicy Lyrics, synced by a" is not read as a shorter one.
    ASMVitrineLyricsResult *found = nil;
    for (NSString *credit in asm_vitrine_noted) {
        if ([text containsString:credit] && credit.length > found.provider.length) found = asm_vitrine_noted[credit];
    }
    return found.creditLinks;
}

void ASMVitrineLyricsOpenCreditLinks(NSArray<ASMVitrineLyricsLink *> *links, UIView *from) {
    if (!links.count) return;
    if (links.count == 1) {
        [UIApplication.sharedApplication openURL:links.firstObject.url options:@{} completionHandler:nil];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (ASMVitrineLyricsLink *link in links) {
        NSURL *url = link.url;
        [sheet addAction:[UIAlertAction actionWithTitle:link.title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = from;
    sheet.popoverPresentationController.sourceRect = from.bounds;
    [ASMVitrineTopController() presentViewController:sheet animated:YES completion:nil];
}

// One walk down the order for one track.
@interface ASMVitrineLyricsWalk : NSObject
@property (nonatomic, copy) NSArray<NSString *> *order;
@property (nonatomic) NSUInteger index;
@property (nonatomic, strong) ASMVitrineLyricsQuery *query;
@property (nonatomic, strong) ASMVitrineLyricsResult *merged;
// Sources that needed a name the query did not have when their turn came.
@property (nonatomic, strong) NSMutableArray<NSString *> *passedOver;
// asm_vitrine_failures when the walk started. Another walk's failure counts too, which at worst asks again.
@property (nonatomic) NSUInteger failuresAtStart;
@end

@implementation ASMVitrineLyricsWalk
@end

// Musixmatch's community translations are not waited for here: the lines take them as they are kept
// for the lyrics view (Shared/Lyrics/KaraokeSource.x), whichever source won, Spotify included.
static void finish(ASMVitrineLyricsWalk *walk) {
    ASMVitrineLyricsQuery *query = walk.query;
    ASMVitrineLyricsResult *merged = walk.merged;
    NSString *trackID = query.trackID;
    ASMVitrineLyricsResult *lyrics = merged.karaokeLines.count || merged.texts.count ? merged : nil;
    // A walk that ends with nothing is only an answer when every source got to search. One that passed a
    // source over for want of a name asked it nothing, and keeping that as "no lyrics" would stick to the
    // track: every later request would get the kept nil, and the lyrics card would be taken off the track
    // for the rest of the session. The same goes for a walk during which a request failed: a busy
    // server's 503 read as "no lyrics" hid a track's lyrics until Spotify was restarted.
    BOOL everyoneAsked = !walk.passedOver.count;
    BOOL failed = atomic_load(&asm_vitrine_failures) != walk.failuresAtStart;
    if (lyrics || (everyoneAsked && !failed) || merged.instrumental) {
        if (asm_vitrine_kept.count >= kKeptTracks) [asm_vitrine_kept removeAllObjects];
        asm_vitrine_kept[trackID] = lyrics ?: NSNull.null;
        if (!lyrics) {
            @synchronized (asm_vitrine_missing) { [asm_vitrine_missing addObject:trackID]; }
        }
    }
    ASMVitrineLog(@"lyrics: %@ ends with %@", trackID, lyrics
          ? [NSString stringWithFormat:@"%lu %@ lines from %@, %lu page lines",
             (unsigned long)lyrics.karaokeLines.count, timingName(lyrics.karaokeLines),
             lyrics.provider, (unsigned long)lyrics.texts.count]
          : everyoneAsked && failed ? @"nothing, a request failed on the way; not kept, so the next request asks again"
          : everyoneAsked ? @"nothing"
          : [NSString stringWithFormat:@"nothing, %@ never knowing its name; not kept, so the next request asks again",
             [walk.passedOver componentsJoinedByString:@", "]]);
    NSArray *waiting = asm_vitrine_waiting[trackID];
    [asm_vitrine_waiting removeObjectForKey:trackID];
    for (void (^done)(ASMVitrineLyricsResult *) in waiting) done(lyrics);
}

static void step(ASMVitrineLyricsWalk *walk) {
    ASMVitrineLyricsQuery *query = walk.query;
    ASMVitrineLyricsResult *merged = walk.merged;
    // A source higher in the order has answered with timed lyrics: that is the answer.
    if (merged.synced && merged.texts.count && merged.karaokeLines.count) {
        finish(walk);
        return;
    }
    if (walk.index >= walk.order.count) {
        // A source that matches by id named the track partway down: the ones passed over ask now,
        // in the order they came in. Once, since they cannot be passed over again with a name.
        if (walk.passedOver.count && named(query)) {
            ASMVitrineLog(@"lyrics: %@ named partway as \"%@\" by \"%@\", asking %@ after all", query.trackID,
                  query.title, query.artist, [walk.passedOver componentsJoinedByString:@", "]);
            walk.order = walk.passedOver;
            walk.index = 0;
            walk.passedOver = [NSMutableArray array];
            step(walk);
            return;
        }
        finish(walk);
        return;
    }
    ASMVitrineLyricsProvider *provider = ASMVitrineLyricsProviderFor(walk.order[walk.index++]);
    if (provider.needsName && !named(query)) {
        [walk.passedOver addObject:provider.key];
        step(walk);
        return;
    }
    provider.ask(query, ^(ASMVitrineLyricsResult *fresh) {
        learnFrom(query, fresh);
        noteCredit(fresh);
        if (fresh.instrumental) {
            ASMVitrineLog(@"lyrics: %@ is instrumental, by %@", query.trackID, provider.key);
            merged.instrumental = YES;
            finish(walk);
            return;
        }
        if (betterLines(merged, fresh)) {
            merged.karaokeLines = fresh.karaokeLines;
            merged.wordTimed = fresh.wordTimed;
            merged.provider = fresh.provider ?: provider.name;
        }
        if (betterTexts(merged, fresh)) {
            merged.starts = fresh.starts;
            merged.texts = fresh.texts;
            merged.synced = fresh.synced;
            if (!merged.provider) merged.provider = fresh.provider ?: provider.name;
            // Spotify's page names the source of its own text, which can be another than the lines'.
            merged.pageProvider = fresh.provider ?: provider.name;
        }
        step(walk);
    });
}

static void startWalk(NSString *trackID, ASMVitrineLyricsQuery *query) {
    ASMVitrineLog(@"lyrics: asking %@ for %@ as \"%@\" by \"%@\", album \"%@\", %lds",
          [ASMVitrineLyricsOrder() componentsJoinedByString:@", "], trackID, query.title, query.artist, query.album, (long)query.seconds);
    ASMVitrineLyricsWalk *walk = [ASMVitrineLyricsWalk new];
    walk.order = ASMVitrineLyricsOrder();
    walk.query = query;
    walk.merged = [ASMVitrineLyricsResult new];
    walk.passedOver = [NSMutableArray array];
    walk.failuresAtStart = atomic_load(&asm_vitrine_failures);
    step(walk);
}

// Starts the walk as soon as the player has named the track, or once it has waited long enough
// that it is not going to: a track opened for something other than what is playing is never named.
static void whenNamed(NSString *trackID, NSTimeInterval waited) {
    ASMVitrineLyricsQuery *query = queryFor(trackID);
    if (named(query) || waited >= kNameWait) {
        if (!named(query)) ASMVitrineLog(@"lyrics: the player never named %@ in %.1fs", trackID, waited);
        startWalk(trackID, query);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNamePoll * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        whenNamed(trackID, waited + kNamePoll);
    });
}

void ASMVitrineLyricsFetch(NSString *trackID, void (^done)(ASMVitrineLyricsResult *result)) {
    setUp();
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!trackID.length) {
            done(nil);
            return;
        }
        id kept = asm_vitrine_kept[trackID];
        if (kept) {
            done(kept == NSNull.null ? nil : kept);
            return;
        }
        NSMutableArray *waiting = asm_vitrine_waiting[trackID];
        if (waiting) {
            [waiting addObject:[done copy]];
            return;
        }
        asm_vitrine_waiting[trackID] = [NSMutableArray arrayWithObject:[done copy]];
        whenNamed(trackID, 0);
    });
}

BOOL ASMVitrineLyricsMayHave(NSString *trackID) {
    setUp();
    @synchronized (asm_vitrine_missing) { return ![asm_vitrine_missing containsObject:trackID]; }
}

void ASMVitrineLyricsPrefetch(NSString *trackID) {
    if (!trackID.length) return;
    ASMVitrineLyricsFetch(trackID, ^(ASMVitrineLyricsResult *result) {});
}

NSInteger ASMVitrineLyricsSpotifyHas(NSString *trackID) {
    setUp();
    if (!trackID) return -1;
    @synchronized (asm_vitrine_spotifyHas) {
        NSNumber *has = asm_vitrine_spotifyHas[trackID];
        return has ? has.integerValue : -1;
    }
}

void ASMVitrineLyricsNoteSpotifyHas(NSString *trackID, BOOL has) {
    setUp();
    if (!trackID.length) return;
    @synchronized (asm_vitrine_spotifyHas) {
        NSNumber *noted = asm_vitrine_spotifyHas[trackID];
        if (noted && noted.boolValue == has) return;
        if (asm_vitrine_spotifyHas.count >= kNotedTracks) [asm_vitrine_spotifyHas removeAllObjects];
        asm_vitrine_spotifyHas[trackID] = @(has);
    }
}

NSString *const ASMVitrineLyricsOwnRequestKey = @"asm.interface.vitrine.ownRequest";

// The cards under the player load together, and the list is shown without any card still loading
// once this many milliseconds have passed (NowPlaying_ScrollImpl's scrollCardsAsyncLoadingTimeoutMs,
// 2 s unless the server says otherwise, 1 s at the least). The lyrics card is one of them and waits
// for the color-lyrics reply, which with a source of the mod's on comes after the chain has answered;
// so the wait is set to the most the flag allows.
id ASMVitrineLyricsForcedFlag(NSString *key) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = ASMVitrineLyricsEnabled(); });
    if (!on) return nil;
    if ([key isEqualToString:@"ios-nowplaying-scroll-impl.scroll_cards_async_loading_timeout_ms"]) return @5000;
    return nil;
}

// After an override; no row shows the timeout, so nothing is locked.
__attribute__((constructor)) static void registerForcer(void) {
    return; // Host owns shared behavior.
    ASMVitrineRegisterFlagForcer(NO, ^id(NSString *key) { return ASMVitrineLyricsForcedFlag(key); }, nil);
}

#pragma mark - the language of translations

NSArray<NSString *> *ASMVitrineLyricsTranslationLanguages(void) {
    return @[@"", @"ar", @"zh-Hans", @"zh-Hant", @"cs", @"da", @"nl", @"en", @"fi", @"fr", @"de", @"el", @"he",
             @"hi", @"hu", @"id", @"it", @"ja", @"ko", @"nb", @"pl", @"pt", @"ro", @"ru", @"sk", @"es", @"sv",
             @"th", @"tr", @"uk", @"vi"];
}

NSArray<NSString *> *ASMVitrineLyricsTranslationLanguageNames(void) {
    NSLocale *english = [NSLocale localeWithLocaleIdentifier:@"en"];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *tag in ASMVitrineLyricsTranslationLanguages()) {
        [names addObject:tag.length ? [english localizedStringForLocaleIdentifier:tag] ?: tag : @"Any · iPhone's language"];
    }
    return names;
}

NSString *ASMVitrineLyricsTranslationLanguage(void) {
    NSArray<NSString *> *tags = ASMVitrineLyricsTranslationLanguages();
    NSInteger index = ASMVitrineInt(ASMVitrineKeyLyricsTranslationLanguage, 0);
    return index > 0 && index < (NSInteger)tags.count ? tags[(NSUInteger)index] : nil;
}

NSString *ASMVitrineLyricsCreditFor(NSString *trackID) {
    setUp();
    @synchronized (asm_vitrine_credits) { return trackID ? asm_vitrine_credits[trackID] : nil; }
}

void ASMVitrineLyricsSetCredit(NSString *trackID, NSString *name) {
    setUp();
    if (!trackID.length) return;
    @synchronized (asm_vitrine_credits) {
        if (asm_vitrine_credits.count >= kKeptTracks) [asm_vitrine_credits removeAllObjects];
        asm_vitrine_credits[trackID] = name ?: @"Spotify";
    }
}

// Once, at launch: the keys Musixmatch owned alone become an order, so the Lyrics page opens on what
// the install was already doing rather than on nothing.
void ASMVitrineLyricsMigrateLegacyKeys(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:ASMVitrineKeyLyricsProviders]) return;
    NSArray<NSString *> *order = fromLegacyKeys();
    if (!order.count) return;
    ASMVitrineLyricsSetOrder(order);
    ASMVitrineSetEnabled(ASMVitrineKeyLyricsAllTracks, ASMVitrineFlag(kLegacyAllTracks, NO));
    ASMVitrineLog(@"lyrics: carried the Musixmatch switches over as %@", [order componentsJoinedByString:@", "]);
}

UIViewController *ASMVitrineLyricsSourcesPage(void) {
    NSMutableArray<ASMVitrineSource *> *all = [NSMutableArray array];
    for (ASMVitrineLyricsProvider *provider in ASMVitrineLyricsAllProviders()) {
        // The page is made on every open, so a key refused since the last one says so here.
        NSString *detail = [provider.key isEqualToString:ASMVitrineSpicyLyricsKey] ? ASMVitrineSpicyLyricsStatus() ?: provider.detail : provider.detail;
        [all addObject:[ASMVitrineSource sourceWithKey:provider.key name:provider.name detail:detail]];
    }
    return ASMVitrineSourcesPageMake(@"Lyrics sources", @"Asked top to bottom until one has word timing. Sources get only the track, never your account.",
                             all, ^NSArray<NSString *> * { return ASMVitrineLyricsOrder(); }, ^(NSArray<NSString *> *keys) { ASMVitrineLyricsSetOrder(keys); });
}
