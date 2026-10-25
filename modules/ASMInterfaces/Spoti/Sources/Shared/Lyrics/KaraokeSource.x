#import "Core/ASMHost.h"
#import "Core/ASMSpotiCore.h"
#import "Lyrics.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/LyricsSources/LyricsSources.h"
static NSMutableDictionary *asm_payloads, *asm_lines;
static ASMSpotiKaraokeLine *lineFrom(NSDictionary *value) {
    ASMSpotiKaraokeLine *line = [ASMSpotiKaraokeLine new];
    line.start = [value[@"start"] integerValue]; line.end = [value[@"end"] integerValue];
    line.align = [value[@"align"] unsignedIntegerValue]; line.timing = [value[@"timing"] unsignedIntegerValue];
    NSMutableArray *words = [NSMutableArray array];
    for (NSDictionary *word in value[@"words"]) {
        ASMSpotiKaraokeWord *item = [ASMSpotiKaraokeWord new];
        item.text = word[@"text"]; item.start = [word[@"start"] integerValue]; item.end = [word[@"end"] integerValue];
        item.joined = [word[@"joined"] boolValue]; [words addObject:item];
    }
    line.words = words;
    line.translation = value[@"translation"];
    NSString *pronunciation = value[@"pronunciation"];
    if (pronunciation.length) {
        ASMSpotiKaraokeLine *roman = [ASMSpotiKaraokeLine new];
        ASMSpotiKaraokeWord *word = [ASMSpotiKaraokeWord new];
        word.text = pronunciation; word.start = line.start; word.end = line.end;
        roman.words = @[word]; roman.start = line.start; roman.end = line.end; roman.align = line.align; roman.timing = 1;
        line.pronunciation = roman;
    }
    NSArray *backing = value[@"backing"];
    if (backing.count) line.backing = lineFrom(backing.firstObject);
    return line;
}
NSArray *ASMSpotiKaraokeLinesForTrack(NSString *track) {
    if (!track) return nil;
    NSDictionary *payload = ASMHostWith(@"lyrics:",track);
    if (!payload) return nil;
    if (!asm_payloads) { asm_payloads = [NSMutableDictionary new]; asm_lines = [NSMutableDictionary new]; }
    if (asm_payloads[track] != payload) {
        if (asm_payloads.count >= 8) { [asm_payloads removeAllObjects]; [asm_lines removeAllObjects]; }
        NSMutableArray *lines = [NSMutableArray array];
        for (NSDictionary *value in payload[@"lines"]) [lines addObject:lineFrom(value)];
        asm_payloads[track] = payload; asm_lines[track] = lines;
        ASMSpotiLyricsSetCredit(track, payload[@"credit"]);
    }
    return asm_lines[track];
}
void ASMSpotiKaraokeKeepLines(NSString *track, NSArray *lines) {
    // External providers are owned by the host. A port never overwrites its cache.
}
void ASMSpotiKaraokeRequestLyrics(NSString *track) { if (track) ASMHostSend(@"requestLyrics:",track); }
void ASMSpotiKaraokeAskSpotifyForTiming(NSString *track) { ASMSpotiKaraokeRequestLyrics(track); }
NSString *ASMSpotiKaraokePlayingTrack(void) { return ASMHostObject(@"trackID"); }
NSInteger ASMSpotiKaraokePositionMs(void) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"positionMs");
    return host ? ((NSInteger(*)(id,SEL))objc_msgSend)(host,sel) : -1;
}
void ASMSpotiKaraokeSeek(NSInteger ms) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"seek:");
    if (host) ((void(*)(id,SEL,NSInteger))objc_msgSend)(host,sel,ms);
}
id ASMSpotiKaraokePlayer(void) { return nil; }
SPTPlayerTrack *ASMSpotiKaraokeTrackFor(NSString *track) {
    SPTPlayerTrack *current = ASMSpotiPlayerState().track;
    return [track isEqualToString:ASMSpotiKaraokePlayingTrack()] ? current : nil;
}
void ASMSpotiKaraokeRememberTrack(SPTPlayerTrack *track) {}
NSString *ASMSpotiKaraokeSpotifyAuthorization(void) { return nil; }
BOOL ASMSpotiKaraokeLooking(NSString *track) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"isLooking:");
    return host && ((BOOL(*)(id,SEL,id))objc_msgSend)(host,sel,track);
}
BOOL ASMSpotiEeveeSpotifyInjected(void) { return YES; }
BOOL ASMSpotiEeveeLyricsOn(void) { return YES; }
BOOL ASMSpotiLyricsStandAsideForEevee(void) { return YES; }
void ASMSpotiSpclientHeaders(void (^use)(NSDictionary *headers)) { use(@{}); }
NSNotificationName const ASMSpotiKaraokeLinesKeptNotification = @"ASMSpotiKaraokeLinesKept";
%ctor {
    // Data is shared under every interface: either port may be the chosen viewer.
    [NSNotificationCenter.defaultCenter addObserverForName:@"ASMInterfaceLyricsChanged" object:nil queue:nil usingBlock:^(NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiKaraokeLinesKeptNotification object:ASMSpotiKaraokePlayingTrack()];
        });
    }];
}
