// Sing: a song's vocals turned down while it plays, from a mic button on the redesigned player's lyrics
// (Redesigned/Lyrics/ASMVitrineRSingButton.m) and the Sing page (Sing on Mod Settings' main page, and Lyrics > Karaoke),
// under either look: the work is on Spotify's sound.
//
//     ASMVitrineSingModel.m       the voice model: downloaded, each file checked against its size and SHA-256, loaded
//     ASMVitrineSingLoader.m      the model in memory: a CPU copy, then a Neural Engine one beside it, each load with a deadline
//     ASMVitrineSingSeparator.m   the STFT around the model: two seconds in, their vocals out, on the faster copy in
//     ASMVitrineSingEngine.m      Spotify's mixer pulled ahead of what plays, the vocals separated in the lead, mixed down
//                         and put where spatial voice holds them
//     Sing.x              the engine put between Spotify's mixer and its output (through Shared/Player/SpeedPitch.x's
//                         chain), Spotify's clock and seeks kept true to what plays, the heat, what Sing is doing,
//                         and the head's turn for spatial voice (Shared/HeadGestures' motion)
//     SingSettings.m      the Sing page, and Spatial voice's under it
//     ASMVitrineSingCard.m        the Sing page's card: the song, Sing's state, the vocals and the rest traced live, the level
//     ASMVitrineSpatialPreview.m  the Spatial voice page's preview: the voice in front of the listener on a field of dots,
//                         turned by the head the way the audio is
//
// The voice model is public and MIT licensed: Mel-Band RoFormer (Ju-Chiang Wang, Wei-Tsung Lu, Minz Won) with
// KimberleyJensen's vocal checkpoint, its spectral core exported for Core ML with two-second windows, from
// https://huggingface.co/My-Name-Is-Jeff/vitrine-sing's separator-ane.mlmodelc (App/About/Licenses.m carries its
// notice): Vitrine's export of that checkpoint for the Neural Engine (its layout (B, C, 1, S), 1x1 convolutions,
// attention per head, an RMSNorm that divides by the row's largest value first so half precision does not overflow),
// palettized to 6 bits. Every operation runs on the Neural Engine, and the CPU runs it too, more slowly. Its floor is
// iOS 18, the Core ML it was built with. No audio leaves the phone. Voice model can choose a light model instead, from
// the same repo's separator-light.mlmodelc: the vocals of HiDolen's Mini-BS-RoFormer-18M (MIT), exported in float16
// by harness/sing/export_light.py with the same input and output, smaller and less clean.
//
// Threading: main thread, but for what Sing.x's render side and the engine say.
#import <UIKit/UIKit.h>

@class SPTPlayerState;

// The mic: on and off at once, from the button or the Sing page; off until switched on.
#define ASMVitrineKeySing @"asm.interface.vitrine.sing"
// Whether the redesign's lyrics show the mic in their corner; on until switched off (issue #12). Karaoke itself
// stays on its own switch, which this does not touch.
#define ASMVitrineKeySingButton @"asm.interface.vitrine.sing.button"
extern NSNotificationName const ASMVitrineSingButtonDidChangeNotification;
// The vocals' level, 0 (gone) through 1 (as the song has them) to 2 (the vocals alone) at the slider's top.
#define ASMVitrineKeySingLevel @"asm.interface.vitrine.sing.level"
// Keeps the model running on a hot iPhone, which otherwise lets it go from the thermal state Serious up.
#define ASMVitrineKeySingIgnoreHeat @"asm.interface.vitrine.sing.ignoreHeat"
// Keeps the model through iOS's memory warnings, which otherwise let it go and stop Karaoke until the next song.
// Off until switched on: with it on, iOS may close Spotify instead.
#define ASMVitrineKeySingIgnoreMemory @"asm.interface.vitrine.sing.ignoreMemory"
// Where the model runs: an index into ASMVitrineSingComputeUnitNames(), Automatic (0: a Neural Engine copy beside the CPU's,
// where the iPhone has a Neural Engine) unless CPU only (1) is chosen. The GPU, Neural Engine and GPU and Neural Engine
// stored before (2-4), and the earlier key's every value, are Automatic now, carried over at launch.
#define ASMVitrineKeySingComputeUnits @"asm.interface.vitrine.sing.runsOn"
#define ASMVitrineKeySingComputeUnitsBefore @"asm.interface.vitrine.sing.computeUnits"
// Compiles the Neural Engine copy in the background after an install or an iOS update, with the mic off; on unless
// switched off.
#define ASMVitrineKeySingPrepareAhead @"asm.interface.vitrine.sing.prepareAhead"
// Spatial voice: through headphones that track the head, the vocals stay in front as it turns; off until
// switched on, and at once.
#define ASMVitrineKeySingSpatial @"asm.interface.vitrine.sing.spatial"
// Spatial voice's sound: how far ahead the voice is (meters, 1.5 until set), how much of it is the room (percent, 25
// until set), how long a head that stays turned takes to bring it back in front (seconds, 5 until set), and how wide
// the instruments spread (percent, 110 until set).
#define ASMVitrineKeySingSpatialDistance @"asm.interface.vitrine.sing.spatial.distance"
#define ASMVitrineKeySingSpatialRoom @"asm.interface.vitrine.sing.spatial.room"
#define ASMVitrineKeySingSpatialFront @"asm.interface.vitrine.sing.spatial.front"
#define ASMVitrineKeySingSpatialWidth @"asm.interface.vitrine.sing.spatial.width"

