// ListeningStats.h says what Listening stats is. This is the recording: PlayerState's observer is told
// when the track or playing changes, never the position, so a play's length is the wall-clock time it
// spent playing, and it is written down when the next track takes over.
//
// ponytail: a track on repeat one never changes the state's track, so its replays are not counted, and a
// play cut off by Spotify being killed is lost; position polling would catch both.
#import "Core/ASMVitrineCore.h"
#import "Shared/Player/PlayerState.h"
#import "ListeningStats.h"
#import "ASMVitrinePlayLog.h"

ASMVitrinePlayLog *ASMVitrineListeningLog(void) {
    static ASMVitrinePlayLog *log;
    if (!log) {
        NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        log = [[ASMVitrinePlayLog alloc] initWithPath:[support stringByAppendingPathComponent:@"Vitrine/Listening.tsv"]];
    }
    return log;
}

static NSString *stringIn(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

@interface ASMVitrinePlayRecorder : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrinePlayRecorder {
    ASMVitrinePlay *_play;
    double _duration, _listened;
    CFAbsoluteTime _since;   // when it started playing, 0 while it is not
}

// Songs and local files; not ads, episodes or the silence between.
static BOOL isMusic(NSString *uri) {
    return [uri hasPrefix:@"spotify:track:"] || [uri hasPrefix:@"spotify:local:"];
}

// The metadata can come after the track does, so what is missing is filled in on every report.
- (void)fill:(SPTPlayerState *)state {
    SPTPlayerTrack *track = state.track;
    NSDictionary *metadata = [track respondsToSelector:@selector(metadata)] ? track.metadata : nil;
    if (!_play.title.length) _play.title = stringIn(track.trackTitle) ?: stringIn(metadata[@"title"]) ?: @"";
    if (!_play.artist.length) _play.artist = stringIn(metadata[@"artist_name"]) ?: stringIn(track.artistName) ?: @"";
    if (!_play.album.length) _play.album = stringIn(metadata[@"album_title"]) ?: @"";
    if (_duration <= 0) _duration = state.duration;
}

- (void)finish {
    if (_play && _play.title.length && _play.artist.length && ASMVitrinePlayCounts(_listened, _duration) && ASMVitrineEnabled(ASMVitrineKeyListeningStats)) {
        _play.end = (int64_t)time(NULL);
        _play.ms = (int64_t)(_listened * 1000);
        [ASMVitrineListeningLog() record:_play];
    }
    _play = nil;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (_since) _listened += now - _since;
    _since = 0;
    NSString *uri = ASMVitrineURIString(state.track.URI);
    if (![uri isEqualToString:_play.uri]) {
        [self finish];
        if (isMusic(uri)) {
            _play = [ASMVitrinePlay new];
            _play.uri = uri;
            _duration = _listened = 0;
        }
    }
    if (!_play) return;
    [self fill:state];
    BOOL loading = [state respondsToSelector:@selector(isLoading)] && state.isLoading;
    if (state.isPlaying && !state.isPaused && !loading) _since = now;
}

- (void)terminate {
    if (_since) _listened += CFAbsoluteTimeGetCurrent() - _since;
    _since = 0;
    [self finish];
}

@end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    static ASMVitrinePlayRecorder *recorder;
    recorder = [ASMVitrinePlayRecorder new];
    ASMVitrineAddPlayerStateObserver(recorder);
    [NSNotificationCenter.defaultCenter addObserver:recorder selector:@selector(terminate) name:UIApplicationWillTerminateNotification object:nil];
}
