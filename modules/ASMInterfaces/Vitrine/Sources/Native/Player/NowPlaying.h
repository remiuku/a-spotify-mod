// The native look's player: Spotify's full screen player with the artwork background and glass header
// buttons (Player.x), the glass lyrics card (LyricsCard.x), the gestures' hookup (PlayerGestures.x), the parts of it to hide (PlayerDeclutter.x)
// and its pull held off while the progress bar is scrubbed (PlayerScrub.x). The glass
// lyrics page is Native/Lyrics/LyricsPage.x's and shares ASMVitrineKeyLyricsCard ("Glass lyrics").
#import <UIKit/UIKit.h>

#define ASMVitrineKeyPlayer @"asm.interface.vitrine.player"
#define ASMVitrineKeyPlayerBackdrop @"asm.interface.vitrine.playerBackdrop"
#define ASMVitrineKeyLyricsCard @"asm.interface.vitrine.lyricsCard"

// Parts of the player to hide, one switch each (PlayerDeclutter.x). An unset switch is off.
#define ASMVitrineHideShuffle @"asm.interface.vitrine.hide.shuffle"
#define ASMVitrineHideRepeat @"asm.interface.vitrine.hide.repeat"
#define ASMVitrineHideConnect @"asm.interface.vitrine.hide.connect"
#define ASMVitrineHideShare @"asm.interface.vitrine.hide.share"
#define ASMVitrineHideQueue @"asm.interface.vitrine.hide.queue"
#define ASMVitrineHideAddTo @"asm.interface.vitrine.hide.addTo"
#define ASMVitrineHideLyricsInline @"asm.interface.vitrine.hide.lyricsInline"
#define ASMVitrineHideLyricsCard @"asm.interface.vitrine.hide.lyricsCard"
#define ASMVitrineHideAboutArtist @"asm.interface.vitrine.hide.aboutArtist"
#define ASMVitrineHideRelatedVideos @"asm.interface.vitrine.hide.relatedVideos"
#define ASMVitrineHideSongDNA @"asm.interface.vitrine.hide.songDNA"
#define ASMVitrineHideLiveEvents @"asm.interface.vitrine.hide.liveEvents"
#define ASMVitrineHideExploreArtist @"asm.interface.vitrine.hide.exploreArtist"
#define ASMVitrineHideCredits @"asm.interface.vitrine.hide.credits"
#define ASMVitrineHideMerch @"asm.interface.vitrine.hide.merch"
#define ASMVitrineHideRecommendations @"asm.interface.vitrine.hide.recommendations"

@class ASMVitrineModRow, ASMVitrineModSection;
// PlayerSettings.m: the player screen's sections of the Player page, the Queue & devices page and the
// "Glass lyrics" row of the Lyrics page.
NSArray<ASMVitrineModSection *> *ASMVitrineNativePlayerScreenSections(void);
UIViewController *ASMVitrineQueueSettingsPage(void);
ASMVitrineModRow *ASMVitrineGlassLyricsRow(void);
