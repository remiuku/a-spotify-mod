#import "Core/ASMHost.h"
#import "Core/ASMVitrineCore.h"
#import "Lyrics.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/LyricsSources/LyricsSources.h"
static NSMutableDictionary *asm_payloads, *asm_lines;
static ASMVitrineKaraokeLine *lineFrom(NSDictionary *value) {
    ASMVitrineKaraokeLine *line = [ASMVitrineKaraokeLine new];
    line.start = [value[@"start"] integerValue]; line.end = [value[@"end"] integerValue];
    line.align = [value[@"align"] unsignedIntegerValue]; line.timing = [value[@"timing"] unsignedIntegerValue];
    NSMutableArray *words = [NSMutableArray array];
    for (NSDictionary *word in value[@"words"]) {
        ASMVitrineKaraokeWord *item = [ASMVitrineKaraokeWord new];
        item.text = word[@"text"]; item.start = [word[@"start"] integerValue]; item.end = [word[@"end"] integerValue];
        item.joined = [word[@"joined"] boolValue]; [words addObject:item];
    }
    line.words = words;
    line.translation = value[@"translation"];
    NSString *pronunciation = value[@"pronunciation"];
    if (pronunciation.length) {
        ASMVitrineKaraokeLine *roman = [ASMVitrineKaraokeLine new];
        ASMVitrineKaraokeWord *word = [ASMVitrineKaraokeWord new];
        word.text = pronunciation; word.start = line.start; word.end = line.end;
        roman.words = @[word]; roman.start = line.start; roman.end = line.end; roman.align = line.align; roman.timing = 1;
        line.pronunciation = roman;
    }
    NSArray *backing = value[@"backing"];
    if (backing.count) line.backing = lineFrom(backing.firstObject);
    return line;
}
NSArray *ASMVitrineKaraokeLinesForTrack(NSString *track) {
    if (!track) return nil;
    NSDictionary *payload = ASMHostWith(@"lyrics:",track);
    if (!payload) return nil;
    if (!asm_payloads) { asm_payloads = [NSMutableDictionary new]; asm_lines = [NSMutableDictionary new]; }
    if (asm_payloads[track] != payload) {
        if (asm_payloads.count >= 8) { [asm_payloads removeAllObjects]; [asm_lines removeAllObjects]; }
        NSMutableArray *lines = [NSMutableArray array];
        for (NSDictionary *value in payload[@"lines"]) [lines addObject:lineFrom(value)];
        asm_payloads[track] = payload; asm_lines[track] = lines;
        ASMVitrineLyricsSetCredit(track, payload[@"credit"]);
    }
    return asm_lines[track];
}
void ASMVitrineKaraokeKeepLines(NSString *track, NSArray *lines) {
    // Keep menu-generated translations in this viewer without overwriting the
    // host's source cache. A changed host payload replaces them on the next read.
    if (!track || !lines) return;
    if (!asm_lines) { asm_lines = [NSMutableDictionary new]; asm_payloads = [NSMutableDictionary new]; }
    asm_lines[track] = lines;
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineKaraokeLinesKeptNotification object:track];
}
void ASMVitrineKaraokeRequestLyrics(NSString *track) { if (track) ASMHostSend(@"requestLyrics:",track); }
void ASMVitrineKaraokeAskSpotifyForTiming(NSString *track) { ASMVitrineKaraokeRequestLyrics(track); }
NSString *ASMVitrineKaraokePlayingTrack(void) { return ASMHostObject(@"trackID"); }
NSInteger ASMVitrineKaraokePositionMs(void) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"positionMs");
    return host ? ((NSInteger(*)(id,SEL))objc_msgSend)(host,sel) : -1;
}
void ASMVitrineKaraokeSeek(NSInteger ms) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"seek:");
    if (host) ((void(*)(id,SEL,NSInteger))objc_msgSend)(host,sel,ms);
}
id ASMVitrineKaraokePlayer(void) { return nil; }
SPTPlayerTrack *ASMVitrineKaraokeTrackFor(NSString *track) {
    SPTPlayerTrack *current = ASMVitrinePlayerState().track;
    return [track isEqualToString:ASMVitrineKaraokePlayingTrack()] ? current : nil;
}
void ASMVitrineKaraokeRememberTrack(SPTPlayerTrack *track) {}
NSString *ASMVitrineKaraokeSpotifyAuthorization(void) { return nil; }
BOOL ASMVitrineKaraokeLooking(NSString *track) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"isLooking:");
    return host && ((BOOL(*)(id,SEL,id))objc_msgSend)(host,sel,track);
}
BOOL ASMVitrineEeveeSpotifyInjected(void) { return YES; }
BOOL ASMVitrineEeveeLyricsOn(void) { return YES; }
BOOL ASMVitrineLyricsStandAsideForEevee(void) { return YES; }
void ASMVitrineSpclientHeaders(void (^use)(NSDictionary *headers)) { use(@{}); }
NSNotificationName const ASMVitrineKaraokeLinesKeptNotification = @"ASMVitrineKaraokeLinesKept";
%ctor {
    // Data is shared under every interface: either port may be the chosen viewer.
    [NSNotificationCenter.defaultCenter addObserverForName:@"ASMInterfaceLyricsChanged" object:nil queue:nil usingBlock:^(NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineKaraokeLinesKeptNotification object:ASMVitrineKaraokePlayingTrack()];
        });
    }];
}

NSInteger ASMVitrineKaraokeDelayMs(void) { return MAX(0,MIN(1000,[NSUserDefaults.standardUserDefaults integerForKey:ASMVitrineKeyLyricsDelay])); }
