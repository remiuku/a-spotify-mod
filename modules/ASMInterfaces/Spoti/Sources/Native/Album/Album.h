// Album: parts of the album page hidden one switch each, and the cover behind its header (Album.x).
// An unset switch is off.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyAlbumBackdrop @"asm.interface.spotipw.albumBackdrop"

#define ASMSpotiHideAlbumExplore @"asm.interface.spotipw.hide.albumExplore"
#define ASMSpotiHideAlbumAddTo @"asm.interface.spotipw.hide.albumAddTo"
#define ASMSpotiHideAlbumDownload @"asm.interface.spotipw.hide.albumDownload"
#define ASMSpotiHideAlbumMore @"asm.interface.spotipw.hide.albumMore"

#define ASMSpotiHideAlbumMoreBy @"asm.interface.spotipw.hide.albumMoreBy"
#define ASMSpotiHideAlbumVideos @"asm.interface.spotipw.hide.albumVideos"
#define ASMSpotiHideAlbumConcerts @"asm.interface.spotipw.hide.albumConcerts"
#define ASMSpotiHideAlbumMerch @"asm.interface.spotipw.hide.albumMerch"
#define ASMSpotiHideAlbumYouMightLike @"asm.interface.spotipw.hide.albumYouMightLike"

UIViewController *ASMSpotiAlbumSettingsPage(void);   // opened from the Home & Library page