// Posted on the main thread whenever what Sing is doing, or its model's download, changes.
extern NSString *const ASMVitrineSingChangedNotification;

typedef NS_ENUM(NSInteger, ASMVitrineSingState) {
    ASMVitrineSingStateUnavailable,   // the OS or the iPhone cannot run it (ASMVitrineSingMissing says which)
    ASMVitrineSingStateNoModel,       // the model is not downloaded
    ASMVitrineSingStateDownloading,
    ASMVitrineSingStateOff,
    ASMVitrineSingStatePreparing,     // the model loading (only while Spotify is active), which Core ML specializes the first time
    ASMVitrineSingStateWaiting,       // on, the model ready, Spotify not playing through the chain yet; or resting at As sung
                              // (ASMVitrineSingStatusText says which)
    ASMVitrineSingStateBuffering,     // on, the lead filling: what plays is dry
    ASMVitrineSingStateSinging,       // on, the vocals down
    ASMVitrineSingStateBehind,        // on, the model slower than the song: what plays is dry until it catches up
    ASMVitrineSingStateHot,           // on, held for the heat, the model let go
    ASMVitrineSingStateFailed,        // the model or Spotify's output failed (ASMVitrineSingStatusDetail says how)
};
ASMVitrineSingState ASMVitrineSingCurrentState(void);
// What Sing is doing, a few words for the button's label and the page, and what it means where there is
// more to say (what is missing, why it failed), nil otherwise.
NSString *ASMVitrineSingStatusText(void);
NSString *ASMVitrineSingStatusDetail(void);
// Which of the OS, the voice model or the iPhone Sing was built for is missing; nil when none is.
NSString *ASMVitrineSingMissing(void);

BOOL ASMVitrineSingOn(void);
void ASMVitrineSetSingOn(BOOL on);
float ASMVitrineSingLevel(void);
void ASMVitrineSetSingLevel(float level);
// The loudness (RMS) of the vocals and of the rest of the song as heard, per tenth of a second, for the `count`
// tenths up to what plays now, oldest first; NO, and nothing written, unless Sing is turning the vocals down now.
// Reading them says a page shows them: with the vocals as sung and Spatial voice off, Sing separates only while
// they are read (at least once a second), and otherwise rests and plays the song as it is.
BOOL ASMVitrineSingReadLevels(float *vocals, float *rest, int count);
// A level as the slider reads it out: Gone, a percentage, As sung, Backing and a percentage, Vocals only.
NSString *ASMVitrineSingLevelText(double level);
void ASMVitrineSetSingIgnoresHeat(BOOL ignores);
// Seconds of Spotify's sound Sing holds ahead of what plays now, as the render thread left it; 0 when none.
double ASMVitrineSingHeldLead(void);
// The seconds to take off `state`'s position for what is heard: the lead held when the clock's line `state` is on
// began (its first state seen), less what Sing dropped since (ASMVitrineSingEngineLeadAt). Every correction for the lead reads
// this; 0 while Sing never ran.
double ASMVitrineSingLeadOf(SPTPlayerState *state);
// Whether this iPhone runs Sing and reads headphone motion, which spatial voice needs.
BOOL ASMVitrineSingSpatialAvailable(void);
BOOL ASMVitrineSingSpatial(void);
// Stored, the motion's permission asked for when it goes on, and applied at once.
void ASMVitrineSetSingSpatial(BOOL on);
// Distance, Room, Back in front and Instruments width: read as stored, and stored and applied at once. Any thread for
// the getters.
double ASMVitrineSingSpatialDistance(void);
double ASMVitrineSingSpatialRoom(void);
double ASMVitrineSingSpatialFront(void);
double ASMVitrineSingSpatialWidth(void);
void ASMVitrineSetSingSpatialSound(double meters, double roomPercent, double frontSeconds, double widthPercent);

// The top of the Spatial voice page: listener and voice on a field of dots seen from behind the head, which
// follows the head through HeadGestures' motion while it is on screen and the motion is allowed, and idles
// otherwise, a line under it saying which.
@interface ASMVitrineSpatialPreview : UIView
// Reads the switch and the motion's permission again.
- (void)refresh;
@end
// Spatial voice's page, its preview and its switch: under Sing's page, and on Mod Settings' main page under Sing.
UIViewController *ASMVitrineSpatialVoiceSettingsPage(void);
// Runs on changed: the Neural Engine copy loaded or dropped as it now says, the CPU's kept.
void ASMVitrineSingComputeUnitsChanged(void);
// What the main page's Sing row reads out: On, Off, or how far the model has come.
NSString *ASMVitrineSingSummary(void);
UIViewController *ASMVitrineSingSettingsPage(void);

