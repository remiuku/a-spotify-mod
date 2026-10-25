// The areas the redesign stripped and ASMSpotiRRepaint.x keeps transparent when Spotify repaints them, each
// set by the part of the redesign that owns it.
#import <UIKit/UIKit.h>

extern __weak UIView *asm_spotipw_r_nowPlayingRoot;   // Redesigned/NowPlayingBar/NowPlayingBar.x, the bar
extern __weak UIView *asm_spotipw_r_nowPlayingCard;   // the bar's painted card, learnt from the album-colour paint
extern __weak UIView *asm_spotipw_r_lyricsPageRoot;   // Redesigned/Lyrics/LyricsPage.x
// Redesigned/Playlist/PlaylistField.x, the playlist page. Only the base surface Spotify paints the page,
// its list and its rows with goes clear here: the artwork field is underneath, and the greys of a
// placeholder or a badge are what still has to read against it.
extern __weak UIView *asm_spotipw_r_playlistRoot;
// Redesigned/Album/AlbumField.x, the album page, kept clear the same way and for the same reason.
extern __weak UIView *asm_spotipw_r_albumRoot;
// Redesigned/Artist/ArtistField.x, the artist page, kept clear the same way and for the same reason.
extern __weak UIView *asm_spotipw_r_artistRoot;
