// The player's settings that do not depend on the look: the lock screen widget's flags.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "PlayerSettings.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/Lyrics/Lyrics.h"

// Widget first: the line in place of the artist (on the Lyrics page too, the same switch) and Like and dislike,
// the one lock screen control a song gets, which the Artwork section's star takes the place of
// (Shared/AnimatedArtwork/LockScreenStar.x locks the flag off). Spotify's flags for podcasts, audiobooks and its
// own lock screen artwork stay on the All flags page: the Artwork section is the mod's.
UIViewController *ASMVitrineLockScreenWidgetPage(void) {
    ASMVitrineModRow *likes = ASMVitrineFlagRow(@"Like and dislike buttons", @"ios-feature-lockscreen.like_dislike_enabled");
    likes.subtitle = @"Off and locked while Switch with the star is on: the star takes their place";
    return [[ASMVitrineModPage alloc] initWithTitle:@"Lock screen" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineSection(@"Widget", @[ASMVitrineLockScreenLyricsRow(), likes]),
        ASMVitrineSection(@"Artwork", ASMVitrineLockScreenMotionRows()),
    ] footer:nil];
}
