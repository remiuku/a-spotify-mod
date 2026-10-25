// Album: parts of the album page hidden one switch each, and the cover behind its header (Album.x).
// An unset switch is off.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyAlbumBackdrop @"asm.interface.vitrine.albumBackdrop"

#define ASMVitrineHideAlbumExplore @"asm.interface.vitrine.hide.albumExplore"
#define ASMVitrineHideAlbumAddTo @"asm.interface.vitrine.hide.albumAddTo"
#define ASMVitrineHideAlbumDownload @"asm.interface.vitrine.hide.albumDownload"
#define ASMVitrineHideAlbumMore @"asm.interface.vitrine.hide.albumMore"

#define ASMVitrineHideAlbumMoreBy @"asm.interface.vitrine.hide.albumMoreBy"
#define ASMVitrineHideAlbumVideos @"asm.interface.vitrine.hide.albumVideos"
#define ASMVitrineHideAlbumConcerts @"asm.interface.vitrine.hide.albumConcerts"
#define ASMVitrineHideAlbumMerch @"asm.interface.vitrine.hide.albumMerch"
#define ASMVitrineHideAlbumYouMightLike @"asm.interface.vitrine.hide.albumYouMightLike"

UIViewController *ASMVitrineAlbumSettingsPage(void);   // opened from the Home & Library page
