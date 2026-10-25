// Moving artwork for a track: its Canvas, or Apple Music's animated album cover where the album has one,
// and for the lock screen, failing both, the cover over a moving blur of itself (ASMVitrineFluidClip.h).
// ASMVitrineMotionCatalog.m looks covers and logos up in Apple Music's catalog. ASMVitrineMotionStore.m keeps every video
// as a local file, the form the system's lock screen takes.
#import <UIKit/UIKit.h>

// What the lock screen fills the screen with, stored as the index of ASMVitrineLockArtwork. It took over from the
// Moving artwork switch, whose key is moved onto it once: on is Moving artwork, off is Off.
#define ASMVitrineKeyLockScreenArtwork @"asm.interface.vitrine.lockscreen.artwork"
#define ASMVitrineKeyLockScreenMotion @"asm.interface.vitrine.lockscreen.motion"
typedef NS_ENUM(NSInteger, ASMVitrineLockArtwork) {
    ASMVitrineLockArtworkOff = 0,
    ASMVitrineLockArtworkMotion,   // the Canvas, else Apple Music's animated cover (LockScreenMotion.x)
    ASMVitrineLockArtworkLyrics,   // a clip per line of lyrics (Shared/LockScreenLyrics/LyricsArtwork.x)
    ASMVitrineLockArtworkEverySong,   // Moving artwork, else the cover over a moving blur of it (LockScreenMotion.x)
    // The lyrics over the moving artwork, else Lyrics: LockScreenMotion.x finds the clip, LyricsArtwork.x
    // draws the lines over it.
    ASMVitrineLockArtworkMotionLyrics,
};
// Off below iOS 26, which has no animated artwork on the lock screen.
ASMVitrineLockArtwork ASMVitrineLockScreenArtwork(void);
// Under Moving artwork with lyrics, LyricsArtwork.x says whether the playing track has no synced lines (YES), so
// LockScreenMotion.x shows its moving artwork plain, as Moving artwork does, or has them (NO), so it takes it off
// for the lyrics' clips. Main queue.
void ASMVitrineLockMotionShowPlain(BOOL plain);
static inline BOOL ASMVitrineLockArtworkShowsLyrics(ASMVitrineLockArtwork artwork) {
    return artwork == ASMVitrineLockArtworkLyrics || artwork == ASMVitrineLockArtworkMotionLyrics;
}
// How the lyrics are drawn, stored as the index of ASMVitrineLyricsClipStyle (Still unless changed).
#define ASMVitrineKeyLockScreenLyricsStyle @"asm.interface.vitrine.lockscreen.lyricsStyle"
// Off until switched on: the lock screen widget's star switches the choice between a choice with lyrics and
// one without (LockScreenStar.x), and takes the place of Spotify's like and dislike buttons. StarBack is the
// choice the star left, to go back to.
#define ASMVitrineKeyLockScreenStar @"asm.interface.vitrine.lockscreen.star"
#define ASMVitrineKeyLockScreenStarBack @"asm.interface.vitrine.lockscreen.star.back"
// Off until switched on: download in Low Data Mode too.
#define ASMVitrineKeyMotionLowData @"asm.interface.vitrine.motion.lowdata"

typedef NS_ENUM(NSInteger, ASMVitrineMotionShape) {
    ASMVitrineMotionSquare,   // 1:1
    ASMVitrineMotionTall,     // 3:4
};

// Apple Music's animated cover for an album, as a local file, or nil. `done` runs on the main queue.
// `pixels` is the width it is shown at; the closest stream at or above it is downloaded.
void ASMVitrineMotionAlbumCover(NSString *artist, NSString *album, ASMVitrineMotionShape shape, CGFloat pixels,
                        void (^done)(NSURL *file));

// The artist's logo from Apple Music, a transparent PNG `pixels` wide, or nil. Main queue.
void ASMVitrineMotionArtistLogo(NSString *artist, CGFloat pixels, void (^done)(UIImage *logo));

