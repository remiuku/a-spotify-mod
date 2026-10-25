// The chain: every source in the order the Lyrics page puts them in, asked one after another, the
// first with timed lyrics answering for the track.
//
// Stopping at the first answer is what makes the lyrics card under the player appear at all. For a
// track Spotify has no lyrics of its own for, the card is only offered when the answer to Spotify's
// lyrics request arrives within about a second of the player building its list of cards; a walk that
// went on through every source for word timing took three seconds and more, and the card never came.
// So the order is the priority, as it reads on the Lyrics page: a source further down is only asked
// when those above it had nothing timed, and then only for what they lacked.
#import "Core/ASMSpotiCore.h"
#import "LyricsSources.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Headers/SPTPlayer.h"
#import <stdatomic.h>

static const NSTimeInterval kTimeout = 6;
static const NSUInteger kKeptTracks = 40;

// What the switches were called while Musixmatch was the only source; read once, to carry an
// existing install's settings over to the order.
static NSString *const kLegacyMusixmatch = @"asm.interface.spotipw.musixmatchLyrics";
static NSString *const kLegacyAllTracks = @"asm.interface.spotipw.musixmatchAllTracks";
static NSString *const kLegacyNetEase = @"asm.interface.spotipw.neteaseWordTiming";

@implementation ASMSpotiLyricsResult
@end

@implementation ASMSpotiLyricsQuery
@end

@implementation ASMSpotiLyricsProvider
@end

#pragma mark - the requests the sources share

// Every request any source has lost to the network or to a server too busy to answer, counted so a
// walk can tell "no source has lyrics" from "a source could not say". Only the first is kept.
static _Atomic NSUInteger asm_spotipw_failures;

void ASMSpotiLyricsNoteReply(NSURLResponse *response, NSError *error) {
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    if (error || status == 429 || status >= 500) atomic_fetch_add(&asm_spotipw_failures, 1);
}

NSURL *ASMSpotiLyricsURL(NSString *base, NSDictionary<NSString *, NSString *> *query) {
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

static void send(NSURLRequest *request, void (^done)(NSData *body)) {
    if (!request) {
        dispatch_async(dispatch_get_main_queue(), ^{ done(nil); });
        return;
    }
    NSURL *url = request.URL;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        ASMSpotiLyricsNoteReply(response, error);
        if (error || status >= 400) ASMSpotiLog(@"lyrics: %@ answered %ld, error %@", url.host, (long)status, error);
        dispatch_async(dispatch_get_main_queue(), ^{ done(status >= 400 ? nil : data); });
    }] resume];
}

static id jsonIn(NSData *body) {
    return body.length ? [NSJSONSerialization JSONObjectWithData:body options:0 error:nil] : nil;
}

void ASMSpotiLyricsGetJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, void (^done)(id root)) {
    send(requestFor(url, headers), ^(NSData *body) {
        done(jsonIn(body));
    });
}

void ASMSpotiLyricsGetText(NSURL *url, void (^done)(NSString *text)) {
    send(requestFor(url, nil), ^(NSData *body) {
        done(body.length ? [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] : nil);
    });
}

