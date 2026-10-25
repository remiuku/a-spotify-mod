#import "Lyrics.h"
#import "Shared/AdBlock/Protobuf.h"

@implementation ASMSpotiKaraokeWord
@end

@implementation ASMSpotiKaraokeLine
@end

// A line is sung at about this pace and never takes longer than the gap to the next one. A slow
// line gets at least 60 % of its gap, but not more than 1.8x the estimate, so a long instrumental
// after it does not stretch its last word across the break.
static const NSInteger kLineBaseMs = 350, kMsPerLetter = 75;
static const double kMinGapShare = 0.6, kMaxStretch = 1.8;
// Added to every word's letters, for the breath between words and so a one-letter word still shows.
static const NSUInteger kWordWeight = 2;
// A syllable of an unspaced script is one character but a whole beat, so it counts for this many
// letters; without it a Japanese line reads as a handful of letters and its sweep finishes early.
static const NSUInteger kSyllableLetters = 3;

#pragma mark - the model

NSString *ASMSpotiKaraokeLineText(ASMSpotiKaraokeLine *line) {
    NSMutableString *text = [NSMutableString string];
    for (ASMSpotiKaraokeWord *word in line.words) {
        if (text.length && !word.joined) [text appendString:@" "];
        [text appendString:word.text ?: @""];
    }
    return text;
}

NSInteger ASMSpotiKaraokeSungEnd(ASMSpotiKaraokeLine *line) {
    return line.backing ? MAX(line.end, line.backing.end) : line.end;
}

NSInteger ASMSpotiKaraokeLeadLine(NSArray<ASMSpotiKaraokeLine *> *lines, NSInteger ms) {
    NSInteger last = -1;
    while (last + 1 < (NSInteger)lines.count && lines[(NSUInteger)last + 1].start <= ms) last++;
    for (NSInteger i = 0; i < last; i++) {
        if (ASMSpotiKaraokeSungEnd(lines[(NSUInteger)i]) > ms) return i;
    }
    return last;
}

// Japanese, Chinese and Korean, and the punctuation set with them. Kana and Hangul are listed as
// well as the ideographs: a line of either is written without spaces just the same.
static NSCharacterSet *unspacedScript(void) {
    static NSCharacterSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *building = [NSMutableCharacterSet new];
        [building addCharactersInRange:NSMakeRange(0x3000, 0x40)];    // CJK punctuation
        [building addCharactersInRange:NSMakeRange(0x3040, 0xC0)];    // hiragana and katakana
        [building addCharactersInRange:NSMakeRange(0x3400, 0x9C0)];   // ideographs, extension A
        [building addCharactersInRange:NSMakeRange(0x4E00, 0x5200)];  // ideographs
        [building addCharactersInRange:NSMakeRange(0xAC00, 0x2BA4)];  // hangul syllables
        [building addCharactersInRange:NSMakeRange(0xF900, 0x200)];   // compatibility ideographs
        [building addCharactersInRange:NSMakeRange(0xFF66, 0x38)];    // halfwidth katakana
        set = [building copy];
    });
    return set;
}

BOOL ASMSpotiKaraokeUnspacedScript(NSString *text) {
    return text.length && [text rangeOfCharacterFromSet:unspacedScript()].location != NSNotFound;
}

void ASMSpotiKaraokeAlignVoices(NSArray<ASMSpotiKaraokeLine *> *lines) {
    NSMutableArray<NSString *> *heard = [NSMutableArray array];
    for (ASMSpotiKaraokeLine *line in lines) {
        if (!line.voice.length || [heard containsObject:line.voice]) continue;
        [heard addObject:line.voice];
    }
    if (heard.count < 2) return;   // one voice, or none named: every line leads, as it already does
    NSString *trailing = heard[1];
    for (ASMSpotiKaraokeLine *line in lines) {
        line.align = [line.voice isEqualToString:trailing] ? ASMSpotiKaraokeAlignTrailing : ASMSpotiKaraokeAlignLeading;
        line.backing.align = line.align;
    }
}

#pragma mark - estimating the words inside a line