// The width a full-screen clip is downloaded at: three quarters of the screen's pixels. A tall cover at the
// screen's full width ran to 29 MB a song; at this width it was 7 MB and looks the same in motion.
CGFloat ASMVitrineMotionPixels(void);

// Apple Music's catalog songs with this ISRC, each with its isrc, durationInMillis and hasHaptics, or nil
// when the catalog could not be asked. Kept for the launch. Main queue.
void ASMVitrineMotionSongsWithISRC(NSString *isrc, void (^done)(NSArray *songs));

// Where moving artwork comes from (MotionSources.m): the keys that are on, in the order they are asked,
// Spotify's Canvas then Apple Music's animated cover unless the user changed it.
#define ASMVitrineKeyMotionSources @"asm.interface.vitrine.motion.sources"
NSArray<NSString *> *ASMVitrineMotionSourceOrder(void);
BOOL ASMVitrineMotionAppleMusicOn(void);
// The track's Canvas video as its metadata names it (canvas.url, of a canvas.type that is a video), or nil.
NSURL *ASMVitrineMotionCanvasIn(NSDictionary *metadata);
// The first clip the order finds for the track `uri`, as a local file, or nil, and the key of the source it
// came from. `canvas` is the track's Canvas video, nil when its metadata names none, and then Spotify's
// Canvas service is asked for it. Main queue.
void ASMVitrineMotionClipFor(NSString *uri, NSURL *canvas, NSString *artist, NSString *album, ASMVitrineMotionShape shape, CGFloat pixels,
                     void (^done)(NSURL *file, NSString *source));

// Follows the player for one user of moving artwork, the lock screen or the redesign's player
// (ASMVitrineMotionFollower.m). Each track's sources are walked once, and again when its Canvas turns up in a later
// state, as it does on a skip, where Spotify reports the track before its extended metadata, unless the clip
// showing came from a source above Canvas. `begin` runs as a walk starts, to take the last clip off, and
// says whether to walk at all; `found` gets the walk's clip, nil for none, and never runs for a walk a newer
// one overtook. Once a walk has ended, the next track's clip is fetched ahead. Main queue.
@class SPTPlayerState;
@interface ASMVitrineMotionFollower : NSObject
- (instancetype)initWithBegin:(BOOL (^)(NSString *uri, SPTPlayerState *state))begin
                        found:(void (^)(NSString *uri, NSURL *file))found;
// The track is walked again from the player's last state: a setting it depends on changed.
- (void)restart;
@end
// The row that opens the ordered list, for the Player page and the lock screen's.
@class ASMVitrineModRow;
ASMVitrineModRow *ASMVitrineMotionSourcesRow(void);

// Any remote video (a Canvas) as a local file, or nil. Main queue.
void ASMVitrineMotionFile(NSURL *remote, void (^done)(NSURL *file));
// Where a video the mod makes itself is kept under `key`, among the downloads, which are kept to the
// newest few. Whether it is there yet is the caller's to check. Any thread.
NSURL *ASMVitrineMotionMadeFile(NSString *key);

// The first frame of a local video. Main queue.
void ASMVitrineMotionPoster(NSURL *file, void (^done)(UIImage *poster));

// Settings: what the lock screen shows, the lyrics' style and Low Data Mode; below iOS 26 the one row
// ASMVitrineLockScreenArtworkNeedsRow, which says the setting needs iOS 26 and, tapped, why.
NSArray *ASMVitrineLockScreenMotionRows(void);
ASMVitrineModRow *ASMVitrineLockScreenArtworkNeedsRow(void);

// Pure steps, for the harness.
NSString *ASMVitrineMotionNameKey(NSString *name);
NSString *ASMVitrineMotionSearchName(NSString *name);
NSString *ASMVitrineMotionStreamIn(NSString *master, CGFloat pixels);
NSString *ASMVitrineMotionWholeFileIn(NSString *media);
