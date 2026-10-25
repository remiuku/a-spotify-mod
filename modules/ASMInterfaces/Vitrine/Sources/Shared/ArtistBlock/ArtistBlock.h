// Artist block: tracks by artists on the list are skipped as they come up (ArtistSkip.x). An artist
// is kept by URI, with the name it had when it was blocked, so a rename or a namesake changes nothing.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyArtistBlock @"asm.interface.vitrine.artistBlock"
#define ASMVitrineKeyArtistBlockFeatured @"asm.interface.vitrine.artistBlock.featured"   // off: the main artist only
#define ASMVitrineKeyArtistBlockList @"asm.interface.vitrine.artistBlock.list"

extern NSString *const ASMVitrineArtistURI;    // NSString, spotify:artist:…
extern NSString *const ASMVitrineArtistName;   // NSString

NSArray<NSDictionary *> *ASMVitrineBlockedArtists(void);
void ASMVitrineBlockArtist(NSDictionary *artist);
void ASMVitrineUnblockArtist(NSString *uri);
BOOL ASMVitrineArtistBlocked(NSString *uri);

// The artists of a track, the main one first, as dictionaries of the keys above.
NSArray<NSDictionary *> *ASMVitrineArtistsOfTrack(id track);
// ArtistSkip.x: the artists of the track playing now, empty before the player has reported one.
NSArray<NSDictionary *> *ASMVitrinePlayingArtists(void);

UIViewController *ASMVitrineArtistBlockSettingsPage(void);
