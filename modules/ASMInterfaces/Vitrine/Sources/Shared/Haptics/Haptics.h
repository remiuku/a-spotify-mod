// Vibrations (Mod Settings > Vibrations), under either look: the Taptic Engine answering
// what a finger does to playback (Controls), and playing along with the music (Music Haptics).
//
//     ASMVitrineFeedback.m         which tap each kind of control gets, played while Controls is on
//     ControlHaptics.x     the player's and the now playing bar's controls, the scrubber, the cover swipes, the gestures
//     MusicHaptics.x       Spotify's audio output listened to, and Core Haptics played along with it
//     ASMVitrineMusicAnalyzer.m    the listening: taps and a rumble out of the samples
//     SystemMusicHaptics.x iOS's own Music Haptics given the song's Apple Music id or ISRC (In the Background)
//     ASMVitrineHapticTrack.m      the pure steps behind it: Spotify's extended metadata asked and read, Apple's songs matched
//     HapticsSettings.m    the Vibrations page: its cards, each one's strength, what Music Haptics follows, its two
//                          switches, and the move to them from the one choice of before
//     ASMVitrineVibrationsPreview.m the rings at the top of the page, which ripple and play the first feature on when tapped
//
// Everything on them applies at once, without a restart. Everything hooked is Spotify's own (its controls
// by accessibility identifier, its scrubber, its cover and title lists, its audio unit), so all of it works
// on Spotify's own screens and on the redesign's alike. The redesigned lyrics page's tap to seek plays its
// feedback from Redesigned/Lyrics/ASMVitrineRKaraokeView.m.
// Threading: main thread only.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyControlHaptics @"asm.interface.vitrine.haptics.controls"
// Music Haptics, the mod's own, worked out from the sound while Spotify is in front. Off until switched on.
#define ASMVitrineKeyMusicHaptics @"asm.interface.vitrine.haptics.music"
// In the Background: the song named to iOS's own Music Haptics, which plays on the lock screen and in other apps
// too. Off until switched on.
#define ASMVitrineKeyMusicHapticsBackground @"asm.interface.vitrine.haptics.music.background"
// The one choice of before the two switches, None 0, Generated 1 or Native iOS 2; ASMVitrineMigrateMusicHaptics moves it.
#define ASMVitrineKeyMusicHapticsMode @"asm.interface.vitrine.haptics.music.mode"
// How hard the taps are, a percentage within the range below; 100 is the feel each shipped with.
#define ASMVitrineKeyControlStrength @"asm.interface.vitrine.haptics.controls.strength"
#define ASMVitrineKeyMusicStrength @"asm.interface.vitrine.haptics.music.strength"
// What Music Haptics plays along with, an ASMVitrineMusicFollows.
#define ASMVitrineKeyMusicFollows @"asm.interface.vitrine.haptics.music.follows"
// What the keys were called while this was the redesign's alone; the %ctors move them over.
#define ASMVitrineKeyControlHapticsWas @"asm.interface.vitrine.redesign.haptics.controls"
#define ASMVitrineKeyMusicHapticsWas @"asm.interface.vitrine.redesign.haptics.music"
#define ASMVitrineKeyControlStrengthWas @"asm.interface.vitrine.redesign.haptics.controls.strength"
#define ASMVitrineKeyMusicStrengthWas @"asm.interface.vitrine.redesign.haptics.music.strength"
#define ASMVitrineKeyMusicFollowsWas @"asm.interface.vitrine.redesign.haptics.music.follows"

// Controls go softer only: most of their taps are UIKit's at full intensity already. Music Haptics goes
// either way: at 200% the rumble reaches 0.7 of the Taptic Engine's most, and most taps their most.
enum {
    ASMVitrineControlStrengthMin = 10, ASMVitrineControlStrengthMax = 100,
    ASMVitrineMusicStrengthMin = 20, ASMVitrineMusicStrengthMax = 200,
    ASMVitrineStrengthStep = 10,
};

typedef NS_ENUM(NSInteger, ASMVitrineMusicFollows) {
    ASMVitrineMusicFollowsEverything,   // a tap on each kick and snare, and the rumble under the bass
    ASMVitrineMusicFollowsBeat,         // a tap on each kick and snare, no rumble
    ASMVitrineMusicFollowsBass,         // a tap on each kick, and the rumble
};

