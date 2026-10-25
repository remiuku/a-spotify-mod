// Anchors the playing track's lossless file again whenever the anchor stops holding: a new track, a seek, a resume.
// Only at normal speed with Karaoke off; anything else leaves Spotify's own sound.
#import "Core/ASMVitrineCore.h"
#import <objc/runtime.h>
#import "Shared/Player/PlayerState.h"
#import "Shared/Sing/Sing.h"
#import "Shared/Player/SpeedPitch.h"
#import "ASMVitrineLossless.h"
#import "ASMVitrineLosslessStore.h"
#import "LosslessQuality.h"

static const int kTries = 3;            // failed anchors in a row before waiting for the next change of source
static const double kRetrySeconds = 2;

@interface ASMVitrineLosslessCoordinator : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineLosslessCoordinator {
    NSString *_track, *_path;
    BOOL _busy, _looked, _nextHas;
    NSString *_next;
    NSDate *_folderChanged;
    int _failures;
    uint64_t _gaveUpEpoch;
    double _retryAt;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    [self tick];
}

- (void)tick {
    SPTPlayerState *state = ASMVitrinePlayerState();
    NSString *track = ASMVitrineURIString(state.track.URI);
    if (![track isEqualToString:_track]) {
        if (_path) ASMVitrineLosslessStop(YES);
        _track = track;
        _path = nil;
        _looked = NO;
        _failures = 0;
        _gaveUpEpoch = 0;
    }
    // A track's first report can come before its title and length: look again until both are known.
    if (track && !_looked) {
        NSString *title = state.track.trackTitle;
        _path = ASMVitrineLosslessStoreFile(track, title ?: @"", state.duration);
        _looked = _path || (title.length && state.duration > 0);
        if (_looked) ASMVitrineLog(@"lossless: %@ (%.1f s): %@", track, state.duration, _path.lastPathComponent ?: @"no file");
    }
    // Spotify fetches a song as it starts, so its quality is set while the one before plays.
    id future = [state respondsToSelector:@selector(future)] ? state.future : nil;
    id upcoming = [future isKindOfClass:NSArray.class] ? [(NSArray *)future firstObject] : nil;
    SPTPlayerTrack *next = [upcoming isKindOfClass:objc_getClass("SPTPlayerTrack")] ? upcoming : nil;
    NSString *nextURI = ASMVitrineURIString(next.URI);
    // Again when the folder changes: a file can arrive while the song before plays.
    NSDate *changed = [NSFileManager.defaultManager attributesOfItemAtPath:ASMVitrineLosslessStoreDirectory() error:NULL].fileModificationDate;
    if (![nextURI isEqualToString:_next] || ![changed isEqualToDate:_folderChanged]) {
        _next = nextURI;
        _folderChanged = changed;
        _nextHas = nextURI && ASMVitrineLosslessStoreHas(nextURI, next.trackTitle ?: @"");
    }
    ASMVitrineLosslessLowerQuality(_nextHas);

    if (!_path || _busy || ASMVitrineLosslessPlaying()) return;
    if (!state.isPlaying || state.isPaused || fabs(state.playbackSpeed - 1) > 0.001 || ASMVitrineSingOn()) return;
    uint64_t epoch = ASMVitrinePlayerSourceEpoch();
    if (_gaveUpEpoch && _gaveUpEpoch == epoch) return;
    double now = CFAbsoluteTimeGetCurrent();
    if (now < _retryAt) return;

    _busy = YES;
    NSString *path = _path;
    double hint = state.position;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *error;
        NSDictionary *anchored = ASMVitrineLosslessAnchor(path, hint, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_busy = NO;
            if (![track isEqualToString:self->_track]) return;
            if (anchored) {
                self->_failures = 0;
                ASMVitrineLosslessStoreRemember(track, path);
                ASMVitrineLog(@"lossless: playing %@ from %.2f s", path.lastPathComponent, [anchored[@"file_seconds"] doubleValue]);
                return;
            }
            self->_retryAt = CFAbsoluteTimeGetCurrent() + kRetrySeconds;
            if (++self->_failures >= kTries) {
                self->_failures = 0;
                self->_gaveUpEpoch = ASMVitrinePlayerSourceEpoch();
                ASMVitrineLog(@"lossless: gave up on %@ until the source changes: %@", path.lastPathComponent, error);
            } else {
                ASMVitrineLog(@"lossless: no anchor (%@)", error);
            }
        });
    });
}
@end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineHidden(ASMVitrineKeyLossless)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        static ASMVitrineLosslessCoordinator *coordinator;
        coordinator = [ASMVitrineLosslessCoordinator new];
        ASMVitrineAddPlayerStateObserver(coordinator);
        // Position reports are not change callbacks, and a seek or resume shows only in the source's epoch.
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { [coordinator tick]; }];
    });
}