#pragma mark - the model (ASMVitrineSingModel.m)

// Which voice model Karaoke downloads and runs, an ASMVitrineSingModelKind: the full one until Light is chosen. Read live, so
// a switch loads the other model for what plays next, without a restart.
#define ASMVitrineKeySingModel @"asm.interface.vitrine.sing.model"
typedef NS_ENUM(NSInteger, ASMVitrineSingModelKind) {
    ASMVitrineSingModelFull,    // separator-ane.mlmodelc, 210 MB: the cleanest separation
    ASMVitrineSingModelLight,   // separator-light.mlmodelc, 31 MB: Mini-BS-RoFormer-18M's vocals, for older iPhones
};
ASMVitrineSingModelKind ASMVitrineSingChosenModel(void);
// Stored, a running download stopped (it keeps what came in for when its model is chosen again), and announced.
void ASMVitrineSetSingChosenModel(ASMVitrineSingModelKind kind);
// A model's download size, for the rows that choose it.
NSString *ASMVitrineSingModelSizeTextOf(ASMVitrineSingModelKind kind);
// The bytes the model not chosen takes on the iPhone, downloaded or partly (the old model with the full one), and
// their removal.
long long ASMVitrineSingOtherModelBytes(void);
void ASMVitrineSingDeleteOtherModel(void);
// Everything below is about the chosen model.

typedef NS_ENUM(NSInteger, ASMVitrineSingModelState) {
    ASMVitrineSingModelMissing,
    ASMVitrineSingModelDownloading,   // with no model to run meanwhile (the old one runs on through its update's download)
    ASMVitrineSingModelReady,         // on the phone, every file checked: this model, or the old one until its update is in
};
ASMVitrineSingModelState ASMVitrineSingModelCurrentState(void);
// 0 to 1 while downloading.
double ASMVitrineSingModelProgress(void);
// Whether the download is held until the iPhone is online again, or on Wi-Fi unless cellular is allowed.
BOOL ASMVitrineSingModelWaitingForNetwork(void);
// The download over cellular and Low Data Mode networks too, which it otherwise waits out; for this launch.
void ASMVitrineSingDownloadModelOverCellular(void);
BOOL ASMVitrineSingModelOverCellular(void);
// The weights' checksum being read, the download's last step.
BOOL ASMVitrineSingModelChecking(void);
// Bytes a stopped download kept for the next one to carry on from; 0 when there are none.
long long ASMVitrineSingModelPausedBytes(void);
// The last download's failure, nil when there was none (too little free space among them: the download does not
// start then).
NSString *ASMVitrineSingModelError(void);
// The download's size, for the row that offers it.
NSString *ASMVitrineSingModelSizeText(void);
void ASMVitrineSingDownloadModel(void);
void ASMVitrineSingCancelModelDownload(void);
void ASMVitrineSingDeleteModel(void);
// The chosen model's compiled folder once it is downloaded and checked; for the full model, else the old model
// (separator.mlmodelc) where it is still on the iPhone; else nil. On a FLEX build a copy put in Application
// Support/Vitrine/Sing/dev/<separator-ane or separator-light>.mlmodelc by hand comes first, unchecked.
NSURL *ASMVitrineSingModelURL(void);
// The model is the old one: it runs on the CPU alone, and the download is its update.
BOOL ASMVitrineSingModelUpdateAvailable(void);
// That update downloading (ASMVitrineSingModelProgress and the rest say how far).
BOOL ASMVitrineSingModelUpdateDownloading(void);
// The size of the model on the iPhone now, for the row that removes it.
NSString *ASMVitrineSingModelInUseSizeText(void);
// Deletes what the old model's download left, and the old model (separator.mlmodelc) itself once separator-ane.mlmodelc
// is in, logging the space freed; from any thread, at launch and as the download ends. The light model is not touched.
void ASMVitrineSingRemoveOldModel(void);
NSArray<NSString *> *ASMVitrineSingComputeUnitNames(void);
// Whether this OS can load the model (iOS 18). Memory is checked as the model loads (ASMVitrineSingLoader.m).
BOOL ASMVitrineSingOSSupported(void);

// Spotify's position before Sing's lead correction, for discontinuity observation. Off render.
double ASMVitrineSingSourcePosition(SPTPlayerState *state);
#if ASMVitrine_DRIVER
// Whether the most recent stage call entered Sing's engine, rather than passing straight through.
BOOL ASMVitrineSingAnchorStageActive(void);
#endif
