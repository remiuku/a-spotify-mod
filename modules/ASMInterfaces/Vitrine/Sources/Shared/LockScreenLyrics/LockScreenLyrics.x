// Spotify's now playing info passes through with the artist swapped for the current line, and a timer
// sends it again each time the line changes. Spotify itself only ever sees its own dictionary back.
//
// The timer follows the playback rate rather than running from launch: a paused player's line does not
// move, so working it out four times a second only wakes the phone. The lock screen keeps the line it
// was left on until the sound starts again.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/ASMVitrineCore.h"
#import "LockScreenLyrics.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Headers/SPTPlayer.h"

static const NSTimeInterval kTick = 0.25;
// Past a line's sung end by this much, with the next line at least this far off, the artist comes back.
static const NSInteger kBreakMs = 4000;
// About what the lock screen's artist row fits before it cuts the text off.
static const NSUInteger kMaxChars = 30;

// Spotify may set the info from any thread; the timer reads it on the main one.
static NSObject *asm_vitrine_lock;
static NSDictionary *asm_vitrine_spotifyInfo;
static CFAbsoluteTime asm_vitrine_spotifyInfoAt;
static NSString *asm_vitrine_shownLine;
static BOOL asm_vitrine_resending;
static dispatch_source_t asm_vitrine_timer;

static NSString *textOf(NSArray<ASMVitrineKaraokeWord *> *words) {
    ASMVitrineKaraokeLine *line = [ASMVitrineKaraokeLine new];
    line.words = words;
    return ASMVitrineKaraokeLineText(line);
}

// A line longer than the artist row holds, split into even pieces rather than a full one and a stub.
// Each piece shows from its first word's estimated start.
static NSArray<NSArray<ASMVitrineKaraokeWord *> *> *piecesOf(ASMVitrineKaraokeLine *line) {
    NSUInteger length = textOf(line.words).length;
    NSUInteger count = MAX((length + kMaxChars - 1) / kMaxChars, 1);
    NSUInteger target = (length + count - 1) / count;
    NSMutableArray<NSArray<ASMVitrineKaraokeWord *> *> *pieces = [NSMutableArray array];
    NSMutableArray<ASMVitrineKaraokeWord *> *piece = [NSMutableArray array];
    NSUInteger pieceLength = 0;
    for (ASMVitrineKaraokeWord *word in line.words) {
        NSUInteger gap = pieceLength && !word.joined ? 1 : 0;
        NSUInteger withWord = pieceLength ? pieceLength + gap + word.text.length : word.text.length;
        if (pieceLength && (withWord > kMaxChars || (withWord > target && pieces.count + 1 < count))) {
            [pieces addObject:piece];
            piece = [NSMutableArray array];
            withWord = word.text.length;
        }
        [piece addObject:word];
        pieceLength = withWord;
    }
    if (piece.count) [pieces addObject:piece];
    return pieces;
}

// Seconds into the track at `now`, run on from what Spotify last reported. A rate it left out runs at 1, as
// playingBy counts it: read as 0, every line written pinned the lock screen's time to Spotify's last report.
static double elapsedAt(NSDictionary *info, CFAbsoluteTime reportedAt, CFAbsoluteTime now) {
    NSNumber *reported = info[MPNowPlayingInfoPropertyPlaybackRate];
    double rate = reported ? reported.doubleValue : 1;
    return [info[MPNowPlayingInfoPropertyElapsedPlaybackTime] doubleValue] + rate * (now - reportedAt);
}

// nil between lines and for a track without synced lyrics, plain text included.
static NSString *lineFor(NSDictionary *info, double elapsed) {
    SPTPlayerState *state = [(id<SPTPlayer>)ASMVitrineKaraokePlayer() state];
    // The player's track can lag behind the now playing info; its lyrics would then be another song's.
    if (![state.track.trackTitle isEqualToString:info[MPMediaItemPropertyTitle]]) return nil;
    NSString *trackID = ASMVitrineKaraokePlayingTrack();
    NSArray<ASMVitrineKaraokeLine *> *lines = ASMVitrineKaraokeLinesForTrack(trackID);
    if (!lines) {
        ASMVitrineKaraokeRequestLyrics(trackID);
        return nil;
    }
    // Plain text has no line being sung to show.
    if (ASMVitrineKaraokeLinesTiming(lines) == ASMVitrineKaraokeTimingNone) return nil;
    NSInteger position = (NSInteger)(elapsed * 1000) - ASMVitrineKaraokeDelayMs();
    NSInteger index = ASMVitrineKaraokeLeadLine(lines, position);
    if (index < 0) return nil;
    BOOL nextFarOff = index + 1 == (NSInteger)lines.count || lines[index + 1].start - position > kBreakMs;
    if (position > lines[index].end + kBreakMs && nextFarOff) return nil;
    NSString *shown = nil;
    for (NSArray<ASMVitrineKaraokeWord *> *piece in piecesOf(lines[index])) {
        if (!shown || piece.firstObject.start <= position) shown = textOf(piece);
    }
    return shown;
}

