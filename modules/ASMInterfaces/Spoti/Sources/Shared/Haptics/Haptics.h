// Vibrations (Mod Settings > Player > Vibrations), under either look: the Taptic Engine answering
// what a finger does to playback (Controls), and playing along with the music (Music Haptics).
//
//     ASMSpotiFeedback.m         which tap each kind of control gets, played while Controls is on
//     ControlHaptics.x     the player's and the now playing bar's controls, the scrubber, the cover swipes, the gestures
//     MusicHaptics.x       Spotify's audio output listened to, and Core Haptics played along with it
//     ASMSpotiMusicAnalyzer.m    the listening: taps and a rumble out of the samples
//     HapticsSettings.m    the Vibrations cards, with each switch's strength and what Music Haptics follows
//
// Everything on them applies at once, without a restart. Everything hooked is Spotify's own (its controls
// by accessibility identifier, its scrubber, its cover and title lists, its audio unit), so all of it works
// on Spotify's own screens and on the redesign's alike. The redesigned lyrics page's tap to seek plays its
// feedback from Redesigned/Lyrics/ASMSpotiRKaraokeView.m.
// Threading: main thread only.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyControlHaptics @"asm.interface.spotipw.haptics.controls"
#define ASMSpotiKeyMusicHaptics @"asm.interface.spotipw.haptics.music"
// How hard the taps are, a percentage within the range below; 100 is the feel each shipped with.
#define ASMSpotiKeyControlStrength @"asm.interface.spotipw.haptics.controls.strength"
#define ASMSpotiKeyMusicStrength @"asm.interface.spotipw.haptics.music.strength"
// What Music Haptics plays along with, an ASMSpotiMusicFollows.
#define ASMSpotiKeyMusicFollows @"asm.interface.spotipw.haptics.music.follows"
// What the keys were called while this was the redesign's alone; the %ctors move them over.
#define ASMSpotiKeyControlHapticsWas @"asm.interface.spotipw.redesign.haptics.controls"
#define ASMSpotiKeyMusicHapticsWas @"asm.interface.spotipw.redesign.haptics.music"
#define ASMSpotiKeyControlStrengthWas @"asm.interface.spotipw.redesign.haptics.controls.strength"
#define ASMSpotiKeyMusicStrengthWas @"asm.interface.spotipw.redesign.haptics.music.strength"
#define ASMSpotiKeyMusicFollowsWas @"asm.interface.spotipw.redesign.haptics.music.follows"

// Controls go softer only: most of their taps are UIKit's at full intensity already. Music Haptics goes
// either way: at 200% the rumble reaches 0.7 of the Taptic Engine's most, and most taps their most.
enum {
    ASMSpotiControlStrengthMin = 10, ASMSpotiControlStrengthMax = 100,
    ASMSpotiMusicStrengthMin = 20, ASMSpotiMusicStrengthMax = 200,
    ASMSpotiStrengthStep = 10,
};

typedef NS_ENUM(NSInteger, ASMSpotiMusicFollows) {
    ASMSpotiMusicFollowsEverything,   // a tap on each kick and snare, and the rumble under the bass
    ASMSpotiMusicFollowsBeat,         // a tap on each kick and snare, no rumble
    ASMSpotiMusicFollowsBass,         // a tap on each kick, and the rumble
};

typedef NS_ENUM(NSInteger, ASMSpotiFeedback) {
    ASMSpotiFeedbackPlay,      // playback starts
    ASMSpotiFeedbackPause,     // playback stops
    ASMSpotiFeedbackSkip,      // previous, next, a jump in the song (a double tap, a lyric line)
    ASMSpotiFeedbackToggle,    // shuffle, repeat
    ASMSpotiFeedbackAdd,       // the add button: liked songs, a playlist
    ASMSpotiFeedbackGrab,      // a finger takes the scrubber
    ASMSpotiFeedbackDetent,    // the scrubber passing a tenth of the song, a cover swipe passing halfway
    ASMSpotiFeedbackEdge,      // the scrubber reaching the start or the end
    ASMSpotiFeedbackRelease,   // the scrubber let go
};

// Plays `feedback` while Controls is on.
void ASMSpotiPlayFeedback(ASMSpotiFeedback feedback);
// Wakes the Taptic Engine for feedback about to follow quickly (a finger on the scrubber).
void ASMSpotiPrepareFeedback(ASMSpotiFeedback feedback);

// From the Music Haptics switch: starts or stops listening at once.
void ASMSpotiSetMusicHapticsEnabled(BOOL on);
// From its strength and its choice of what to follow: reads them again, for the next tap.
void ASMSpotiMusicHapticsSettingsChanged(void);

// A strength key's percentage as a factor, 1 for 100%, kept within its range.
double ASMSpotiHapticsStrength(NSString *key);
ASMSpotiMusicFollows ASMSpotiMusicHapticsFollows(void);

@class ASMSpotiModSection;
// The Vibrations sections of the Player page: a card for Controls and one for Music Haptics, each opening
// out into its settings while its switch is on.
NSArray<ASMSpotiModSection *> *ASMSpotiVibrationsSections(void);
