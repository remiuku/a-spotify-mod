// What the lock screen fills the screen with, the lyrics' style and whether the downloads run in Low Data
// Mode. iOS 26 and up only.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "AnimatedArtwork.h"

ASMVitrineLockArtwork ASMVitrineLockScreenArtwork(void) {
    if (@available(iOS 26.0, *)) {
        // The old switch's YES and NO read as Moving artwork and Off, the enum's first two.
        static dispatch_once_t once;
        dispatch_once(&once, ^{ ASMVitrineMigrateKey(ASMVitrineKeyLockScreenMotion, ASMVitrineKeyLockScreenArtwork); });
        return (ASMVitrineLockArtwork)ASMVitrineInt(ASMVitrineKeyLockScreenArtwork, ASMVitrineLockArtworkOff);
    }
    return ASMVitrineLockArtworkOff;
}

NSArray *ASMVitrineLockScreenMotionRows(void) {
    if (@available(iOS 26.0, *)) {
        ASMVitrineLockScreenArtwork();   // moves the old switch over before the row reads the new key
        ASMVitrineModRow *style = ASMVitrineChoiceRow(@"Lyrics style", @"Still draws each line once; Animated breathes the cover behind it. "
                                                       @"With moving artwork, for songs that have none",
                                      ASMVitrineKeyLockScreenLyricsStyle, @[@"Still", @"Animated"], 0);
        style.visible = ^BOOL { return ASMVitrineLockArtworkShowsLyrics(ASMVitrineLockScreenArtwork()); };
        ASMVitrineModRow *lowData = ASMVitrineOptionRow(@"Download in Low Data Mode", @"Moving artwork, up to about 7 MB a song", ASMVitrineKeyMotionLowData);
        lowData.visible = ^BOOL {
            ASMVitrineLockArtwork artwork = ASMVitrineLockScreenArtwork();
            return artwork == ASMVitrineLockArtworkMotion || artwork == ASMVitrineLockArtworkEverySong || artwork == ASMVitrineLockArtworkMotionLyrics;
        };
        ASMVitrineModRow *sources = ASMVitrineMotionSourcesRow();
        sources.visible = lowData.visible;
        ASMVitrineModRow *star = ASMVitrineOptionRow(@"Switch with the star", @"The lock screen widget's star swaps the moving artwork for the lyrics "
                                                             @"and back. It takes the place of Spotify's like and dislike buttons",
                                     ASMVitrineKeyLockScreenStar);
        star.visible = ^BOOL { return ASMVitrineLockScreenArtwork() != ASMVitrineLockArtworkOff; };
        return @[
            ASMVitrineChoiceRow(@"Full-screen artwork", @"The Canvas or Apple Music's animated cover, or the lyrics a line at a time. "
                                                 @"Every song puts the cover over a moving blur of it where a song has neither. "
                                                 @"Moving artwork with lyrics puts the lines over the Canvas or animated cover",
                        ASMVitrineKeyLockScreenArtwork, @[@"Off", @"Moving artwork", @"Lyrics", @"Every song", @"Moving artwork with lyrics"],
                        ASMVitrineLockArtworkOff),
            style,
            star,
            sources,
            lowData,
        ];
    }
    return @[ASMVitrineLockScreenArtworkNeedsRow()];
}

// Below iOS 26 the section stays, with one row that says why there is nothing to pick.
ASMVitrineModRow *ASMVitrineLockScreenArtworkNeedsRow(void) {
    return ASMVitrineStatActionRow(@"Full-screen artwork", nil, ^NSString *{ return @"Needs iOS 26"; }, ^{
        NSString *message = [NSString stringWithFormat:@"This iPhone has iOS %@. The lock screen takes moving artwork "
                                                       @"from apps from iOS 26 on, so the Canvas and Apple Music's animated "
                                                       @"covers can show there once the iPhone is updated.", UIDevice.currentDevice.systemVersion];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Needs iOS 26" message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
    });
}
