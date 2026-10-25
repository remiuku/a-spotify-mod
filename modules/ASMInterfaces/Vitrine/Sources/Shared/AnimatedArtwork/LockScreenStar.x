// The lock screen widget's star: a tap switches the full-screen artwork between moving artwork and the
// lyrics, at once, by writing the choice LockScreenMotion.x and LyricsArtwork.x both watch. The star is
// MediaPlayer's like command, the slot Apple Music's Favorite star takes; it is filled while the lyrics
// show, under Lyrics or Moving artwork with lyrics. Spotify's own like and dislike buttons (its like_dislike flag) take the same slot, so the flag
// is forced off while the switch is on and the Lock screen page's row shows it locked. iOS 26 only, as
// the artwork is.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/ASMVitrineCore.h"
#import "AnimatedArtwork.h"
#import "Shared/Player/PlayerState.h"

static NSString *const kLikeDislikeFlag = @"ios-feature-lockscreen.like_dislike_enabled";
static MPFeedbackCommand *asm_vitrine_like;   // the command while the star is on it, else nil
static id asm_vitrine_target;

static BOOL starOn(void) {
    return ASMVitrineHidden(ASMVitrineKeyLockScreenStar) && ASMVitrineLockScreenArtwork() != ASMVitrineLockArtworkOff;
}

static MPRemoteCommandHandlerStatus tapped(void) {
    ASMVitrineLockArtwork choice = ASMVitrineLockScreenArtwork();
    if (choice == ASMVitrineLockArtworkOff) return MPRemoteCommandHandlerStatusCommandFailed;
    dispatch_async(dispatch_get_main_queue(), ^{
        // Back to the choice the star left when that one is on the other side, with lyrics or without; else to
        // Lyrics or Moving artwork. So Lyrics and Moving artwork with lyrics each swap with the moving artwork.
        BOOL lyrics = ASMVitrineLockArtworkShowsLyrics(choice);
        ASMVitrineLockArtwork back = (ASMVitrineLockArtwork)ASMVitrineInt(ASMVitrineKeyLockScreenStarBack, ASMVitrineLockArtworkOff);
        BOOL valid = back > ASMVitrineLockArtworkOff && back <= ASMVitrineLockArtworkMotionLyrics && ASMVitrineLockArtworkShowsLyrics(back) != lyrics;
        ASMVitrineSetInt(ASMVitrineKeyLockScreenStarBack, choice);
        ASMVitrineSetInt(ASMVitrineKeyLockScreenArtwork, valid ? back : lyrics ? ASMVitrineLockArtworkMotion : ASMVitrineLockArtworkLyrics);
        ASMVitrineLog(@"lock star: tapped, the lock screen takes %ld", (long)ASMVitrineLockScreenArtwork());
    });
    return MPRemoteCommandHandlerStatusSuccess;
}

// Main thread, on every defaults write and player state: the command is touched only when the star's state
// changed, or when Spotify's lock screen policy turned it off under the star, which the log says.
static void arm(void) {
    static BOOL lastOn, lastActive;
    BOOL on = starOn(), active = on && ASMVitrineLockArtworkShowsLyrics(ASMVitrineLockScreenArtwork());
    if (asm_vitrine_like && !asm_vitrine_like.enabled) {
        static int told;
        if (told++ < 3) ASMVitrineLog(@"lock star: the like command was off under the star, set again");
        asm_vitrine_like.enabled = YES;
    }
    if (on == lastOn && active == lastActive && on == (asm_vitrine_like != nil)) return;
    lastOn = on;
    lastActive = active;
    if (!on && !asm_vitrine_like) return;   // the command is Spotify's
    MPFeedbackCommand *like = MPRemoteCommandCenter.sharedCommandCenter.likeCommand;
    if (!on) {
        [like removeTarget:asm_vitrine_target];
        asm_vitrine_target = nil;
        asm_vitrine_like = nil;
        like.enabled = NO;
        like.active = NO;
        ASMVitrineLog(@"lock star: off");
        return;
    }
    if (!asm_vitrine_like) {
        // Spotify's handler, if the flag had it on one, would like the song on the same tap.
        [like removeTarget:nil];
        asm_vitrine_target = [like addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) { return tapped(); }];
        like.localizedTitle = @"Lock screen lyrics";
        asm_vitrine_like = like;
        ASMVitrineLog(@"lock star: on the like command");
    }
    like.enabled = YES;
    like.active = active;
}

// Spotify's two ways of taking the like command back under the star: turning it off is kept on; taking the
// handlers off is let through and logged, with the star armed again on the next player state.
%hook MPRemoteCommand
- (void)setEnabled:(BOOL)enabled {
    if (!enabled && asm_vitrine_like && self == asm_vitrine_like) {
        static int told;
        if (told++ < 3) ASMVitrineLog(@"lock star: Spotify turned the like command off, kept on");
        enabled = YES;
    }
    %orig(enabled);
}
- (void)removeTarget:(id)target {
    if (asm_vitrine_like && self == asm_vitrine_like && target != asm_vitrine_target) {
        ASMVitrineLog(@"lock star: Spotify took %@ off the like command", target ? @"its handler" : @"every handler");
        if (!target) asm_vitrine_like = nil;
    }
    %orig;
}
%end

@interface ASMVitrineLockScreenStar : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineLockScreenStar
- (void)playerStateDidChange:(SPTPlayerState *)state {
    arm();
}
@end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (@available(iOS 26.0, *)) {
        // Read at launch as Spotify reads the flag; the row locks from the switches as they are stored now.
        BOOL atLaunch = starOn();
        ASMVitrineRegisterFlagForcer(YES, ^id(NSString *key) {
            return atLaunch && [key isEqualToString:kLikeDislikeFlag] ? @NO : nil;
        }, ^id(NSString *key) {
            return starOn() && [key isEqualToString:kLikeDislikeFlag] ? @NO : nil;
        });
        %init;
        static ASMVitrineLockScreenStar *observer;
        observer = [ASMVitrineLockScreenStar new];
        ASMVitrineAddPlayerStateObserver(observer);
        // Heard on the writing thread and handed to main without waiting (AGENTS.md).
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *note) {
            dispatch_async(dispatch_get_main_queue(), ^{ arm(); });
        }];
        ASMVitrineLog(@"lock star: %@", atLaunch ? @"on, Spotify's like and dislike buttons forced off" : @"off");
    }
}
