// AirPods gestures (Mod Settings > Player > AirPods gestures), under either look: a double nod and a shake of
// the head, each doing what its pull-down says (Like and Next track until changed), read from the head motion
// that AirPods Pro, AirPods 3 and later, AirPods Max and some Beats report through CMHeadphoneMotionManager.
//
//     ASMVitrineHeadDetector.m         the gestures out of the motion, plain C, tested on the Mac (harness/head-gestures)
//     HeadGestures.x           the motion listened to while the switch is on and Spotify plays, and what each
//                              gesture does through Spotify's player and its collection platform
//     HeadGesturesSettings.m   the page: the switch, each gesture's action, the sensitivity, Try it and Forget
//     HeadGesturesTeach.m      the teaching sheet: five of each gesture, one after each tone, over a ring that
//                              shows the head live
//
// HeadGestures.x owns the app's one CMHeadphoneMotionManager (iOS hands a manager's motion to one handler) and
// lends its motion to other features through ASMVitrineHeadMotionListen: Sing's spatial voice listens there.
//
// Everything applies at once, without a restart.
// Threading: main thread only, but for the listeners' handlers.
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import "ASMVitrineHeadDetector.h"

#define ASMVitrineKeyHeadGestures @"asm.interface.vitrine.headgestures"
// A percentage the thresholds are divided by: over 100 a smaller move counts.
#define ASMVitrineKeyHeadSensitivity @"asm.interface.vitrine.headgestures.sensitivity"
// What learning set, in thousandths of a radian a second; unset or 0 is the detector's default.
#define ASMVitrineKeyHeadNod @"asm.interface.vitrine.headgestures.nod"
#define ASMVitrineKeyHeadShake @"asm.interface.vitrine.headgestures.shake"
// Each gesture's ASMVitrineHeadAction; unset is Like for the nod and Next track for the shake.
#define ASMVitrineKeyHeadNodAction @"asm.interface.vitrine.headgestures.nodaction"
#define ASMVitrineKeyHeadShakeAction @"asm.interface.vitrine.headgestures.shakeaction"
// Whether a gesture that fires a command plays its tone; on until switched off. Try it and teaching always do.
#define ASMVitrineKeyHeadChime @"asm.interface.vitrine.headgestures.chime"

enum { ASMVitrineHeadSensitivityMin = 50, ASMVitrineHeadSensitivityMax = 200, ASMVitrineHeadSensitivityStep = 10 };

// What a gesture does, stored as this number: the order is the pull-down's and only grows at the end.
typedef NS_ENUM(NSInteger, ASMVitrineHeadAction) {
    ASMVitrineHeadActionNothing,
    ASMVitrineHeadActionSeekBack,      // 15 s
    ASMVitrineHeadActionSeekForward,   // 15 s
    ASMVitrineHeadActionPlayPause,
    ASMVitrineHeadActionNext,
    ASMVitrineHeadActionPrevious,
    ASMVitrineHeadActionShuffle,       // on or off
    ASMVitrineHeadActionRepeat,        // off, the context, the track, as Spotify's button goes
    ASMVitrineHeadActionLike,          // into Liked Songs, never out
    ASMVitrineHeadActionCount,
};
ASMVitrineHeadAction ASMVitrineHeadGestureAction(ASMVitrineHeadGesture gesture);
void ASMVitrineSetHeadGestureAction(ASMVitrineHeadGesture gesture, ASMVitrineHeadAction action);

// The cue's sounds, mixed into the music: one tone to time a gesture by, a rising pair when one worked, a low
// tone when it did not. A haptic comes with each while Spotify is in front.
typedef NS_ENUM(NSInteger, ASMVitrineHeadCue) {
    ASMVitrineHeadCueReady,
    ASMVitrineHeadCueWorked,
    ASMVitrineHeadCueFailed,
};
void ASMVitrineHeadGesturesCue(ASMVitrineHeadCue cue);

// Adds the playing track to Liked Songs, never takes it out, through the collection platform kept here: the
// nod's Like, and the Like shortcut's (Shared/LiveActivity). NO when what plays is no track or the platform
// was not reached yet. Spotify's toast shows only with Spotify in front.
BOOL ASMVitrineLikePlayingTrack(void);

// From the switch, the sensitivity, the actions and learning: listens or stops, and reads the thresholds again.
void ASMVitrineHeadGesturesSettingsChanged(void);
// Whether this iPhone can read headphone motion at all (iOS 14 and up; the headphones are another matter).
BOOL ASMVitrineHeadGesturesAvailable(void);

// The page's listening, whatever plays, during which no gesture does anything to the song. One at a time:
// starting one ends the last, and a stopped one's done is never called.
//
// Records `seconds` of motion and hands it back, three doubles a sample (time, pitch, yaw), empty when no
// headphones sent any or motion is not allowed.
void ASMVitrineHeadGesturesRecord(double seconds, void (^done)(NSData *motion));
// Listens up to `seconds` at the thresholds set now, sensitivity included, and hands back the first gesture,
// or ASMVitrineHeadGestureNone once the time is up; `heard` says whether any motion came.
void ASMVitrineHeadGesturesTry(double seconds, void (^done)(ASMVitrineHeadGesture gesture, BOOL heard));
void ASMVitrineHeadGesturesStopListening(void);
// While held the motion runs whatever plays and no gesture does anything: the teaching sheet holds it open, so
// the headphones are sending already when each of its recordings starts.
void ASMVitrineHeadGesturesHold(BOOL hold);

// The threshold one recording of the gesture of `axis` teaches, 0 when it holds no such gesture.
double ASMVitrineHeadGesturesSampleThreshold(NSData *motion, ASMVitrineHeadAxis axis);
// Learns `axis` from recordings of it (ASMVitrineHeadLearnSamples, all but one of them at least) and stores the
// threshold; answers it, or 0 with nothing stored.
double ASMVitrineHeadGesturesLearnFrom(NSArray<NSData *> *motions, ASMVitrineHeadAxis axis);

UIViewController *ASMVitrineHeadGesturesSettingsPage(void);
// The teaching sheet over `owner`; `closed` runs once it is gone, whatever it stored.
void ASMVitrinePresentHeadGesturesTeaching(UIViewController *owner, void (^closed)(void));

// Head motion for another feature, under `name`; a nil handler takes it out. While any listener is in, the
// manager runs whatever the gestures' switch says. A handler is called on the motion's serial queue with every
// motion, and with nil when the motion stops: the headphones gone, the manager stopped, or the listener taken out.
void ASMVitrineHeadMotionListen(NSString *name, void (^handler)(CMDeviceMotion *motion));
// Asks for Motion & Fitness now, while a page is in front, if it was never asked and nothing listens yet.
void ASMVitrineHeadMotionAskPermission(void);
