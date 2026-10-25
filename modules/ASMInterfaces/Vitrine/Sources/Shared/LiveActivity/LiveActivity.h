// The Live Activity (Mod Settings > Live Activity), on the lock screen and in the Dynamic
// Island (iOS 17+), under either look: it draws on no Spotify screen of its own. In one of three views: the line being sung with the next one under it, the tracks
// up next (a tap on one skipping ahead to it), or the control menu, tabs of Controls (previous, play and
// pause, next, shuffle, repeat), Queue and a sleep Timer of the mod's own (Shared/Player/SleepTimer.h)
// that fades the sound out (over the page's Fade out choice) and pauses Spotify, at a time or at the end of
// the track, album or playlist.
//
//     LiveActivity.x              polls the player, sends the activity a new state when what it shows changes
//     LiveActivityBridge.swift    ActivityKit, which is Swift only
//     LiveActivityShared.swift    the attributes and the taps' intents, compiled into the extension too, and
//                                 the shortcuts' intents: Like This Song, Play or Pause, Next and Previous Track,
//                                 Sing and Sleep Timer, for Siri, the Shortcuts app, the Action button and the
//                                 controls (extension/LiveActivity/Controls.swift), answered by LiveActivity.x
//                                 with the activity on or off; checked in the simulator (harness/shortcuts)
//     AppShortcuts.swift          Spotify's App Shortcuts, tweak only
//     LiveActivitySettings.m      its page, opened from the root of Mod Settings
//     ASMVitrineLiveActivityPreview.m     the page's preview, a mock of the card on a slice of the lock screen
//
// Every tap in the card runs an intent inside Spotify and takes a second or two to show on the card.
//
// The widget is extension/LiveActivity, built into the IPA by scripts/build-extension.sh; the tap's
// intent runs in Spotify, so scripts/merge-appintents.py adds it to Spotify's App Intents metadata. The lines and
// the clock come from Shared/Lyrics, the queue from the player's state. The switch and the view apply at
// once: iOS lets an activity start only while the app is in front, which it is when the switch is flipped.
// The page's other options are read on every tick and sent in the state, so they apply within a tick too.
//
// The Swift names crossing into the widget (ASMVitrineLyricsAttributes, the intents and their enums, the notifications)
// are a contract with extension/LiveActivity and with the App Intents metadata merged into Spotify:
// ActivityKit and App Intents pair the two processes by type name, so a change here is a change there.
// Threading: main thread only.
#import <Foundation/Foundation.h>

#define ASMVitrineKeyLiveActivity @"asm.interface.vitrine.liveActivity"
// Which view it shows, the index into the page's list.
#define ASMVitrineKeyLiveActivityView @"asm.interface.vitrine.liveActivity.view"
// The lyrics view's: the line's translation under it (off until switched on), and the line's size, an
// ASMVitrineLiveActivityTextSize.
#define ASMVitrineKeyLiveActivityTranslation @"asm.interface.vitrine.liveActivity.translation"
#define ASMVitrineKeyLiveActivityTextSize @"asm.interface.vitrine.liveActivity.textSize"
// The lyrics view's too: what it shows on a track with no timed lyrics, an ASMVitrineLiveActivityWithoutLyrics, and
// the lines' alignment, an ASMVitrineLiveActivityAlignment.
#define ASMVitrineKeyLiveActivityWithoutLyrics @"asm.interface.vitrine.liveActivity.withoutLyrics"
#define ASMVitrineKeyLiveActivityAlignment @"asm.interface.vitrine.liveActivity.alignment"
// Every view's: the cover beside the track and in the Dynamic Island (on until switched off), the card's
// colors, an ASMVitrineLiveActivityColors, and the progress bar (on until switched off).
#define ASMVitrineKeyLiveActivityArtwork @"asm.interface.vitrine.liveActivity.artwork"
#define ASMVitrineKeyLiveActivityColors @"asm.interface.vitrine.liveActivity.colors"
#define ASMVitrineKeyLiveActivityProgressBar @"asm.interface.vitrine.liveActivity.progressBar"
// What the keys were called while this was the redesign's alone; LiveActivity.x's %ctor moves them over.
#define ASMVitrineKeyLiveActivityWas @"asm.interface.vitrine.redesign.liveActivity"
#define ASMVitrineKeyLiveActivityViewWas @"asm.interface.vitrine.redesign.liveActivity.view"

typedef NS_ENUM(NSInteger, ASMVitrineLiveActivityView) {
    ASMVitrineLiveActivityLyrics = 0,
    ASMVitrineLiveActivityQueue,
    ASMVitrineLiveActivityPanel,   // the control menu
};

// ASMVitrineLyricsAttributes.ContentState's textSize; the widget gives each a text style.
typedef NS_ENUM(NSInteger, ASMVitrineLiveActivityTextSize) {
    ASMVitrineLiveActivityTextSmall = 0,
    ASMVitrineLiveActivityTextMedium,
    ASMVitrineLiveActivityTextLarge,
};

// ASMVitrineLyricsAttributes.ContentState's withoutLyrics: a note under the track, or the track large in place of the lines.
typedef NS_ENUM(NSInteger, ASMVitrineLiveActivityWithoutLyrics) {
    ASMVitrineLiveActivityWithoutLyricsNote = 0,
    ASMVitrineLiveActivityWithoutLyricsTrack,
};

// ASMVitrineLyricsAttributes.ContentState's alignment, of the lyric lines.
typedef NS_ENUM(NSInteger, ASMVitrineLiveActivityAlignment) {
    ASMVitrineLiveActivityAlignLeft = 0,
    ASMVitrineLiveActivityAlignCenter,
};

// ASMVitrineLyricsAttributes.ContentState's colors: Spotify's (the cover's color darkened behind Spotify's green),
// the cover's (the same behind the cover's color lightened) or plain (white on the system's background).
typedef NS_ENUM(NSInteger, ASMVitrineLiveActivityColors) {
    ASMVitrineLiveActivityColorsSpotify = 0,
    ASMVitrineLiveActivityColorsArtwork,
    ASMVitrineLiveActivityColorsPlain,
};

// From the switch: starts following the player (and the activity, the app being in front) or ends both.
void ASMVitrineSetLiveActivityEnabled(BOOL on);

@class UIViewController;
// The Live Activity page: a preview of the card (ASMVitrineLiveActivityPreview.m), its switch, which view it shows, the
// lyrics' options and the card's.
UIViewController *ASMVitrineLiveActivitySettingsPage(void);
// Whether this install lets Spotify start a Live Activity: NSSupportsLiveActivities, which only Vitrine's IPA
// build writes into Info.plist. Without it iOS turns every one down.
BOOL ASMVitrineLiveActivityAllowedByInstall(void);