static NSUInteger lettersIn(NSString *text) {
    __block NSUInteger count = 0;
    NSCharacterSet *letters = NSCharacterSet.alphanumericCharacterSet, *unspaced = unspacedScript();
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *piece, NSRange a, NSRange b, BOOL *stop) {
        if ([unspaced characterIsMember:[piece characterAtIndex:0]]) count += kSyllableLetters;
        else if ([letters characterIsMember:[piece characterAtIndex:0]]) count++;
    }];
    return count;
}

static void appendPiece(NSMutableArray<ASMSpotiKaraokeWord *> *pieces, NSString *text) {
    if (!text.length) return;
    ASMSpotiKaraokeWord *word = [ASMSpotiKaraokeWord new];
    word.text = text;
    [pieces addObject:word];
}

// The line split into what the sweep lights one at a time: words where the script spaces them, a
// syllable at a time where it does not, so a Japanese line sweeps instead of lighting up whole.
// Everything a token holds past its first piece is joined to the one before it.
static NSArray<ASMSpotiKaraokeWord *> *piecesOf(NSString *line) {
    NSMutableArray<ASMSpotiKaraokeWord *> *pieces = [NSMutableArray array];
    for (NSString *token in [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) {
        if (!token.length) continue;
        NSUInteger first = pieces.count;
        if (!ASMSpotiKaraokeUnspacedScript(token)) {
            appendPiece(pieces, token);
        } else {
            // Latin letters or digits caught between two syllables stay together as one piece.
            NSMutableString *run = [NSMutableString string];
            NSCharacterSet *unspaced = unspacedScript();
            [token enumerateSubstringsInRange:NSMakeRange(0, token.length)
                                      options:NSStringEnumerationByComposedCharacterSequences
                                   usingBlock:^(NSString *piece, NSRange a, NSRange b, BOOL *stop) {
                if (![unspaced characterIsMember:[piece characterAtIndex:0]]) {
                    [run appendString:piece];
                    return;
                }
                appendPiece(pieces, [run copy]);
                [run setString:@""];
                appendPiece(pieces, piece);
            }];
            appendPiece(pieces, [run copy]);
        }
        for (NSUInteger i = first + 1; i < pieces.count; i++) pieces[i].joined = YES;
    }
    return pieces;
}

static BOOL isBreak(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length == 0 || [trimmed isEqualToString:@"♪"];
}

// gap is the time to the next line, 0 for the last one.
static ASMSpotiKaraokeLine *timedLine(NSString *text, NSInteger start, NSInteger gap) {
    NSArray<ASMSpotiKaraokeWord *> *words = piecesOf(text);
    NSUInteger weight = 0, letters = 0;
    for (ASMSpotiKaraokeWord *word in words) {
        NSUInteger count = lettersIn(word.text);
        letters += count;
        weight += count + kWordWeight;
    }
    NSInteger estimate = kLineBaseMs + (NSInteger)letters * kMsPerLetter;
    NSInteger sung = estimate;
    if (gap > 0) {
        sung = MAX((NSInteger)(gap * kMinGapShare), estimate);
        sung = MIN(sung, (NSInteger)(estimate * kMaxStretch));
        sung = MIN(sung, gap);
    }

    double at = start;
    for (ASMSpotiKaraokeWord *word in words) {
        word.start = (NSInteger)at;
        at += weight ? (double)sung * (lettersIn(word.text) + kWordWeight) / weight : 0;
        word.end = (NSInteger)at;
    }
    ASMSpotiKaraokeLine *line = [ASMSpotiKaraokeLine new];
    line.words = words;
    line.start = start;
    line.end = start + sung;
    line.timing = ASMSpotiKaraokeTimingLine;
    return line;
}

NSArray<ASMSpotiKaraokeLine *> *ASMSpotiKaraokeEstimatedLines(NSArray<NSNumber *> *starts, NSArray<NSString *> *texts) {
    NSMutableArray<ASMSpotiKaraokeLine *> *lines = [NSMutableArray array];
    for (NSUInteger i = 0; i < texts.count; i++) {
        if (isBreak(texts[i])) continue;
        NSInteger start = starts[i].integerValue;
        NSInteger gap = i + 1 < starts.count ? starts[i + 1].integerValue - start : 0;
        [lines addObject:timedLine(texts[i], start, MAX(gap, 0))];
    }
    return lines.count ? lines : nil;
}

NSArray<ASMSpotiKaraokeLine *> *ASMSpotiKaraokeStaticLines(NSArray<NSString *> *texts) {
    NSMutableArray<ASMSpotiKaraokeLine *> *lines = [NSMutableArray array];
    for (NSString *text in texts) {
        if (![text isKindOfClass:NSString.class] || isBreak(text)) continue;
        NSArray<ASMSpotiKaraokeWord *> *words = piecesOf(text);
        if (!words.count) continue;
        ASMSpotiKaraokeLine *line = [ASMSpotiKaraokeLine new];
        line.words = words;
        line.timing = ASMSpotiKaraokeTimingNone;
        [lines addObject:line];
    }
    return lines.count ? lines : nil;
}

ASMSpotiKaraokeTiming ASMSpotiKaraokeLinesTiming(NSArray<ASMSpotiKaraokeLine *> *lines) {
    ASMSpotiKaraokeTiming finest = ASMSpotiKaraokeTimingNone;
    for (ASMSpotiKaraokeLine *line in lines) finest = MIN(finest, line.timing);
    return finest;
}

#pragma mark - Spotify's own bodies

// Lyrics { 1 data: { 1 time_synchronized, 2 repeated line: { 1 offset_ms, 2 content } }, 2 colors }
// Not time_synchronized, the lines are plain text and their offsets all 0. The flag alone is not
// trusted: Spotify's page body has come without it for lines its JSON calls LINE_SYNCED, so any
// offset past 0 counts as timed too.
static NSArray<ASMSpotiKaraokeLine *> *fromProtobuf(NSData *body) {
    ASMSpotiPBField *data = ASMSpotiPBFirst(ASMSpotiPBParse(body), 1);
    if (data.wire != 2) return nil;
    NSArray<ASMSpotiPBField *> *fields = ASMSpotiPBParse(data.payload);
    BOOL synced = ASMSpotiPBFirst(fields, 1).varint != 0;
    NSMutableArray<NSNumber *> *starts = [NSMutableArray array];
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    for (ASMSpotiPBField *field in fields) {
        if (field.number != 2 || field.wire != 2) continue;
        NSArray<ASMSpotiPBField *> *line = ASMSpotiPBParse(field.payload);
        int32_t start = (int32_t)ASMSpotiPBFirst(line, 1).varint;
        if (start > 0) synced = YES;
        [starts addObject:@(start)];
        [texts addObject:ASMSpotiPBText(ASMSpotiPBFirst(line, 2)) ?: @""];
    }
    return synced ? ASMSpotiKaraokeEstimatedLines(starts, texts) : ASMSpotiKaraokeStaticLines(texts);
}

// { "lyrics": { "syncType": "LINE_SYNCED", "lines": [ { "startTimeMs": "1234", "words": "..." } ] } },
// or "UNSYNCED" with every start 0.
static NSArray<ASMSpotiKaraokeLine *> *fromJSON(NSData *body) {
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
    NSDictionary *lyrics = [root isKindOfClass:NSDictionary.class] ? root[@"lyrics"] : nil;
    if (![lyrics isKindOfClass:NSDictionary.class]) return nil;
    BOOL synced = [lyrics[@"syncType"] isEqual:@"LINE_SYNCED"];
    if (!synced && ![lyrics[@"syncType"] isEqual:@"UNSYNCED"]) return nil;
    NSMutableArray<NSNumber *> *starts = [NSMutableArray array];
    NSMutableArray<NSString *> *texts = [NSMutableArray array];
    for (NSDictionary *line in lyrics[@"lines"]) {
        if (![line isKindOfClass:NSDictionary.class]) continue;
        id words = line[@"words"];
        [starts addObject:@([line[@"startTimeMs"] integerValue])];
        [texts addObject:[words isKindOfClass:NSString.class] ? words : @""];
    }
    return synced ? ASMSpotiKaraokeEstimatedLines(starts, texts) : ASMSpotiKaraokeStaticLines(texts);
}

NSArray<ASMSpotiKaraokeLine *> *ASMSpotiKaraokeLinesFromBody(NSData *body) {
    if (!body.length) return nil;
    return ((const uint8_t *)body.bytes)[0] == '{' ? fromJSON(body) : fromProtobuf(body);
}
