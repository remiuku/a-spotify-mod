// A local file's edit laid over what Spotify read from it (LocalFiles.h).
//
// -[SPTPlayerTrack metadata] is the one place: trackTitle, artistName, albumTitle and imageURL each read
// self.metadata and take title, artist_name, album_title and image_url from it (their code in the
// binary, through NSDictionary's spt_metadata_* in IDZKAdditions), and the player, the now playing bar
// and the system's now playing info are built from the player's track. So the names go in there, and
// the cover as an image address of the kind Spotify gives a local file, spotify:localfileimage:<path>.
//
// Spotify's loader hands such an address (three parts, no ipod-library in it) to
// SPTLocalAVAssetImageLoaderRequest, whose -loadLocalFileImage reads the cover out of the file at the
// path with AVAsset and passes its bytes to -dispatchSuccess:, which gives them to the delegate's
// imageLoaderRequest:didLoadImageData:. The request caches nothing (preventInMemoryCaching and
// preventPersistentCaching answer YES), so a stored cover is read from disk each time and passed on
// the same way. The system's now playing artwork is added too, in case Spotify fetches it apart.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/ASMVitrineCore.h"
#import "Headers/SPTLocalAVAssetImageLoaderRequest.h"
#import "Headers/SPTPlayer.h"
#import "Shared/Player/NowPlayingExtras.h"
#import "Shared/Player/PlayerState.h"
#import "LocalFiles.h"

// Called for every track in every list many times a second: one prefix check for any other track.
static NSDictionary *withEdit(NSDictionary *metadata, NSString *uri) {
    NSDictionary *edit = ASMVitrineLocalFileEditFor(uri);
    if (!edit) return metadata;
    NSMutableDictionary *edited = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
    if ([edit[@"title"] length]) edited[@"title"] = edit[@"title"];
    if ([edit[@"artist"] length]) edited[@"artist_name"] = edit[@"artist"];
    if ([edit[@"album"] length]) edited[@"album_title"] = edit[@"album"];
    NSString *cover = ASMVitrineLocalFileCoverURL(ASMVitrineLocalFileCoverPath(edit));
    // Every size, since a reader may take any of them: Spotify's loader, and the redesign's artwork bridge
    // (Redesigned/Kit/ASMVitrineRBridges.x), which reads the stored file itself.
    if (cover) {
        for (NSString *field in @[@"image_small_url", @"image_url", @"image_large_url", @"image_xlarge_url"]) edited[field] = cover;
    }
    return edited;
}

#pragma mark - the system's now playing artwork

@interface ASMVitrineLocalFileNowPlaying : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineLocalFileNowPlaying {
    NSString *_track;
}

// Spotify's info is matched by its title, which is the edited one when Spotify built it from the
// player's track and the file's own when it did not, so the artwork rides on either.
- (void)show:(SPTPlayerState *)state {
    NSString *uri = ASMVitrineURIString(state.track.URI);
    NSString *path = ASMVitrineLocalFileCoverPath(ASMVitrineLocalFileEditFor(uri));
    UIImage *cover = path ? [UIImage imageWithContentsOfFile:path] : nil;
    if (!cover) {
        ASMVitrineNowPlayingSetExtras(@"localFiles", nil, nil);
        ASMVitrineNowPlayingSetExtras(@"localFiles.tags", nil, nil);
        return;
    }
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:cover.size requestHandler:^UIImage *(CGSize size) {
        return cover;
    }];
    ASMVitrineNowPlayingSetExtras(@"localFiles", @{MPMediaItemPropertyArtwork: artwork}, ASMVitrineLocalFileInfo(uri)[@"title"]);
    ASMVitrineNowPlayingSetExtras(@"localFiles.tags", @{MPMediaItemPropertyArtwork: artwork}, ASMVitrineLocalFileTags(uri)[@"title"]);
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = ASMVitrineURIString(state.track.URI);
    if (!track || [track isEqualToString:_track]) return;
    _track = track;
    [self show:state];
}

- (void)editsChanged:(NSNotification *)note {
    if ([note.object isEqual:_track]) [self show:ASMVitrinePlayerState()];
}

@end

#pragma mark - hooks

%hook SPTPlayerTrack
- (NSDictionary *)metadata {
    NSDictionary *metadata = %orig;
    NSString *uri = ASMVitrineURIString(self.URI);
    return ASMVitrineLocalFileIs(uri) ? withEdit(metadata, uri) : metadata;
}
%end

%hook SPTLocalAVAssetImageLoaderRequest
- (void)loadLocalFileImage {
    NSString *path = ASMVitrineLocalFileCoverInURL(self.URL.absoluteString);
    if (!path) {
        %orig;
        return;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        ASMVitrineLog(@"local files: the cover %@ is gone, the track shows none", path.lastPathComponent);
        %orig;
        return;
    }
    [self dispatchSuccess:data];
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    %init;
    static ASMVitrineLocalFileNowPlaying *nowPlaying;
    nowPlaying = [ASMVitrineLocalFileNowPlaying new];
    ASMVitrineAddPlayerStateObserver(nowPlaying);
    [NSNotificationCenter.defaultCenter addObserver:nowPlaying selector:@selector(editsChanged:) name:ASMVitrineLocalFileEditsDidChangeNotification object:nil];
    ASMVitrineRequireClasses(@[@"SPTPlayerTrack", @"SPTLocalAVAssetImageLoaderRequest"]);
}