void ASMSpotiLyricsPostJSON(NSURL *url, NSDictionary<NSString *, NSString *> *headers, id body, void (^done)(id root)) {
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

void ASMSpotiLyricsPageLines(NSArray<ASMSpotiKaraokeLine *> *lines, NSArray<NSNumber *> **starts, NSArray<NSString *> **texts) {
    NSMutableArray<NSNumber *> *at = [NSMutableArray array];
    NSMutableArray<NSString *> *said = [NSMutableArray array];
    ASMSpotiKaraokeLine *last = nil;
    for (ASMSpotiKaraokeLine *line in lines) {
        if (last && line.start - last.end >= kBreakMs) {
            [at addObject:@(last.end)];
            [said addObject:@"♪"];
        }
        NSString *text = ASMSpotiKaraokeLineText(line);
        // The backing vocals read on the same line on Spotify's own page, which has one row a line.
        if (line.backing) text = [text stringByAppendingFormat:@" %@", ASMSpotiKaraokeLineText(line.backing)];
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

NSArray<ASMSpotiLyricsProvider *> *ASMSpotiLyricsAllProviders(void) {
    static NSArray<ASMSpotiLyricsProvider *> *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMSpotiLyricsProvider *(^make)(NSString *, NSString *, NSString *, ASMSpotiLyricsAsk) =
        ^(NSString *key, NSString *name, NSString *detail, ASMSpotiLyricsAsk ask) {
            ASMSpotiLyricsProvider *provider = [ASMSpotiLyricsProvider new];
            provider.key = key;
            provider.name = name;
            provider.detail = detail;
            // A source that matches by Spotify's own track id has everything it needs from the
            // start; the rest wait for the player to name the track before they can search.
            provider.needsName = ![@[@"musixmatch", @"spicylyrics"] containsObject:key];
            provider.ask = ask;
            return provider;
        };
        all = @[
            make(@"spicylyrics", @"Spicy Lyrics", @"Syllable timing, uses your Spotify token", ASMSpotiSpicyLyricsAsk),
            make(@"binilyrics", @"BiniLyrics", @"Apple Music word timing", ASMSpotiBiniLyricsAsk),
            make(@"musixmatch", @"Musixmatch", @"Spotify's licensed catalogue", ASMSpotiMusixmatchAsk),
            make(@"unison", @"Unison", @"Hand-timed, few tracks", ASMSpotiUnisonAsk),
            make(@"netease", @"NetEase", @"Word timing, censored", ASMSpotiNetEaseAsk),
            make(@"lrclib", @"LRCLIB", @"Line timing, open fallback", ASMSpotiLrcLibAsk),
        ];
    });
    return all;
}

ASMSpotiLyricsProvider *ASMSpotiLyricsProviderFor(NSString *key) {
    for (ASMSpotiLyricsProvider *provider in ASMSpotiLyricsAllProviders()) {
        if ([provider.key isEqualToString:key]) return provider;
    }
    return nil;
}

// An install from before the order existed keeps what it had: the sources it was using, in the only
// order there was. Nothing is switched on for it that it had not already asked for.
static NSArray<NSString *> *fromLegacyKeys(void) {
    if (!ASMSpotiFlag(kLegacyMusixmatch, NO)) return @[];
    NSMutableArray<NSString *> *order = [NSMutableArray arrayWithObject:@"musixmatch"];
    if (ASMSpotiFlag(kLegacyNetEase, NO)) [order addObject:@"netease"];
    return order;
}

NSArray<NSString *> *ASMSpotiLyricsOrder(void) {
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:ASMSpotiKeyLyricsProviders];
    NSArray *keys = [stored isKindOfClass:NSArray.class] ? stored : fromLegacyKeys();
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id key in keys) {
        if ([key isKindOfClass:NSString.class] && ASMSpotiLyricsProviderFor(key) && ![order containsObject:key]) [order addObject:key];
    }
    return order;
}

void ASMSpotiLyricsSetOrder(NSArray<NSString *> *keys) {
    [NSUserDefaults.standardUserDefaults setObject:keys ?: @[] forKey:ASMSpotiKeyLyricsProviders];
}

BOOL ASMSpotiLyricsEnabled(void) {
    return ASMSpotiLyricsOrder().count > 0;
}

#pragma mark - what is known about the track

// The player knows every track it has played by name, which is what every source but Musixmatch
// searches by. The track is looked up by id rather than compared with the one playing now: a lyrics
// request often lands a beat before the player moves on to its track, and comparing then left the
// query nameless. A track the player has not reported starts with nothing, and the first source
// that matches by id fills the rest in.
static ASMSpotiLyricsQuery *queryFor(NSString *trackID) {
    ASMSpotiLyricsQuery *query = [ASMSpotiLyricsQuery new];
    query.trackID = trackID;
    SPTPlayerTrack *track = ASMSpotiKaraokeTrackFor(trackID);
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

static void learnFrom(ASMSpotiLyricsQuery *query, ASMSpotiLyricsResult *result) {
    if (!query.title.length && result.title.length) query.title = result.title;
    if (!query.artist.length && result.artist.length) query.artist = result.artist;
    if (!query.album.length && result.album.length) query.album = result.album;
    if (query.seconds <= 0 && result.seconds > 0) query.seconds = result.seconds;
}

#pragma mark - the walk

// Main queue only, except asm_spotipw_missing and asm_spotipw_credits.
static NSMutableDictionary<NSString *, id> *asm_spotipw_kept;
static NSMutableDictionary<NSString *, NSMutableArray *> *asm_spotipw_waiting;
static NSMutableSet<NSString *> *asm_spotipw_missing;
static NSMutableDictionary<NSString *, NSString *> *asm_spotipw_credits;
// Spotify's own has_lyrics per track, as its metadata said. The player's metadata is read many
// times a second while a list scrolls, so a value already noted costs one lookup and no write.
static NSMutableDictionary<NSString *, NSNumber *> *asm_spotipw_spotifyHas;
static const NSUInteger kNotedTracks = 200;

static void setUp(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        asm_spotipw_kept = [NSMutableDictionary dictionary];
        asm_spotipw_waiting = [NSMutableDictionary dictionary];
        asm_spotipw_missing = [NSMutableSet set];
        asm_spotipw_credits = [NSMutableDictionary dictionary];
        asm_spotipw_spotifyHas = [NSMutableDictionary dictionary];
    });
}

