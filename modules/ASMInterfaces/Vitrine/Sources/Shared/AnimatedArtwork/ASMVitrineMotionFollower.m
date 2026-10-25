// ASMVitrineMotionFollower (AnimatedArtwork.h): one track's walk of the sources at a time, for the lock screen
// (LockScreenMotion.x) and the redesign's player (Redesigned/Player/PlayerMotion.x) alike.
#import <objc/runtime.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/Player/PlayerState.h"
#import "AnimatedArtwork.h"
#import "ASMVitrineMotionClip.h"

@interface ASMVitrineMotionFollower () <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineMotionFollower {
    BOOL (^_begin)(NSString *, SPTPlayerState *);
    void (^_found)(NSString *, NSURL *);
    NSString *_track;    // the URI walked last
    BOOL _walked;        // whether `begin` let it be walked
    NSURL *_canvas;      // the Canvas its metadata named as the walk began, nil for none
    NSString *_source;   // where the clip found came from, nil for none or not found yet
    NSUInteger _walk;    // counts the walks, so an overtaken one is told from the newest
    NSString *_ahead;    // the next track whose clip was fetched ahead
}

- (instancetype)initWithBegin:(BOOL (^)(NSString *, SPTPlayerState *))begin found:(void (^)(NSString *, NSURL *))found {
    if (!(self = [super init])) return nil;
    _begin = [begin copy];
    _found = [found copy];
    ASMVitrineAddPlayerStateObserver(self);
    return self;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *uri = ASMVitrineURIString(state.track.URI);
    if (!uri) return;
    NSURL *canvas = ASMVitrineMotionCanvasIn(state.track.metadata);
    if ([uri isEqualToString:_track]) {
        if (!_walked || _canvas || !canvas || !ASMVitrineMotionCanvasOutranks(ASMVitrineMotionSourceOrder(), _source)) return;
        ASMVitrineLog(@"motion: the Canvas of %@ came after the track, asked again", uri);
    }
    [self walk:state uri:uri canvas:canvas];
}

- (void)walk:(SPTPlayerState *)state uri:(NSString *)uri canvas:(NSURL *)canvas {
    _track = uri;
    _canvas = canvas;
    _source = nil;
    NSUInteger walk = ++_walk;
    _walked = _begin(uri, state);
    if (!_walked) return;
    NSDictionary *metadata = [state.track.metadata isKindOfClass:NSDictionary.class] ? state.track.metadata : nil;
    __weak ASMVitrineMotionFollower *weakSelf = self;
    ASMVitrineMotionClipFor(uri, canvas, state.track.artistName, metadata[@"album_title"], ASMVitrineMotionTall, ASMVitrineMotionPixels(), ^(NSURL *file, NSString *source) {
        ASMVitrineMotionFollower *follower = weakSelf;
        if (!follower || walk != follower->_walk) return;
        follower->_source = source;
        follower->_found(uri, file);
        [follower fetchAhead];
    });
}

// The next track's clip, fetched into the store once, so a skip finds it there.
- (void)fetchAhead {
    SPTPlayerState *state = ASMVitrinePlayerState();
    id future = [state respondsToSelector:@selector(future)] ? state.future : nil;
    id next = [future isKindOfClass:NSArray.class] ? [(NSArray *)future firstObject] : nil;
    if (![next isKindOfClass:objc_getClass("SPTPlayerTrack")]) return;
    SPTPlayerTrack *track = next;
    NSString *uri = ASMVitrineURIString(track.URI);
    if (!uri || [uri isEqualToString:_track] || [uri isEqualToString:_ahead]) return;
    _ahead = uri;
    NSDictionary *metadata = [track.metadata isKindOfClass:NSDictionary.class] ? track.metadata : nil;
    ASMVitrineMotionClipFor(uri, ASMVitrineMotionCanvasIn(metadata), track.artistName, metadata[@"album_title"], ASMVitrineMotionTall, ASMVitrineMotionPixels(),
                    ^(NSURL *file, NSString *source) {
        ASMVitrineLog(@"motion: the next track's clip fetched ahead: %@", file ? source : @"none");
    });
}

- (void)restart {
    _track = nil;
    _walk++;
    SPTPlayerState *state = ASMVitrinePlayerState();
    if (state) [self playerStateDidChange:state];
}

@end
