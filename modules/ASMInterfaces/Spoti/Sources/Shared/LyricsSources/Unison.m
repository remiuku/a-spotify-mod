// Unison, the lyrics people write for Better Lyrics by hand. It is a small corpus next to the rest,
// but what is in it is Apple Music's own TTML at its best, so it earns being asked early: what it
// misses the next source answers, and what it has beats what that source would have given.
//
// Reads need no key. The write half of its API — submitting, voting, reporting — is signed, and the
// mod does none of it: it asks for lyrics and nothing else.
#import "Core/ASMSpotiCore.h"
#import "LyricsSources.h"

static NSString *const kAPI = @"https://unison.boidu.dev/lyrics";
static const NSInteger kLengthSlack = 4;

ASMSpotiLyricsAsk ASMSpotiUnisonAsk = ^(ASMSpotiLyricsQuery *query, void (^done)(ASMSpotiLyricsResult *result)) {
    if (!query.title.length || !query.artist.length) {
        ASMSpotiLog(@"unison: nothing to search with for %@", query.trackID);
        done(nil);
        return;
    }
    // song and artist alone answer with the highest scored match; album and duration narrow it.
    NSMutableDictionary<NSString *, NSString *> *search = [NSMutableDictionary dictionaryWithDictionary:@{
        @"song": query.title,
        @"artist": query.artist,
    }];
    if (query.seconds > 0) search[@"duration"] = @(query.seconds).stringValue;
    if (query.album.length) search[@"album"] = query.album;
    ASMSpotiLyricsGetJSON(ASMSpotiLyricsURL(kAPI, search), nil, ^(id root) {
        id data = [root isKindOfClass:NSDictionary.class] ? root[@"data"] : nil;
        if (![data isKindOfClass:NSDictionary.class]) {
            ASMSpotiLog(@"unison: no lyrics for %@ by %@", query.title, query.artist);
            done(nil);
            return;
        }
        // Unison also keeps LRC and plain text, which carry nothing the other sources do not.
        if (![data[@"format"] isEqual:@"ttml"]) {
            ASMSpotiLog(@"unison: %@ by %@ is %@, not ttml", query.title, query.artist, data[@"format"]);
            done(nil);
            return;
        }
        NSInteger length = [data[@"duration"] integerValue];
        if (query.seconds > 0 && length > 0 && labs(length - query.seconds) > kLengthSlack) {
            ASMSpotiLog(@"unison: %@ is %lds against the track's %lds", query.title, (long)length, (long)query.seconds);
            done(nil);
            return;
        }
        NSArray<ASMSpotiKaraokeLine *> *lines = ASMSpotiTTMLLines(data[@"lyrics"]);
        if (!lines) {
            done(nil);
            return;
        }
        ASMSpotiLyricsResult *result = [ASMSpotiLyricsResult new];
        result.synced = YES;
        result.wordTimed = [data[@"syncType"] isEqual:@"richsync"];
        result.karaokeLines = lines;
        NSArray<NSNumber *> *starts;
        NSArray<NSString *> *texts;
        ASMSpotiLyricsPageLines(lines, &starts, &texts);
        result.starts = starts;
        result.texts = texts;
        ASMSpotiLog(@"unison: %@ by %@ has %lu %@ lines (%@ confidence)", query.title, query.artist,
              (unsigned long)lines.count, result.wordTimed ? @"word timed" : @"line timed", data[@"confidence"]);
        done(result);
    });
};