// Whether the source's lines are better than what the walk already has: any lines beat none, and
// finer timing beats coarser — words timed beat a line's start, which beats plain text. Read off the
// lines themselves, which say how they were really timed, rather than off what the source claimed.
static BOOL betterLines(ASMSpotiLyricsResult *merged, ASMSpotiLyricsResult *fresh) {
    if (!fresh.karaokeLines.count) return NO;
    return !merged.karaokeLines.count || ASMSpotiKaraokeLinesTiming(fresh.karaokeLines) < ASMSpotiKaraokeLinesTiming(merged.karaokeLines);
}

static NSString *timingName(NSArray<ASMSpotiKaraokeLine *> *lines) {
    switch (ASMSpotiKaraokeLinesTiming(lines)) {
        case ASMSpotiKaraokeTimingWords: return @"word timed";
        case ASMSpotiKaraokeTimingLine: return @"line timed";
        default: return @"untimed";
    }
}

// The same for the text Spotify's own page shows: any text beats none, timed beats untimed.
static BOOL betterTexts(ASMSpotiLyricsResult *merged, ASMSpotiLyricsResult *fresh) {
    if (!fresh.texts.count) return NO;
    return !merged.texts.count || (fresh.synced && !merged.synced);
}

// How long a lyrics request waits for the player to name its track before the walk starts without a
// name. The request routinely lands a few hundred milliseconds before the player reports the track
// it belongs to, and a walk started in that gap passes over every source that searches by name.
static const NSTimeInterval kNameWait = 1.5, kNamePoll = 0.1;

static BOOL named(ASMSpotiLyricsQuery *query) {
    return query.title.length && query.artist.length;
}

// One walk down the order for one track.
@interface ASMSpotiLyricsWalk : NSObject
@property (nonatomic, copy) NSArray<NSString *> *order;
@property (nonatomic) NSUInteger index;
@property (nonatomic, strong) ASMSpotiLyricsQuery *query;
@property (nonatomic, strong) ASMSpotiLyricsResult *merged;
// Sources that needed a name the query did not have when their turn came.
@property (nonatomic, strong) NSMutableArray<NSString *> *passedOver;
// asm_spotipw_failures when the walk started. Another walk's failure counts too, which at worst asks again.
@property (nonatomic) NSUInteger failuresAtStart;
@end

@implementation ASMSpotiLyricsWalk
@end

// A walk that ends with nothing is only an answer when every source got to search. One that passed a
// source over for want of a name asked it nothing, and keeping that as "no lyrics" would stick to the
// track: every later request would get the kept nil, and the lyrics card would be taken off the track
// for the rest of the session. The same goes for a walk during which a request failed: a busy
// server's 503 read as "no lyrics" hid a track's lyrics until Spotify was restarted.
static void finish(ASMSpotiLyricsWalk *walk) {
    ASMSpotiLyricsQuery *query = walk.query;
    ASMSpotiLyricsResult *merged = walk.merged;
    NSString *trackID = query.trackID;
    ASMSpotiLyricsResult *lyrics = merged.karaokeLines.count || merged.texts.count ? merged : nil;
    BOOL everyoneAsked = !walk.passedOver.count;
    BOOL failed = atomic_load(&asm_spotipw_failures) != walk.failuresAtStart;
    if (lyrics || (everyoneAsked && !failed) || merged.instrumental) {
        if (asm_spotipw_kept.count >= kKeptTracks) [asm_spotipw_kept removeAllObjects];
        asm_spotipw_kept[trackID] = lyrics ?: NSNull.null;
        if (!lyrics) {
            @synchronized (asm_spotipw_missing) { [asm_spotipw_missing addObject:trackID]; }
        }
    }
    ASMSpotiLog(@"lyrics: %@ ends with %@", trackID, lyrics
          ? [NSString stringWithFormat:@"%lu %@ lines from %@, %lu page lines",
             (unsigned long)lyrics.karaokeLines.count, timingName(lyrics.karaokeLines),
             lyrics.provider, (unsigned long)lyrics.texts.count]
          : everyoneAsked && failed ? @"nothing, a request failed on the way; not kept, so the next request asks again"
          : everyoneAsked ? @"nothing"
          : [NSString stringWithFormat:@"nothing, %@ never knowing its name; not kept, so the next request asks again",
             [walk.passedOver componentsJoinedByString:@", "]]);
    NSArray *waiting = asm_spotipw_waiting[trackID];
    [asm_spotipw_waiting removeObjectForKey:trackID];
    for (void (^done)(ASMSpotiLyricsResult *) in waiting) done(lyrics);
}

