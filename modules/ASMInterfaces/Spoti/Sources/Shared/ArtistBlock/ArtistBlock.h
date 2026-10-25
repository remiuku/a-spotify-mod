// Artist block: tracks by artists on the list are skipped as they come up (ArtistSkip.x). An artist
// is kept by URI, with the name it had when it was blocked, so a rename or a namesake changes nothing.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyArtistBlock @"asm.interface.spotipw.artistBlock"
#define ASMSpotiKeyArtistBlockFeatured @"asm.interface.spotipw.artistBlock.featured"   // off: the main artist only
#define ASMSpotiKeyArtistBlockList @"asm.interface.spotipw.artistBlock.list"

extern NSString *const ASMSpotiArtistURI;    // NSString, spotify:artist:…
extern NSString *const ASMSpotiArtistName;   // NSString

NSArray<NSDictionary *> *ASMSpotiBlockedArtists(void);
void ASMSpotiBlockArtist(NSDictionary *artist);
void ASMSpotiUnblockArtist(NSString *uri);
BOOL ASMSpotiArtistBlocked(NSString *uri);

// The artists of a track, the main one first, as dictionaries of the keys above.
NSArray<NSDictionary *> *ASMSpotiArtistsOfTrack(id track);
// ArtistSkip.x: the artists of the track playing now, empty before the player has reported one.
NSArray<NSDictionary *> *ASMSpotiPlayingArtists(void);

UIViewController *ASMSpotiArtistBlockSettingsPage(void);
