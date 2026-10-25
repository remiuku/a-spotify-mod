// The native look's player: Spotify's full screen player with the artwork background and glass header
// buttons (Player.x), the glass lyrics card (LyricsCard.x), the gestures' hookup (PlayerGestures.x) and the parts of it to hide (PlayerDeclutter.x). The glass
// lyrics page is Native/Lyrics/LyricsPage.x's and shares ASMSpotiKeyLyricsCard ("Glass lyrics").
#import <UIKit/UIKit.h>

#define ASMSpotiKeyPlayer @"asm.interface.spotipw.player"
#define ASMSpotiKeyPlayerBackdrop @"asm.interface.spotipw.playerBackdrop"
#define ASMSpotiKeyLyricsCard @"asm.interface.spotipw.lyricsCard"

// Parts of the player to hide, one switch each (PlayerDeclutter.x). An unset switch is off.
#define ASMSpotiHideShuffle @"asm.interface.spotipw.hide.shuffle"
#define ASMSpotiHideRepeat @"asm.interface.spotipw.hide.repeat"
#define ASMSpotiHideConnect @"asm.interface.spotipw.hide.connect"
#define ASMSpotiHideShare @"asm.interface.spotipw.hide.share"
#define ASMSpotiHideQueue @"asm.interface.spotipw.hide.queue"
#define ASMSpotiHideAddTo @"asm.interface.spotipw.hide.addTo"
#define ASMSpotiHideLyricsInline @"asm.interface.spotipw.hide.lyricsInline"
#define ASMSpotiHideLyricsCard @"asm.interface.spotipw.hide.lyricsCard"
#define ASMSpotiHideAboutArtist @"asm.interface.spotipw.hide.aboutArtist"
#define ASMSpotiHideRelatedVideos @"asm.interface.spotipw.hide.relatedVideos"
#define ASMSpotiHideSongDNA @"asm.interface.spotipw.hide.songDNA"
#define ASMSpotiHideLiveEvents @"asm.interface.spotipw.hide.liveEvents"
#define ASMSpotiHideExploreArtist @"asm.interface.spotipw.hide.exploreArtist"
#define ASMSpotiHideCredits @"asm.interface.spotipw.hide.credits"
#define ASMSpotiHideMerch @"asm.interface.spotipw.hide.merch"
#define ASMSpotiHideRecommendations @"asm.interface.spotipw.hide.recommendations"

// The welcome tour's one switch for the player: on hides every card under the player but the
// lyrics, off shows them again. The player's buttons are not its business. Only the tour reads
// it; the hooks read the keys above.
#define ASMSpotiKeyPlayerLyricsOnly @"asm.interface.spotipw.hide.playerLyricsOnly"
void ASMSpotiSetPlayerLyricsOnly(BOOL on);

@class ASMSpotiModRow, ASMSpotiModSection;
// PlayerSettings.m: the player screen's sections of the Player page, the Queue & devices page and the
// "Glass lyrics" row of the Lyrics page.
NSArray<ASMSpotiModSection *> *ASMSpotiNativePlayerScreenSections(void);
UIViewController *ASMSpotiQueueSettingsPage(void);
ASMSpotiModRow *ASMSpotiGlassLyricsRow(void);