// Spotify's info with the line in place of the artist, or its own artist for nil. The clock always moves
// on to `elapsed`: the system takes the elapsed time as now's, so the one Spotify reported a while ago
// would pull the progress bar back.
static NSDictionary *withLine(NSDictionary *info, NSString *line, double elapsed) {
    NSMutableDictionary *shown = [info mutableCopy];
    if (line) shown[MPMediaItemPropertyArtist] = line;
    shown[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(elapsed);
    return shown;
}

static void tick(void) {
    NSDictionary *info;
    CFAbsoluteTime reportedAt;
    @synchronized (asm_vitrine_lock) {
        info = asm_vitrine_spotifyInfo;
        reportedAt = asm_vitrine_spotifyInfoAt;
    }
    if (!info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    double elapsed = elapsedAt(info, reportedAt, now);
    NSString *line = lineFor(info, elapsed);
    if (line == asm_vitrine_shownLine || [line isEqualToString:asm_vitrine_shownLine]) return;
    asm_vitrine_shownLine = line;
    asm_vitrine_resending = YES;
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = withLine(info, line, elapsed);
    asm_vitrine_resending = NO;
}

// Main thread, as everything the timer touches is.
static void setTicking(BOOL on) {
    if (on == (asm_vitrine_timer != nil)) return;
    if (!on) {
        dispatch_source_cancel(asm_vitrine_timer);
        asm_vitrine_timer = nil;
        return;
    }
    // A strict GCD timer: the main run loop's timers are throttled while the screen is off, and the lines stood
    // still on a locked phone.
    asm_vitrine_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_main_queue());
    uint64_t every = (uint64_t)(kTick * NSEC_PER_SEC);
    dispatch_source_set_timer(asm_vitrine_timer, dispatch_time(DISPATCH_TIME_NOW, every), every, 10 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(asm_vitrine_timer, ^{
        static CFAbsoluteTime last;
        static int late;
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (last && now - last > 2 && late++ < 5) ASMVitrineLog(@"%s: ticked %.1f s late", __FILE_NAME__, now - last - kTick);
        last = now;
        tick();
    });
    dispatch_resume(asm_vitrine_timer);
}

// Whether the sound is moving. A rate Spotify did not report at all counts as moving: the line would
// stand still either way, and a missing key is no reason to leave the feature switched off for good.
static BOOL playingBy(NSDictionary *info) {
    NSNumber *rate = info[MPNowPlayingInfoPropertyPlaybackRate];
    return !rate || rate.doubleValue > 0;
}

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    if (asm_vitrine_resending) {
        %orig;
        return;
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    @synchronized (asm_vitrine_lock) {
        asm_vitrine_spotifyInfo = info;
        asm_vitrine_spotifyInfoAt = now;
    }
    BOOL playing = playingBy(info) && info[MPNowPlayingInfoPropertyElapsedPlaybackTime] != nil;
    // Karaoke's lyrics are main-thread state; off it the info goes out as it is and the next tick adds the line.
    if (!NSThread.isMainThread || !info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            asm_vitrine_shownLine = nil;
            setTicking(playing);
        });
        %orig;
        return;
    }
    setTicking(playing);
    double elapsed = elapsedAt(info, now, now);
    NSString *line = lineFor(info, elapsed);
    asm_vitrine_shownLine = line;
    %orig(withLine(info, line, elapsed));
}

- (NSDictionary *)nowPlayingInfo {
    NSDictionary *info;
    @synchronized (asm_vitrine_lock) {
        info = asm_vitrine_spotifyInfo;
    }
    return info ?: %orig;
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineFlag(ASMVitrineKeyLockScreenLyrics, NO)) return;
    asm_vitrine_lock = [NSObject new];
    %init;
    // The timer waits for Spotify to report a playing track; nothing before that has a line to show.
    ASMVitrineLog(@"lock screen lyrics: on");
}