static void step(ASMSpotiLyricsWalk *walk) {
    ASMSpotiLyricsQuery *query = walk.query;
    ASMSpotiLyricsResult *merged = walk.merged;
    // A source higher in the order has answered with timed lyrics: that is the answer.
    if (merged.synced && merged.texts.count && merged.karaokeLines.count) {
        finish(walk);
        return;
    }
    if (walk.index >= walk.order.count) {
        // A source that matches by id named the track partway down: the ones passed over ask now,
        // in the order they came in. Once, since they cannot be passed over again with a name.
        if (walk.passedOver.count && named(query)) {
            ASMSpotiLog(@"lyrics: %@ named partway as \"%@\" by \"%@\", asking %@ after all", query.trackID,
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
    ASMSpotiLyricsProvider *provider = ASMSpotiLyricsProviderFor(walk.order[walk.index++]);
    if (provider.needsName && !named(query)) {
        [walk.passedOver addObject:provider.key];
        step(walk);
        return;
    }
    provider.ask(query, ^(ASMSpotiLyricsResult *fresh) {
        learnFrom(query, fresh);
        if (fresh.instrumental) {
            ASMSpotiLog(@"lyrics: %@ is instrumental, by %@", query.trackID, provider.key);
            merged.instrumental = YES;
            finish(walk);
            return;
        }
        if (betterLines(merged, fresh)) {
            merged.karaokeLines = fresh.karaokeLines;
            merged.wordTimed = fresh.wordTimed;
            merged.provider = provider.name;
        }
        if (betterTexts(merged, fresh)) {
            merged.starts = fresh.starts;
            merged.texts = fresh.texts;
            merged.synced = fresh.synced;
            if (!merged.provider) merged.provider = provider.name;
        }
        step(walk);
    });
}

static void startWalk(NSString *trackID, ASMSpotiLyricsQuery *query) {
    ASMSpotiLog(@"lyrics: asking %@ for %@ as \"%@\" by \"%@\", album \"%@\", %lds",
          [ASMSpotiLyricsOrder() componentsJoinedByString:@", "], trackID, query.title, query.artist, query.album, (long)query.seconds);
    ASMSpotiLyricsWalk *walk = [ASMSpotiLyricsWalk new];
    walk.order = ASMSpotiLyricsOrder();
    walk.query = query;
    walk.merged = [ASMSpotiLyricsResult new];
    walk.passedOver = [NSMutableArray array];
    walk.failuresAtStart = atomic_load(&asm_spotipw_failures);
    step(walk);
}

// Starts the walk as soon as the player has named the track, or once it has waited long enough
// that it is not going to: a track opened for something other than what is playing is never named.
static void whenNamed(NSString *trackID, NSTimeInterval waited) {
    ASMSpotiLyricsQuery *query = queryFor(trackID);
    if (named(query) || waited >= kNameWait) {
        if (!named(query)) ASMSpotiLog(@"lyrics: the player never named %@ in %.1fs", trackID, waited);
        startWalk(trackID, query);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kNamePoll * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        whenNamed(trackID, waited + kNamePoll);
    });
}

void ASMSpotiLyricsFetch(NSString *trackID, void (^done)(ASMSpotiLyricsResult *result)) {
    setUp();
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!trackID.length) {
            done(nil);
            return;
        }
        id kept = asm_spotipw_kept[trackID];
        if (kept) {
            done(kept == NSNull.null ? nil : kept);
            return;
        }
        NSMutableArray *waiting = asm_spotipw_waiting[trackID];
        if (waiting) {
            [waiting addObject:[done copy]];
            return;
        }
        asm_spotipw_waiting[trackID] = [NSMutableArray arrayWithObject:[done copy]];
        whenNamed(trackID, 0);
    });
}

BOOL ASMSpotiLyricsMayHave(NSString *trackID) {
    setUp();
    @synchronized (asm_spotipw_missing) { return ![asm_spotipw_missing containsObject:trackID]; }
}

void ASMSpotiLyricsPrefetch(NSString *trackID) {
    if (!trackID.length) return;
    ASMSpotiLyricsFetch(trackID, ^(ASMSpotiLyricsResult *result) {});
}