typedef NS_ENUM(NSInteger, ASMVitrineFeedback) {
    ASMVitrineFeedbackPlay,      // playback starts
    ASMVitrineFeedbackPause,     // playback stops
    ASMVitrineFeedbackSkip,      // previous, next, a jump in the song (a double tap, a lyric line)
    ASMVitrineFeedbackToggle,    // shuffle, repeat
    ASMVitrineFeedbackAdd,       // the add button: liked songs, a playlist
    ASMVitrineFeedbackGrab,      // a finger takes the scrubber
    ASMVitrineFeedbackDetent,    // the scrubber passing a tenth of the song, a cover swipe passing halfway
    ASMVitrineFeedbackEdge,      // the scrubber reaching the start or the end
    ASMVitrineFeedbackRelease,   // the scrubber let go
};

// Plays `feedback` while Controls is on.
void ASMVitrinePlayFeedback(ASMVitrineFeedback feedback);
// Wakes the Taptic Engine for feedback about to follow quickly (a finger on the scrubber).
void ASMVitrinePrepareFeedback(ASMVitrineFeedback feedback);

// The two Music Haptics switches. Both may be on: while iOS plays its haptic track for the song (In the
// Background), the mod's own stays quiet; while Spotify is in front and iOS has none, the mod's own plays.
// In the Background reads off below iOS 18, which has no Music Haptics. Main thread.
BOOL ASMVitrineMusicHapticsOn(void);
BOOL ASMVitrineMusicHapticsInBackground(void);
// Whether iOS lists this install for Music Haptics: MusicHapticsSupported, which only Vitrine's IPA build writes
// into Info.plist. Without it In the Background has nothing to hand the song to.
BOOL ASMVitrineMusicHapticsListedByInstall(void);
// The choice of before moved to the switches, once: Generated turns Music Haptics on, Native iOS In the
// Background, None neither. Each reader of the switches calls it first, since none can know it runs first.
void ASMVitrineMigrateMusicHaptics(void);
// Posted on the main thread when either switch flips; both engines take it up at once.
extern NSNotificationName const ASMVitrineMusicHapticsSwitchesChangedNotification;
// From SystemMusicHaptics.x: YES while iOS reports the named song playing, and for a short while as it asks
// and names one, so the mod's own stays quiet and the two never play at once. Main thread.
void ASMVitrineMusicHapticsSetSystemCovers(BOOL covers);
// From its strength and its choice of what to follow: reads them again, for the next tap.
void ASMVitrineMusicHapticsSettingsChanged(void);
// One kick of the mod's own at its strength, with the rumble under it unless it follows the beat alone, played
// at once: the Vibrations preview's tap. Nothing while the mod's own is not listening.
void ASMVitrineMusicHapticsPreview(void);
// Each tap the mod's own plays from now on is handed to `watcher` on the main thread as it is felt, with its
// intensity before the strength, 0 to 1; nil stops it. Main thread.
void ASMVitrineMusicHapticsWatchTaps(void (^watcher)(float intensity));
// What iOS's own Music Haptics is doing, for the settings to read out: SystemMusicHaptics.x sets it. Main thread.
NSString *ASMVitrineMusicHapticsStatus(void);
void ASMVitrineSetMusicHapticsStatus(NSString *status);
// Whether Music Haptics is on in Settings > Accessibility, as SystemMusicHaptics.x last read it, YES until it has.
// A change posts ASMVitrineSystemMusicHapticsChangedNotification, for the page to show or hide its note. Main thread.
BOOL ASMVitrineSystemMusicHapticsOn(void);
void ASMVitrineSetSystemMusicHapticsOn(BOOL on);
extern NSNotificationName const ASMVitrineSystemMusicHapticsChangedNotification;

// A Spotify track URI's ISRC from Spotify's own metadata (SystemMusicHaptics.x), nil for none, on the main queue.
// Kept for the last 100 tracks; `tries` asks again 4 s apart when Spotify does not answer.
void ASMVitrineSpotifyISRC(NSString *uri, NSUInteger tries, void (^done)(NSString *isrc));

// A strength key's percentage as a factor, 1 for 100%, kept within its range.
double ASMVitrineHapticsStrength(NSString *key);
ASMVitrineMusicFollows ASMVitrineMusicHapticsFollows(void);

// The Vibrations page, linked from Mod Settings' main page: the preview, then a card for Controls and one for Music
// Haptics, each opening out into its settings while it is on.
UIViewController *ASMVitrineVibrationsSettingsPage(void);
