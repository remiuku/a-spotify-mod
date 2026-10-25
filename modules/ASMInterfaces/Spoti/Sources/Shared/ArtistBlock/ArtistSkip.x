// Skips a track by a blocked artist the moment the player moves onto it, whatever started it: the
// queue, autoplay, a radio or a tap. The track is read off SPTEsperantoPlayer, the app's player,
// which the now playing bar asks for its state from launch on; the full screen player's playback
// controller only exists while that player does, so it is the skip's first choice, not the source. A
// track change is heard from the lock screen's now playing info, which Spotify sets on every track.
// A track is looked at once, so an update within it does not skip twice.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/ASMSpotiCore.h"
#import "ArtistBlock.h"
#import "Headers/SPTPlayer.h"
#import "Headers/SPTNowPlayingPlaybackController.h"

static __weak id asm_spotipw_player;
static __weak SPTNowPlayingPlaybackControllerImplementation *asm_spotipw_controller;
static NSString *asm_spotipw_seenTrack;

static SPTPlayerTrack *playingTrack(BOOL explain) {
    id player = asm_spotipw_player;
    SPTPlayerState *state = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
    SPTPlayerTrack *track = [state respondsToSelector:@selector(track)] ? state.track : nil;
    if (!track && explain) {
        ASMSpotiLog(@"artist block: no track, player %@ state %@",
              player ? NSStringFromClass([player class]) : @"nil", state ? NSStringFromClass(state.class) : @"nil");
    }
    return track;
}

NSArray<NSDictionary *> *ASMSpotiPlayingArtists(void) {
    SPTPlayerTrack *track = playingTrack(YES);
    NSArray<NSDictionary *> *artists = ASMSpotiArtistsOfTrack(track);
    if (track && !artists.count) {
        ASMSpotiLog(@"artist block: no artists in %@, artistURI %@ (%@)", NSStringFromClass(track.class),
              [track respondsToSelector:@selector(artistURI)] ? track.artistURI : @"-",
              [track respondsToSelector:@selector(artistURI)] ? NSStringFromClass([track.artistURI class]) : @"-");
    }
    return artists;
}

static NSString *trackKey(SPTPlayerTrack *track) {
    id uri = [track respondsToSelector:@selector(URI)] ? track.URI : nil;
    return [uri isKindOfClass:NSURL.class] ? ((NSURL *)uri).absoluteString : [uri description];
}

static NSDictionary *blockedArtistOf(SPTPlayerTrack *track) {
    NSArray<NSDictionary *> *artists = ASMSpotiArtistsOfTrack(track);
    if (!ASMSpotiFlag(ASMSpotiKeyArtistBlockFeatured, NO) && artists.count > 1) artists = @[artists.firstObject];
    for (NSDictionary *artist in artists) {
        if (ASMSpotiArtistBlocked(artist[ASMSpotiArtistURI])) return artist;
    }
    return nil;
}

static void skip(SPTPlayerTrack *track, NSDictionary *artist) {
    SPTNowPlayingPlaybackControllerImplementation *controller = asm_spotipw_controller;
    id player = asm_spotipw_player;
    if (controller.canSkipNext) {
        [controller skipToNextWhileDragging:NO];
    } else if ([player respondsToSelector:@selector(skipToNextTrack)]) {
        [(id<SPTPlayer>)player skipToNextTrack];
    } else {
        ASMSpotiLog(@"artist block: %@ by %@ cannot be skipped", track.trackTitle, artist[ASMSpotiArtistName]);
        return;
    }
    ASMSpotiLog(@"artist block: skipped %@ by %@", track.trackTitle, artist[ASMSpotiArtistName]);
}

static void trackMayHaveChanged(void) {
    SPTPlayerTrack *track = playingTrack(NO);
    NSString *key = trackKey(track);
    if (!key || [key isEqualToString:asm_spotipw_seenTrack]) return;
    asm_spotipw_seenTrack = key;

    NSDictionary *artist = blockedArtistOf(track);
    if (artist) skip(track, artist);
}

%hook SPTEsperantoPlayer
- (id)state {
    if (!asm_spotipw_player) {
        asm_spotipw_player = self;
        ASMSpotiLog(@"artist block: player found");
    }
    return %orig;
}
%end

%hook SPTNowPlayingPlaybackControllerImplementation
- (id)initWithPlayer:(id)player testManager:(id)manager inStreamClient:(id)client {
    id controller = %orig;
    asm_spotipw_controller = controller;
    return controller;
}
%end

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    %orig;
    if (!ASMSpotiFlag(ASMSpotiKeyArtistBlock, NO)) return;
    dispatch_async(dispatch_get_main_queue(), ^{ trackMayHaveChanged(); });
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMSpotiRequireClasses(@[@"SPTEsperantoPlayer", @"SPTNowPlayingPlaybackControllerImplementation", @"MPNowPlayingInfoCenter"]);
}