NSInteger ASMSpotiLyricsSpotifyHas(NSString *trackID) {
    setUp();
    if (!trackID) return -1;
    @synchronized (asm_spotipw_spotifyHas) {
        NSNumber *has = asm_spotipw_spotifyHas[trackID];
        return has ? has.integerValue : -1;
    }
}

void ASMSpotiLyricsNoteSpotifyHas(NSString *trackID, BOOL has) {
    setUp();
    if (!trackID.length) return;
    @synchronized (asm_spotipw_spotifyHas) {
        NSNumber *noted = asm_spotipw_spotifyHas[trackID];
        if (noted && noted.boolValue == has) return;
        if (asm_spotipw_spotifyHas.count >= kNotedTracks) [asm_spotipw_spotifyHas removeAllObjects];
        asm_spotipw_spotifyHas[trackID] = @(has);
    }
}

NSString *const ASMSpotiLyricsOwnRequestKey = @"asm.interface.spotipw.ownRequest";

// The cards under the player load together, and the list is shown without any card still loading
// once this many milliseconds have passed (NowPlaying_ScrollImpl's scrollCardsAsyncLoadingTimeoutMs,
// 2 s unless the server says otherwise, 1 s at the least). The lyrics card is one of them and waits
// for the color-lyrics reply, which with a source of the mod's on comes after the chain has answered;
// so the wait is set to the most the flag allows.
id ASMSpotiLyricsForcedFlag(NSString *key) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = ASMSpotiLyricsEnabled(); });
    if (!on) return nil;
    if ([key isEqualToString:@"ios-nowplaying-scroll-impl.scroll_cards_async_loading_timeout_ms"]) return @5000;
    return nil;
}

// After an override; no row shows the timeout, so nothing is locked.
__attribute__((constructor)) static void registerForcer(void) {
    return; // Host owns shared behavior.
    ASMSpotiRegisterFlagForcer(NO, ^id(NSString *key) { return ASMSpotiLyricsForcedFlag(key); }, nil);
}

#pragma mark - the language of translations

NSArray<NSString *> *ASMSpotiLyricsTranslationLanguages(void) {
    return @[@"", @"ar", @"zh-Hans", @"zh-Hant", @"cs", @"da", @"nl", @"en", @"fi", @"fr", @"de", @"el", @"he",
             @"hi", @"hu", @"id", @"it", @"ja", @"ko", @"nb", @"pl", @"pt", @"ro", @"ru", @"sk", @"es", @"sv",
             @"th", @"tr", @"uk", @"vi"];
}

NSArray<NSString *> *ASMSpotiLyricsTranslationLanguageNames(void) {
    NSLocale *english = [NSLocale localeWithLocaleIdentifier:@"en"];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *tag in ASMSpotiLyricsTranslationLanguages()) {
        [names addObject:tag.length ? [english localizedStringForLocaleIdentifier:tag] ?: tag : @"Any"];
    }
    return names;
}

NSString *ASMSpotiLyricsTranslationLanguage(void) {
    NSArray<NSString *> *tags = ASMSpotiLyricsTranslationLanguages();
    NSInteger index = ASMSpotiInt(ASMSpotiKeyLyricsTranslationLanguage, 0);
    return index > 0 && index < (NSInteger)tags.count ? tags[(NSUInteger)index] : nil;
}

NSString *ASMSpotiLyricsCreditFor(NSString *trackID) {
    setUp();
    @synchronized (asm_spotipw_credits) { return trackID ? asm_spotipw_credits[trackID] : nil; }
}

void ASMSpotiLyricsSetCredit(NSString *trackID, NSString *name) {
    setUp();
    if (!trackID.length) return;
    @synchronized (asm_spotipw_credits) {
        if (asm_spotipw_credits.count >= kKeptTracks) [asm_spotipw_credits removeAllObjects];
        asm_spotipw_credits[trackID] = name ?: @"Spotify";
    }
}

// Once, at launch: the keys Musixmatch owned alone become an order, so the Lyrics page opens on what
// the install was already doing rather than on nothing.
void ASMSpotiLyricsMigrateLegacyKeys(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults objectForKey:ASMSpotiKeyLyricsProviders]) return;
    NSArray<NSString *> *order = fromLegacyKeys();
    if (!order.count) return;
    ASMSpotiLyricsSetOrder(order);
    ASMSpotiSetEnabled(ASMSpotiKeyLyricsAllTracks, ASMSpotiFlag(kLegacyAllTracks, NO));
    ASMSpotiLog(@"lyrics: carried the Musixmatch switches over as %@", [order componentsJoinedByString:@", "]);
}
