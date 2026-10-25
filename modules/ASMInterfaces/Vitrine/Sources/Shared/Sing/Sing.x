// Sing on Spotify's sound (Sing.h): the engine put between Spotify's mixer and its output, the voice model
// loaded while the mic is on, Spotify's clock and seeks kept true to what plays, the heat, and what Sing is
// doing for the button and the page.
//
// The engine sits in the chain Speed and pitch takes over (Shared/Player/SpeedPitch.x): its stage is handed
// the mixer's pull, so the engine can pull the mixer ahead of what plays. It takes Spotify's sound as Spotify
// hands it to the music's output, whose format this file reads each time Shared/Player says that output changed,
// started again or changed format (ASMVitrinePlayerWatchMusicOutput; voice search's unit or a second chain's is not the
// music's): Sing needs it at the model's 44.1 kHz, float, a buffer per channel, two channels, and otherwise passes
// it as it is. A new output or a new format drops the sound held ahead, which was in the old one.
//
// The lead is sound Spotify's decoder has handed over and the speaker has not played yet, and Spotify's clock
// counts what the decoder handed over when the player reports. -[SPTPlayerState position] is [self
// positionAsOfTimestamp] run on by the time since [self timestamp] (disassembly at 0x1057735ec, its -1 kept for no
// position), and the player reports on a change (a seek, a pause, a track), not as it plays. So what is heard is the
// reported position less the lead held when that line of the clock began, less what was dropped since, and not
// less the lead now: a lead filling after a report does not move what is heard, and taking it off lagged the lyrics
// by it. A state stamped again on the same line (the same position run on at the same speed) is the same report, so
// the lead is looked up by the line, not by the state's stamp (ASMVitrineSingLeadOf). positionAsOfTimestamp and position are
// hooked to take that off: the scrubber, the lyrics, the Live Activity and the lock screen follow what is heard. Run on
// (position), the lead comes off after running on and never below 0: the next track is reported as its first frames
// are handed over, with the last one's end still held, and its clock holds at 0 until that end has played rather than
// running on from the title change. A seek, a
// skip or a stop drops the lead (-[SPTEsperantoPlayer seekTo:...] and skipTo...TrackWithOptions:track:loggingParams:
// in the binary's method list, each returning Spotify's own result for the command; the shorter skips are
// trampolines into those two through objc_msgSend, 0x1096da9e4-0x1096daa08), and so does a track changing well
// before the last one ended: something new was played. The next track in the queue coming up to 12 s early is
// crossfade, which keeps it. Until a seek or a skip lands (Spotify reports the target or the new track, or 5 s pass)
// nothing is read ahead, as Spotify's mixer still hands over what came before it; and on the queue's last track the
// lead drains a second before Spotify's decoder reaches the end, where Spotify may stop its output with it held
// (ASMVitrineSingEngineSetLeadCap).
//
// The model is loaded by ASMVitrineSingLoader.m, only while Spotify is active and the mic is on, and kept a minute after the
// mic goes off: a CPU copy, then on Automatic a Neural Engine copy beside it, which runs the windows once it is in. From the thermal state Serious up the engine is held, plays the song as it is and lets the model go,
// unless Ignore heat warnings is on; it loads again once the iPhone is back at Fair. The model is what heats it, so
// Sing does not keep a hot iPhone hot. A model that falls 8 s behind stops Sing for the rest of the song, which then
// plays as it is; Sing tries again with the next track, when the iPhone cools or when Runs on changes, and stays
// stopped after three in a row with no song kept up. While the Neural Engine copy loads (its first compile among
// them), the CPU's falling behind counts for none of that: the song plays with what vocals are in.
// With the vocals as sung, Spatial voice off and the Sing page's lines not on screen, what Sing plays is the song
// itself, so it rests: the engine is held as for the heat and the model kept a minute as for a mic switched off.
// Whenever Sing does not separate (stopped, held, resting, standing aside), the engine plays the sound it holds ahead
// on as it is, dry, and the clock stays corrected for it: letting it go mid-song would skip that much of the song.
// It goes where nothing heard is lost: a seek, a skip, Spotify's output stopping, or a pause, where Spotify is
// seeked back to what was heard (ASMVitrineSingTrackWatcher), as it is when the headphones it played on go.
//
// Sing stands aside, the model kept, over AirPlay, for what is not a song, and while Spotify plays but its output has
// not rendered for 3 s (another device plays, through Connect). An interruption (a call, Siri, another app's audio)
// holds the worker and keeps the model and the lead for when Spotify plays again, until iOS says it ended or the sound
// comes back; Spotify decides whether it resumes.
//
// Spatial voice listens to Shared/HeadGestures' motion (the app's one CMHeadphoneMotionManager) while Sing is
// on and Spotify plays, and hands the engine the head's yaw off a front that follows where the head points (Back in front,
// 5 s unless set), so the voice drifts back ahead of a head that stays turned and the attitude's own drift never carries
// it off. With no motion (no such headphones, Motion & Fitness not allowed) the voice stays ahead. iOS's own
// spatial audio on the route already holds the whole song in place, so spatial voice stands down for it.
//
// Threading: the stage on the render thread; Spotify starts its output on a thread of its own; the head's
// motion on HeadGestures' queue; the rest main.
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreML/CoreML.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <pthread.h>
#import <stdatomic.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/HeadGestures/HeadGestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/SpeedPitch.h"
#import "Sing.h"
#import "ASMVitrineSingEngine.h"
#import "ASMVitrineSingLoader.h"
#import "ASMVitrineSingSeparator.h"

#if ASMVitrine_DRIVER
// Test builds only: a stand-in for the voice model that hands every window back as all vocals, as harness/sing's does,
// with no model and no heat. The engine reads ahead and builds its lead as it would, and Spatial voice places the
// whole song, so the clock, the lead and the placing can be checked on a phone too hot for the model.
// pref --key asm.interface.vitrine.sing.devStandIn --value 1, then a relaunch.
@interface ASMVitrineSingWholeSeparator : ASMVitrineSingSeparator
@end

@implementation ASMVitrineSingWholeSeparator
- (BOOL)separateLeft:(const float *)left right:(const float *)right vocalsLeft:(float *)vocalsLeft vocalsRight:(float *)vocalsRight error:(NSError **)error {
    memcpy(vocalsLeft, left, kSGSingWindowFrames * sizeof(float));
    memcpy(vocalsRight, right, kSGSingWindowFrames * sizeof(float));
    return YES;
}
@end

static ASMVitrineSingSeparator *standIn(void) {
    static ASMVitrineSingSeparator *separator;
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        on = ASMVitrineFlag(@"asm.interface.vitrine.sing.devStandIn", NO);
        if (on) separator = [[ASMVitrineSingWholeSeparator alloc] initWithModel:nil];
        if (on) ASMVitrineLog(@"sing: STAND-IN: every window is all vocals, no model and no heat hold");
    });
    return separator;
}
#else
static ASMVitrineSingSeparator *standIn(void) {
    return nil;
}
#endif

// The separator the engine runs: the loader's, or a test build's stand-in.
static ASMVitrineSingSeparator *separatorNow(void) {
    return standIn() ?: ASMVitrineSingLoaderSeparator();
}

// The vocals' level until one is chosen: down to a guide.
static const float kDefaultLevel = 0.15f;
// How often what Sing is doing is read while the mic is on.
static const NSTimeInterval kWatchEvery = 0.5;
// A track changing more than this before the last one's end is something new played, not the next track; the next
// track in the queue, up to Spotify's longest crossfade more.
static const double kEndSlack = 2;
static const double kCrossfadeMost = 12;
// Spotify playing with its music output silent this long: it plays on another device.
static const NSTimeInterval kNoOutputFor = 3;

static _Atomic(ASMVitrineSingEngine *) asm_vitrine_engine;   // made the first time the mic is on, never freed
static atomic_bool asm_vitrine_formatTaken;          // Spotify's output is in a format Sing takes
static atomic_bool asm_vitrine_staged;               // the stage has run: Spotify's sound comes through the chain
static atomic_bool asm_vitrine_formatRefused;        // the stage was handed buffers it does not take
static atomic_bool asm_vitrine_outputStarted;        // Spotify has started or connected the music's output
static atomic_bool asm_vitrine_rendered;             // the stage ran since tick last looked
static BOOL asm_vitrine_outputReachable;             // Shared/Player watches the music's output for Sing

#pragma mark - the render thread

typedef struct {
    ASMVitrinePlayerPull pull;
    void *context;
} ChainPull;

static OSStatus pullChain(void *context, UInt32 frames, float *left, float *right, UInt32 *sounding) {
    ChainPull *chain = context;
    struct { AudioBufferList list; AudioBuffer second; } buffers = {{2, {{1, frames * 4, left}}}, {1, frames * 4, right}};
    return chain->pull(chain->context, frames, &buffers.list, sounding);
}

#if ASMVitrine_DRIVER
static atomic_bool asm_vitrine_anchorStageActive;
BOOL ASMVitrineSingAnchorStageActive(void) { return atomic_load(&asm_vitrine_anchorStageActive); }
#endif

static OSStatus stage(UInt32 frames, AudioBufferList *data, ASMVitrinePlayerPull pull, void *context) {
    ASMVitrineSingEngine *engine = atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire);
    #if ASMVitrine_DRIVER
    atomic_store(&asm_vitrine_anchorStageActive, false);
    #endif
    if (!engine) return pull(context, frames, data, NULL);
    atomic_store_explicit(&asm_vitrine_staged, true, memory_order_relaxed);
    atomic_store_explicit(&asm_vitrine_rendered, true, memory_order_relaxed);
    BOOL takes = atomic_load_explicit(&asm_vitrine_formatTaken, memory_order_relaxed) && data->mNumberBuffers == 2;
    for (UInt32 b = 0; takes && b < 2; b++) {
        takes = data->mBuffers[b].mData && data->mBuffers[b].mNumberChannels == 1 && data->mBuffers[b].mDataByteSize == frames * sizeof(float);
    }
    if (!takes) {
        atomic_store_explicit(&asm_vitrine_formatRefused, true, memory_order_relaxed);
        return pull(context, frames, data, NULL);
    }
    #if ASMVitrine_DRIVER
    atomic_store(&asm_vitrine_anchorStageActive, true);
    #endif
    ChainPull chain = {pull, context};
    return ASMVitrineSingEngineRender(engine, frames, data->mBuffers[0].mData, data->mBuffers[1].mData, pullChain, &chain);
}

#pragma mark - Spotify's audio thread

// Under Shared/Player's lock, one call at a time: the last output and format seen are this function's own.
static void musicOutputChanged(AudioUnit output) {
    static AudioUnit last;
    static AudioStreamBasicDescription lastFormat;
    AudioStreamBasicDescription format = {0};
    BOOL known = output && ASMVitrinePlayerMusicClientFormat(&format);
    atomic_store_explicit(&asm_vitrine_outputStarted, output != NULL, memory_order_relaxed);
    BOOL takes = known && format.mFormatID == kAudioFormatLinearPCM && format.mSampleRate == kSGSingRate
                 && format.mChannelsPerFrame == 2 && format.mBitsPerChannel == 32 && (format.mFormatFlags & kAudioFormatFlagIsFloat)
                 && (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
    BOOL changed = output != last || memcmp(&format, &lastFormat, sizeof format) != 0;
    last = output;
    lastFormat = format;
    // The sound held ahead is the old output's or the old format's: dropped before the next render plays any of it.
    ASMVitrineSingEngine *engine = atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire);
    if (changed && engine) ASMVitrineSingEngineFlush(engine);
    if (takes != atomic_exchange(&asm_vitrine_formatTaken, takes) || (changed && !takes)) {
        ASMVitrineLog(@"sing: Spotify hands the music's output %.0f Hz, %u channels, %u bits, flags 0x%x: %@", format.mSampleRate,
              (unsigned)format.mChannelsPerFrame, (unsigned)format.mBitsPerChannel, (unsigned)format.mFormatFlags,
              takes ? @"Sing takes it" : output ? @"not a format Sing takes, its sound passes as it is" : @"no music output now");
    }
}

#pragma mark - the model

static NSString *asm_vitrine_setupError;   // the engine could not be made
static NSString *asm_vitrine_stopped;      // why Sing stopped by itself, with the switch still on
static NSString *asm_vitrine_refused;      // why Sing stands aside for what plays now (AirPlay, not a song); clears by itself

// What stopped it. Falling behind tries again with the next track, when the iPhone cools or when Runs on changes;
// a memory warning with the next track once there is room for the model; this many falls behind in a row, with no
// song kept up between them, stay stopped until the switch goes off and on, so a phone that can never keep up does
// not start and give up all day.
typedef NS_ENUM(NSInteger, ASMVitrineSingStop) { ASMVitrineSingStopNone, ASMVitrineSingStopBehind, ASMVitrineSingStopMemory, ASMVitrineSingStopForGood };
static ASMVitrineSingStop asm_vitrine_stopKind;
static const int kGiveUpsKept = 3;
static int asm_vitrine_giveUps;            // falls behind since a song was last kept up
static BOOL asm_vitrine_sangThisTrack;     // the vocals were down at some point of the track playing

// AirPlay's delay changes as it plays, Spotify playing on another device leaves this iPhone nothing to take the vocals
// from, nor does a podcast or an ad: Sing stands aside, the song plays as it is, and the model is kept for when it can
// run again. Whether that changed.
static NSString *const kOverAirPlay = @"Karaoke does not run over AirPlay, whose delay changes as it plays, so the song plays as it is.";
static NSString *const kElsewhere = @"Spotify plays, but this iPhone has not played any of it for 3 s (it plays on another device), and Karaoke works on "
                                    @"what this iPhone plays itself. It starts once the song plays here.";
static NSString *const kNotASong = @"Karaoke turns down the vocals of songs, and what plays now is not one, so it plays as it is.";
static BOOL asm_vitrine_elsewhere;         // Spotify plays and its music output has not rendered for 3 s (tick)
static BOOL readRefusal(void) {
    NSString *refused = nil;
    for (AVAudioSessionPortDescription *port in AVAudioSession.sharedInstance.currentRoute.outputs) {
        if ([port.portType isEqualToString:AVAudioSessionPortAirPlay]) refused = kOverAirPlay;
    }
    if (!refused && asm_vitrine_elsewhere) refused = kElsewhere;
    NSString *uri = ASMVitrineURIString(ASMVitrinePlayerState().track.URI);
    if (!refused && uri && ![uri hasPrefix:@"spotify:track:"] && ![uri hasPrefix:@"spotify:local:"]) refused = kNotASong;
    if (refused == asm_vitrine_refused || [refused isEqualToString:asm_vitrine_refused]) return NO;
    asm_vitrine_refused = refused;
    ASMVitrineLog(@"sing: %@", refused ?: @"runs again: what plays is a song, on this iPhone, not over AirPlay");
    return YES;
}
static BOOL asm_vitrine_hot;
static BOOL asm_vitrine_active;            // Spotify is the active app: the only time a load starts
static BOOL asm_vitrine_interrupted;       // a call, Siri or another app's audio holds the session: the worker is held
static CFAbsoluteTime asm_vitrine_interruptedAt;

static void announce(void) {
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineSingChangedNotification object:nil];
}

// Runs on: Automatic or CPU only. Automatic is a Neural Engine copy beside the CPU's, on an iPhone with a Neural Engine
// (A12 on): on an iPhone 15 Pro it takes 231-325 ms a window there, against 632-723 ms on the CPU (which keeps up,
// warmer). Once that copy has failed to load, warm up or run a window in this launch, Automatic is the CPU's alone
// until Spotify is opened again or Runs on changes (falling behind is not a failure: that is the budget's, as on any
// copy). A copy past its deadline is not remembered as failed: Core ML carries on compiling a load given up on and
// keeps the result, so the next launch may load it at once.
// The iOS, the app's bundle and the model's folder the Neural Engine copy last loaded on and from: Core ML has kept its
// compiled form, so it loads in seconds. An install moves the bundle (device 2026-10-07: 48-65 s again after each).
static NSString *const kNeuralReadyOn = @"asm.interface.vitrine.sing.neuralReadyOn";
static NSString *asm_vitrine_neuralFailed;   // why the Neural Engine copy is not used for the rest of this launch

static NSString *osBuild(void) {
    return NSProcessInfo.processInfo.operatingSystemVersionString;
}

static NSInteger runsOn(void) {
    return ASMVitrineInt(ASMVitrineKeySingComputeUnits, 0);
}

static NSString *runsOnName(void) {
    return ASMVitrineSingComputeUnitNames()[runsOn() == 1];
}

static BOOL hasNeuralEngine(void) {
    static int has = -1;
    if (has < 0) {
        has = 0;
        if (@available(iOS 17.0, *)) {
            for (id<MLComputeDeviceProtocol> device in MLAllComputeDevices()) {
                if ([device isKindOfClass:MLNeuralEngineComputeDevice.class]) has = 1;
            }
        }
    }
    return has;
}

// Runs on is Automatic, the iPhone has a Neural Engine, its copy has not failed in this launch, and the model is not the
// old one, which the Neural Engine does not run.
static BOOL neuralWanted(void) {
    return runsOn() != 1 && hasNeuralEngine() && !asm_vitrine_neuralFailed && !ASMVitrineSingModelUpdateAvailable();
}

// What Core ML keeps the compiled model for: this iOS, this install and the model's folder.
static NSString *neuralCompiled(void) {
    return [NSString stringWithFormat:@"%@ %@ %@", osBuild(), NSBundle.mainBundle.bundlePath, ASMVitrineSingModelURL().path];
}

static void wantModel(void) {
    ASMVitrineSingLoaderWant(ASMVitrineSingModelURL(), neuralWanted());
}

// The Neural Engine copy given up on for the rest of the launch: the CPU's carries on alone.
static void apply(void);
static void neuralFailed(NSString *why) {
    if (asm_vitrine_neuralFailed) return;
    asm_vitrine_neuralFailed = why;
    ASMVitrineLog(@"sing: the Neural Engine copy %@, so Karaoke runs on the CPU copy for the rest of this launch", why);
    if (ASMVitrineSingOn()) apply();
}

// The first load on this iOS, from this folder, compiles the model for the Neural Engine.
static BOOL preparingNeural(void) {
    return ASMVitrineSingLoaderFastState() == ASMVitrineSingFastLoading
           && ![[NSUserDefaults.standardUserDefaults stringForKey:kNeuralReadyOn] isEqualToString:neuralCompiled()];
}

// While the Neural Engine copy loads or warms up, the CPU's falling behind is "not yet", not "cannot": the engine's
// budget is held, so no song is given up and no strike counted, until the copy is in or has failed.
static void holdBudget(ASMVitrineSingEngine *engine) {
    static BOOL held;
    BOOL hold = ASMVitrineSingLoaderFastState() == ASMVitrineSingFastLoading;
    if (engine) ASMVitrineSingEngineHoldBudget(engine, hold);
    if (hold == held) return;
    held = hold;
    ASMVitrineLog(@"sing: %@", hold ? @"falling behind spends none of the 8 s while the Neural Engine copy loads" : @"falling behind counts again");
}

// The loader's news: the separator into the engine, the Neural Engine copy loaded (remembered) or failed (the CPU's
// alone from then on).
static void loaderChanged(void) {
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (engine) ASMVitrineSingEngineSetSeparator(engine, separatorNow());
    switch (ASMVitrineSingLoaderFastState()) {
        case ASMVitrineSingFastReady: [NSUserDefaults.standardUserDefaults setObject:neuralCompiled() forKey:kNeuralReadyOn]; break;
        case ASMVitrineSingFastFailed: neuralFailed(@"did not load"); break;
        case ASMVitrineSingFastTimedOut: neuralFailed([NSString stringWithFormat:@"did not load in %.0f minutes", ASMVitrineSingLoaderNeuralDeadline / 60]); break;
        default: break;
    }
    holdBudget(engine);
    announce();
}

// After an install or an iOS update the Neural Engine copy compiles again (48-65 s on an iPhone 15 Pro), a minute in
// which the mic has only the CPU's copy, which a warm iPhone cannot keep up with. With the model in and the mic off it
// compiles ahead instead, once Spotify has been in front a while, the iPhone is below Serious and nothing else loads.
static const NSTimeInterval kPrepareAfter = 15;

static void prepareAhead(void) {
    NSString *compiled = neuralCompiled();
    if (!ASMVitrineEnabled(ASMVitrineKeySingPrepareAhead) || ASMVitrineSingOn() || !asm_vitrine_active || !neuralWanted() || ASMVitrineSingModelCurrentState() != ASMVitrineSingModelReady
        || [[NSUserDefaults.standardUserDefaults stringForKey:kNeuralReadyOn] isEqualToString:compiled]) return;
    if (NSProcessInfo.processInfo.thermalState >= NSProcessInfoThermalStateSerious) {
        static BOOL told;
        if (!told) ASMVitrineLog(@"sing: the Neural Engine copy waits to be prepared until the iPhone is cooler (thermal state %s)", ASMVitrineSingThermalName());
        told = YES;
        return;
    }
    CFAbsoluteTime began = CFAbsoluteTimeGetCurrent();
    BOOL started = ASMVitrineSingLoaderPrepareNeural(ASMVitrineSingModelURL(), ^(BOOL loaded) {
        if (loaded) [NSUserDefaults.standardUserDefaults setObject:compiled forKey:kNeuralReadyOn];
        ASMVitrineLog(@"sing: the Neural Engine copy %@ ahead of the mic in %.0f s, and is let go (thermal state now %s)",
              loaded ? @"is prepared" : @"was not prepared", CFAbsoluteTimeGetCurrent() - began, ASMVitrineSingThermalName());
    });
    if (started) ASMVitrineLog(@"sing: prepares the Neural Engine copy ahead of the mic, for this install");
}

static void prepareAheadSoon(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPrepareAfter * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        prepareAhead();
    });
}

#pragma mark - spatial voice

static BOOL asm_vitrine_spatialListening;
// On HeadGestures' motion queue only.
static ASMVitrineSpatialFront asm_vitrine_front;
// Back in front, read on the motion queue: stored on the main thread.
static _Atomic double asm_vitrine_frontSeconds = 5;

static void headMoved(CMDeviceMotion *motion) {
    ASMVitrineSingEngine *engine = atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire);
    if (!motion) {
        asm_vitrine_front.hasFront = false;
        if (engine) ASMVitrineSingEngineSetVoiceAngle(engine, 0);
        return;
    }
    double angle = ASMVitrineSpatialVoiceAngle(&asm_vitrine_front, motion.attitude.yaw, motion.timestamp, asm_vitrine_frontSeconds);
    if (engine) ASMVitrineSingEngineSetVoiceAngle(engine, (float)angle);
}

// iOS's own spatial audio (Spatialize Stereo, or a spatial headphone's own) on the route.
static BOOL systemSpatial(void) {
    for (AVAudioSessionPortDescription *port in AVAudioSession.sharedInstance.currentRoute.outputs) {
        if (port.spatialAudioEnabled) return YES;
    }
    return NO;
}

// Listens to the head while Sing is on, spatial voice is on and Spotify plays, and iOS does not hold the song in
// place itself; otherwise the voice goes back ahead (HeadGestures hands a listener taken out nil).
static void updateSpatial(void) {
    SPTPlayerState *player = ASMVitrinePlayerState();
    BOOL wanted = ASMVitrineSingOn() && !ASMVitrineSingMissing() && ASMVitrineSingSpatial() && player.isPlaying && !player.isPaused;
    BOOL listen = wanted && !systemSpatial();
    if (listen == asm_vitrine_spatialListening) return;
    asm_vitrine_spatialListening = listen;
    ASMVitrineLog(@"sing: spatial voice %@", listen ? @"follows the head" : wanted ? @"stands down for iOS's own spatial audio" : @"is ahead");
    ASMVitrineHeadMotionListen(@"sing", listen ? ^(CMDeviceMotion *motion) { headMoved(motion); } : nil);
}

BOOL ASMVitrineSingSpatialAvailable(void) {
    return ASMVitrineSingOSSupported() && ASMVitrineHeadGesturesAvailable();
}

BOOL ASMVitrineSingSpatial(void) {
    return ASMVitrineHidden(ASMVitrineKeySingSpatial);
}

static double storedNumber(NSString *key, double fallback, double low, double high) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    double number = [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
    return isfinite(number) ? fmin(high, fmax(low, number)) : fallback;
}

double ASMVitrineSingSpatialDistance(void) {
    return storedNumber(ASMVitrineKeySingSpatialDistance, 1.5, 1, 6.5);
}

double ASMVitrineSingSpatialRoom(void) {
    return storedNumber(ASMVitrineKeySingSpatialRoom, 25, 0, 100);
}

double ASMVitrineSingSpatialFront(void) {
    return storedNumber(ASMVitrineKeySingSpatialFront, 5, 5, 60);
}

double ASMVitrineSingSpatialWidth(void) {
    return storedNumber(ASMVitrineKeySingSpatialWidth, 110, 0, 200);
}

// The engine's Distance and Room, on while Spatial voice is.
static void applySpatialSound(ASMVitrineSingEngine *engine) {
    if (engine) ASMVitrineSingEngineSetSpatial(engine, ASMVitrineSingSpatial(), ASMVitrineSingSpatialDistance(), ASMVitrineSingSpatialRoom() / 100, ASMVitrineSingSpatialWidth() / 100);
}

void ASMVitrineSetSingSpatialSound(double meters, double roomPercent, double frontSeconds, double widthPercent) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setDouble:meters forKey:ASMVitrineKeySingSpatialDistance];
    [defaults setDouble:roomPercent forKey:ASMVitrineKeySingSpatialRoom];
    [defaults setDouble:frontSeconds forKey:ASMVitrineKeySingSpatialFront];
    [defaults setDouble:widthPercent forKey:ASMVitrineKeySingSpatialWidth];
    asm_vitrine_frontSeconds = ASMVitrineSingSpatialFront();
    applySpatialSound(atomic_load(&asm_vitrine_engine));
}

static void updateRest(void);

void ASMVitrineSetSingSpatial(BOOL on) {
    ASMVitrineSetEnabled(ASMVitrineKeySingSpatial, on);
    applySpatialSound(atomic_load(&asm_vitrine_engine));
    // Asked while the Sing page is in front, rather than with the next song.
    if (on) ASMVitrineHeadMotionAskPermission();
    updateSpatial();
    updateRest();
}

#pragma mark - the state

static void watch(void);

// Resting: nothing needs the model, so the engine is held as for the heat and the song plays straight. The vocals are
// as sung (which plays exactly the song), Spatial voice is off, and no page traces the lines: the Sing page's card
// reads them thirty times a second while it shows with Spotify in front (ASMVitrineSingReadLevels), so a second without a
// read is the page gone (popped, covered or in the background). The lyrics page reads none: it is not a viewer.
static const CFTimeInterval kLinesGoneAfter = 1;
static CFAbsoluteTime asm_vitrine_linesReadAt;
static BOOL asm_vitrine_resting;

static BOOL restful(void) {
    BOOL held = asm_vitrine_hot && !ASMVitrineHidden(ASMVitrineKeySingIgnoreHeat) && !standIn();
    return ASMVitrineSingOn() && !ASMVitrineSingMissing() && !held && !asm_vitrine_stopped && !asm_vitrine_refused && fabsf(ASMVitrineSingLevel() - 1) <= 0.001f && !ASMVitrineSingSpatial()
           && CFAbsoluteTimeGetCurrent() - asm_vitrine_linesReadAt > kLinesGoneAfter;
}

static void apply(void) {
    BOOL on = ASMVitrineSingOn() && !ASMVitrineSingMissing();
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (on && !engine) {
        engine = ASMVitrineSingEngineCreate();
        if (!engine) {
            asm_vitrine_setupError = @"Karaoke could not set aside memory for the song.";
            return;
        }
        ASMVitrineSingEngineSetLevel(engine, ASMVitrineSingLevel());
        applySpatialSound(engine);
        atomic_store_explicit(&asm_vitrine_engine, engine, memory_order_release);
    }
    BOOL held = asm_vitrine_hot && !ASMVitrineHidden(ASMVitrineKeySingIgnoreHeat) && !standIn();
    // Off, the model is kept a minute for a quick off and on. Held for the heat, it is let go at once, which frees
    // its memory and stops its work; it loads again once the iPhone cools.
    // ponytail: a phone flickering about Serious loads and drops the model each time; add a cooling-off delay if logs show it.
    // Stopped by itself, the song plays as it is and the switch stays on to say why; the model is kept, but for a
    // memory warning's stop, which let it go. Resting, the model is kept as for a mic switched off.
    BOOL rest = restful(), toRest = rest && !asm_vitrine_resting;
    if (rest != asm_vitrine_resting) {
        asm_vitrine_resting = rest;
        if (rest) ASMVitrineLog(@"sing: rests, the vocals as sung, Spatial voice off and the lines not shown: the song plays as it is, the model kept %.0f s",
                        ASMVitrineSingLoaderKeepSeconds);
        else if (on && !held && !asm_vitrine_stopped && !asm_vitrine_refused) ASMVitrineLog(@"sing: separates again (the vocals at %.2f, Spatial voice %@, the lines %@)", ASMVitrineSingLevel(),
                   ASMVitrineSingSpatial() ? @"on" : @"off", CFAbsoluteTimeGetCurrent() - asm_vitrine_linesReadAt > kLinesGoneAfter ? @"not shown" : @"shown");
    }
    if (asm_vitrine_stopped || asm_vitrine_refused) on = NO;
    else if (!on) ASMVitrineSingLoaderRelease();
    else if (held) ASMVitrineSingLoaderPurge(@"the iPhone is too hot (thermal state serious or above)");
    else if (rest) { if (toRest) ASMVitrineSingLoaderRelease(); }
    else if (asm_vitrine_active && !standIn()) wantModel();
    if (!engine) return;
    ASMVitrineSingEngineSetSeparator(engine, separatorNow());
    holdBudget(engine);
    ASMVitrineSingEngineSetPaused(engine, held || rest || asm_vitrine_interrupted);
    ASMVitrineSingEngineSetOn(engine, on);
    double lead = ASMVitrineSingEngineLead(engine);
    if ((!on || held || rest || asm_vitrine_interrupted) && lead > 0.05) ASMVitrineLog(@"sing: keeps the %.2f s held ahead, played as it is, until Spotify pauses, seeks or skips", lead);
    updateSpatial();
    watch();
}

// Called as often as the slider moves: applies only when resting would change.
static void updateRest(void) {
    if (restful() != asm_vitrine_resting) apply();
}

BOOL ASMVitrineSingOn(void) {
    return ASMVitrineHidden(ASMVitrineKeySing);
}

void ASMVitrineSetSingOn(BOOL on) {
    ASMVitrineSetEnabled(ASMVitrineKeySing, on);
    asm_vitrine_stopped = nil;
    asm_vitrine_stopKind = ASMVitrineSingStopNone;
    asm_vitrine_giveUps = 0;
    ASMVitrineLog(@"sing: the mic is %@", on ? @"on" : @"off");
    // Read only while on: what it was when last on may be gone.
    readRefusal();
    apply();
    announce();
}

// A stop for falling behind is over (and one for memory too, with `memory` and room for the model): Sing tries again.
static void retry(NSString *why, BOOL memory) {
    BOOL behind = asm_vitrine_stopKind == ASMVitrineSingStopBehind, lowMemory = memory && asm_vitrine_stopKind == ASMVitrineSingStopMemory && ASMVitrineSingLoaderHasRoom();
    if (!ASMVitrineSingOn() || (!behind && !lowMemory)) return;
    asm_vitrine_stopped = nil;
    asm_vitrine_stopKind = ASMVitrineSingStopNone;
    ASMVitrineLog(@"sing: tries again, %@ (%d fell behind in a row)", why, asm_vitrine_giveUps);
    apply();
    announce();
}

BOOL ASMVitrineSingReadLevels(float *vocals, float *rest, int count) {
    // A page tracing the lines is on screen: Sing separates for it.
    asm_vitrine_linesReadAt = CFAbsoluteTimeGetCurrent();
    if (asm_vitrine_resting) updateRest();
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (!engine || ASMVitrineSingCurrentState() != ASMVitrineSingStateSinging) return NO;
    ASMVitrineSingEngineReadLevels(engine, vocals, rest, count);
    // As heard: the vocals' gain up to 1, then the rest's down to nothing at 2.
    float level = ASMVitrineSingLevel(), vocalsGain = fminf(level, 1), restGain = level <= 1 ? 1 : 2 - level;
    for (int k = 0; k < count; k++) {
        vocals[k] *= vocalsGain;
        rest[k] *= restGain;
    }
    return YES;
}

float ASMVitrineSingLevel(void) {
    NSNumber *stored = [NSUserDefaults.standardUserDefaults objectForKey:ASMVitrineKeySingLevel];
    return stored ? fmaxf(0, fminf(stored.floatValue, 2)) : kDefaultLevel;
}

void ASMVitrineSetSingLevel(float level) {
    level = fmaxf(0, fminf(level, 2));
    [NSUserDefaults.standardUserDefaults setFloat:level forKey:ASMVitrineKeySingLevel];
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (engine) ASMVitrineSingEngineSetLevel(engine, level);
    updateRest();
}

void ASMVitrineSingComputeUnitsChanged(void) {
    // A choice made is a new try, the Neural Engine's included.
    asm_vitrine_neuralFailed = nil;
    ASMVitrineLog(@"sing: Runs on is now %@", runsOnName());
    // Somewhere else to run is a fresh try, however often it fell behind before.
    asm_vitrine_giveUps = 0;
    if (asm_vitrine_stopKind == ASMVitrineSingStopForGood) asm_vitrine_stopKind = ASMVitrineSingStopBehind;
    retry(@"Runs on changed", NO);
    if (ASMVitrineSingOn()) apply();
    announce();
}

void ASMVitrineSetSingIgnoresHeat(BOOL ignores) {
    ASMVitrineSetEnabled(ASMVitrineKeySingIgnoreHeat, ignores);
    apply();
    announce();
}

NSString *ASMVitrineSingMissing(void) {
    if (!ASMVitrineSingOSSupported()) return [NSString stringWithFormat:@"Karaoke needs iOS 18, the first its voice model runs on. This iPhone has iOS %@.", UIDevice.currentDevice.systemVersion];
    if (ASMVitrineSingModelCurrentState() != ASMVitrineSingModelReady) return [NSString stringWithFormat:@"Karaoke needs its voice model, which is downloaded from Mod Settings > Karaoke (%@).", ASMVitrineSingModelSizeText()];
    return nil;
}

ASMVitrineSingState ASMVitrineSingCurrentState(void) {
    if (!ASMVitrineSingOSSupported()) return ASMVitrineSingStateUnavailable;
    ASMVitrineSingModelState model = ASMVitrineSingModelCurrentState();
    if (model == ASMVitrineSingModelDownloading) return ASMVitrineSingStateDownloading;
    if (model != ASMVitrineSingModelReady) return ASMVitrineSingStateNoModel;
    if (!ASMVitrineSingOn()) return ASMVitrineSingStateOff;
    // Held for the heat, the model is let go: held, not loading.
    if (asm_vitrine_hot && !ASMVitrineHidden(ASMVitrineKeySingIgnoreHeat)) return ASMVitrineSingStateHot;
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (asm_vitrine_stopped || asm_vitrine_refused || ASMVitrineSingLoaderError() || !engine || ASMVitrineSingEngineError(engine)) return ASMVitrineSingStateFailed;
    // Resting, ready for the level to move, whether the model is still kept or not.
    if (asm_vitrine_resting) return ASMVitrineSingStateWaiting;
    // Interrupted: held, nothing plays, nothing is behind.
    if (asm_vitrine_interrupted && separatorNow()) return ASMVitrineSingStateWaiting;
    if (!separatorNow()) return ASMVitrineSingStatePreparing;
    // Spotify plays and Speed and pitch never took its output over: the stage, and so Sing, never runs.
    if (!atomic_load(&asm_vitrine_staged) && atomic_load(&asm_vitrine_outputStarted) && !ASMVitrinePlayerSpeedAllowed()) return ASMVitrineSingStateFailed;
    if (!asm_vitrine_outputReachable || (atomic_load(&asm_vitrine_staged) && atomic_load(&asm_vitrine_formatRefused) && !atomic_load(&asm_vitrine_formatTaken))) return ASMVitrineSingStateFailed;
    ASMVitrineSingEngineStats stats = ASMVitrineSingEngineReadStats(engine);
    if (!atomic_load(&asm_vitrine_staged) || stats.lead < 0.05) return ASMVitrineSingStateWaiting;
    if (stats.mixing) return ASMVitrineSingStateSinging;
    // The lead is full and the vocals are still not in: the model is slower than the song.
    if (stats.windows && (stats.averageMS > kSGSingEngineHop * 1000.0 / kSGSingRate || stats.lead >= stats.targetLead - 0.25)) return ASMVitrineSingStateBehind;
    return ASMVitrineSingStateBuffering;
}

NSString *ASMVitrineSingStatusText(void) {
    switch (ASMVitrineSingCurrentState()) {
        case ASMVitrineSingStateUnavailable: return @"Unavailable";
        case ASMVitrineSingStateNoModel: return @"Needs its voice model";
        case ASMVitrineSingStateDownloading:
            if (ASMVitrineSingModelChecking()) return @"Checking the download";
            if (ASMVitrineSingModelWaitingForNetwork()) return ASMVitrineSingModelOverCellular() ? @"Waiting for the network" : @"Waiting for Wi-Fi";
            return [NSString stringWithFormat:@"Downloading %.0f%%", ASMVitrineSingModelProgress() * 100];
        case ASMVitrineSingStateOff: return ASMVitrineSingLoaderPreparingSeconds() >= 0 ? @"Off · preparing for the Neural Engine" : @"Off";
        case ASMVitrineSingStatePreparing: {
            NSTimeInterval seconds = ASMVitrineSingLoaderSeconds();
            return seconds >= 1 ? [NSString stringWithFormat:@"Loading the voice model, %.0f s", seconds] : @"Loading the voice model";
        }
        case ASMVitrineSingStateWaiting: return asm_vitrine_resting ? @"As sung" : @"Ready";
        case ASMVitrineSingStateBuffering: return @"Listening ahead";
        case ASMVitrineSingStateSinging: {
            ASMVitrineSingSeparator *separator = ASMVitrineSingLoaderSeparator();
            return separator && [separator stats].fast ? @"On, Neural Engine" : @"On, CPU";
        }
        // The Neural Engine copy on its way: the budget is held (holdBudget), so this is not yet Too slow.
        case ASMVitrineSingStateBehind:
            return ASMVitrineSingLoaderFastState() == ASMVitrineSingFastLoading ? @"Preparing for the Neural Engine" : @"Too slow";
        case ASMVitrineSingStateHot: return @"Held, too hot";
        case ASMVitrineSingStateFailed:
            if (!asm_vitrine_stopped && asm_vitrine_refused) return asm_vitrine_refused == kOverAirPlay ? @"Off over AirPlay" : asm_vitrine_refused == kElsewhere ? @"Not on this iPhone" : @"Songs only";
            return asm_vitrine_stopped ? @"Stopped" : @"Failed";
    }
    return @"";
}

// Where the model runs now, for the details of a working Sing.
static NSString *runsOnNote(void) {
    if (ASMVitrineSingModelUpdateAvailable()) {
        return [NSString stringWithFormat:@"Karaoke runs on the CPU with the voice model it had before. Its update (%@, on the Voice model row) runs "
                                          @"on the Neural Engine, faster and cooler.", ASMVitrineSingModelSizeText()];
    }
    if (runsOn() == 1) return @"Karaoke runs on the CPU alone, as Runs on says.";
    if (!hasNeuralEngine()) return @"This iPhone has no Neural Engine Karaoke can use, so it runs on the CPU.";
    if (asm_vitrine_neuralFailed) {
        return [NSString stringWithFormat:@"The Neural Engine copy of the voice model %@, so Karaoke runs on the CPU until Spotify is opened again.", asm_vitrine_neuralFailed];
    }
    if (preparingNeural()) {
        return [NSString stringWithFormat:@"Preparing for the Neural Engine, first time only (%.0f s so far). Karaoke runs on the CPU until then.",
                ASMVitrineSingLoaderFastSeconds()];
    }
    switch (ASMVitrineSingLoaderFastState()) {
        case ASMVitrineSingFastNone: return @"Karaoke runs on the CPU; the Neural Engine copy loads once Spotify is open.";
        case ASMVitrineSingFastLoading: return @"Karaoke runs on the CPU while the Neural Engine copy loads.";
        case ASMVitrineSingFastReady: return @"Karaoke runs on the Neural Engine.";
        case ASMVitrineSingFastSkipped: return @"Too little memory is left for the Neural Engine copy, so Karaoke runs on the CPU alone.";
        case ASMVitrineSingFastFailed: return @"The Neural Engine could not load the voice model, so Karaoke runs on the CPU alone.";
        case ASMVitrineSingFastTimedOut: return [NSString stringWithFormat:@"The Neural Engine did not load the voice model in %.0f minutes, so Karaoke runs on the CPU alone.",
                                         ASMVitrineSingLoaderNeuralDeadline / 60];
    }
    return nil;
}

NSString *ASMVitrineSingStatusDetail(void) {
    switch (ASMVitrineSingCurrentState()) {
        case ASMVitrineSingStateUnavailable:
        case ASMVitrineSingStateNoModel:
            return ASMVitrineSingMissing();
        case ASMVitrineSingStateDownloading:
            if (ASMVitrineSingModelWaitingForNetwork()) {
                if (!ASMVitrineSingModelOverCellular()) {
                    return [NSString stringWithFormat:@"The voice model's download waits for Wi-Fi, as %@ is a lot of a cellular plan, and carries on from %.0f%% once "
                                                      @"the iPhone is on Wi-Fi. The Voice model row on the Karaoke page can let it use cellular.",
                            ASMVitrineSingModelSizeText(), ASMVitrineSingModelProgress() * 100];
                }
                return [NSString stringWithFormat:@"The iPhone is offline. The voice model's download carries on from %.0f%% of %@ once it is online again.",
                        ASMVitrineSingModelProgress() * 100, ASMVitrineSingModelSizeText()];
            }
            return [NSString stringWithFormat:@"The voice model is coming in, %.0f%% of %@. Karaoke starts once it is checked.", ASMVitrineSingModelProgress() * 100, ASMVitrineSingModelSizeText()];
        case ASMVitrineSingStateOff: {
            NSTimeInterval seconds = ASMVitrineSingLoaderPreparingSeconds();
            if (seconds < 0) return nil;
            return [NSString stringWithFormat:@"After an update, the iPhone prepares the voice model for the Neural Engine once, which takes about a minute. "
                                              @"Vitrine does it now, in the background, so Karaoke starts at full speed when it is switched on (%.0f s so far).", seconds];
        }
        case ASMVitrineSingStateWaiting:
            if (asm_vitrine_resting) {
                return @"The vocals are as sung and Spatial voice is off, so the song plays as it is and the voice model rests. Karaoke starts again "
                       @"when the level moves, Spatial voice goes on, or the Karaoke page opens.";
            }
            return [NSString stringWithFormat:@"The voice model is ready, and Karaoke starts once Spotify plays a song. %@", runsOnNote()];
        case ASMVitrineSingStatePreparing:
            if (ASMVitrineSingLoaderCurrentState() == ASMVitrineSingLoaderIdle) return @"The voice model loads once Spotify is open.";
            return [NSString stringWithFormat:@"Core ML prepares the voice model for this iPhone's CPU, %.0f s so far, then Karaoke starts. The first time, that can take a minute.",
                    ASMVitrineSingLoaderSeconds()];
        case ASMVitrineSingStateBuffering:
            return @"Karaoke listens a few seconds ahead of what plays, so the vocals are separated before you hear them. Until then the song plays as it is.";
        case ASMVitrineSingStateSinging:
            return runsOnNote();
        case ASMVitrineSingStateBehind: {
            ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
            double ms = engine ? ASMVitrineSingEngineReadStats(engine).averageMS : 0;
            return [NSString stringWithFormat:@"The voice model takes %.1f s for every 1.5 s of song on this iPhone, so the vocals stay in until it catches up. %@",
                    ms / 1000, runsOnNote()];
        }
        case ASMVitrineSingStateHot:
            return @"The iPhone is hot, so Karaoke has let go of the voice model and the song plays as it is. Karaoke loads it again once the iPhone cools. "
                   @"Ignore heat warnings keeps Karaoke going.";
        case ASMVitrineSingStateFailed: {
            ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
            if (asm_vitrine_stopped ?: asm_vitrine_refused) return asm_vitrine_stopped ?: asm_vitrine_refused;
            NSString *error = ASMVitrineSingLoaderError() ?: (engine ? ASMVitrineSingEngineError(engine) : asm_vitrine_setupError);
            if (ASMVitrineSingLoaderError()) return [error stringByAppendingString:@" Switch Karaoke off and on again to try again."];
            if (error) return error;
            if (!asm_vitrine_outputReachable) return @"Spotify's output could not be reached.";
            if (!atomic_load(&asm_vitrine_staged) && !ASMVitrinePlayerSpeedAllowed()) return @"Spotify's output could not be taken over, so Karaoke cannot reach its sound.";
            return @"Spotify's output is not 44.1 kHz stereo, which the voice model needs, so the song plays as it is.";
        }
        default:
            return nil;
    }
}

NSString *ASMVitrineSingSummary(void) {
    switch (ASMVitrineSingCurrentState()) {
        case ASMVitrineSingStateUnavailable: return @"Unavailable";
        case ASMVitrineSingStateNoModel: return @"Off";
        case ASMVitrineSingStateDownloading: return [NSString stringWithFormat:@"%.0f%%", ASMVitrineSingModelProgress() * 100];
        case ASMVitrineSingStateOff: return @"Off";
        default: return @"On";
    }
}

#pragma mark - watching while the mic is on

static NSTimer *asm_vitrine_watch;
static ASMVitrineSingState asm_vitrine_shown = -1;
static NSString *asm_vitrine_shownText;
static NSString *asm_vitrine_lastTrack;
static double asm_vitrine_lastRaw = -1, asm_vitrine_lastDuration;
static _Atomic CFAbsoluteTime asm_vitrine_lastFlush;   // Sing.x's own flushes: each comes with a report of Spotify's
static __thread BOOL asm_vitrine_rawPosition;   // the hook below hands Spotify's own value back

static double rawPosition(SPTPlayerState *state) {
    BOOL was = asm_vitrine_rawPosition;
    asm_vitrine_rawPosition = YES;
    double position = state.position;
    asm_vitrine_rawPosition = was;
    return position;
}

double ASMVitrineSingSourcePosition(SPTPlayerState *state) { return rawPosition(state); }

double ASMVitrineSingHeldLead(void) {
    return ASMVitrineSingEngineLead(atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire));
}

// Spotify's clock runs on lines: a position at a moment, run on at the playback speed (paused, it holds). A seek, a
// track, a pause or a resume starts a new line; a state that is the same line stamped again later is not a new
// report of what the decoder handed over, so its lead is the one at the line's first state seen, not at its own
// timestamp. Two states are one line when they put the clock within kSameLine of each other at the same speed.
typedef struct {
    double origin;           // the position at the reference date, running; the held position, paused
    double speed;
    bool paused;
    CFAbsoluteTime firstAt;  // when the line began, by the first state of it seen
} ClockLine;
enum { kLines = 8 };
static const double kSameLine = 0.25;
static ClockLine asm_vitrine_lines[kLines];
static unsigned asm_vitrine_lineCount;
static os_unfair_lock asm_vitrine_linesLock = OS_UNFAIR_LOCK_INIT;

static double rawAsOf(SPTPlayerState *state) {
    BOOL was = asm_vitrine_rawPosition;
    asm_vitrine_rawPosition = YES;
    double position = state.positionAsOfTimestamp;
    asm_vitrine_rawPosition = was;
    return position;
}

// When the line `state` is on began, for the lead held then: the stamp of the first state of it seen. The stamp is this
// iPhone's clock, as -position runs on from it by timeIntervalSinceNow.
// ponytail: a line first seen through a state stamped after it began reads the lead of that later moment; Spotify's
// own UI, the lyrics and tick read the player at least twice a second, so that is a fill's half second at most.
static CFAbsoluteTime lineStart(SPTPlayerState *state, CFAbsoluteTime at, double asOf) {
    double speed = [state respondsToSelector:@selector(playbackSpeed)] ? state.playbackSpeed : 1;
    if (!(speed > 0)) speed = 1;
    bool paused = state.isPaused;
    double origin = paused ? asOf : asOf - at * speed;
    CFAbsoluteTime first = at;
    os_unfair_lock_lock(&asm_vitrine_linesLock);
    bool found = false;
    for (unsigned k = 0; k < MIN(asm_vitrine_lineCount, (unsigned)kLines) && !found; k++) {
        ClockLine *line = &asm_vitrine_lines[(asm_vitrine_lineCount - 1 - k) % kLines];
        // A state stamped after a seek, a skip or a pause's seek back is that report, a new line even where it runs on
        // from the last (a seek back to what was heard).
        CFAbsoluteTime flushed = atomic_load_explicit(&asm_vitrine_lastFlush, memory_order_relaxed);
        bool reported = line->firstAt < flushed && flushed <= at;
        if (!reported && line->paused == paused && fabs(line->speed - speed) < 1e-3 && fabs(line->origin - origin) < kSameLine * (paused ? 1 : speed)) {
            first = line->firstAt;
            found = true;
        }
    }
    if (!found) asm_vitrine_lines[asm_vitrine_lineCount++ % kLines] = (ClockLine){origin, speed, paused, at};
    os_unfair_lock_unlock(&asm_vitrine_linesLock);
    return first;
}

double ASMVitrineSingLeadOf(SPTPlayerState *state) {
    ASMVitrineSingEngine *engine = atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire);
    if (!engine || !state) return 0;
    NSDate *at = [state respondsToSelector:@selector(timestamp)] ? state.timestamp : nil;
    double asOf = rawAsOf(state);
    if (![at isKindOfClass:NSDate.class] || asOf < 0) return ASMVitrineSingEngineLead(engine);
    return ASMVitrineSingEngineLeadAt(engine, lineStart(state, at.timeIntervalSinceReferenceDate, asOf));
}

// The last absolute seek's target and the frames pulled when it was asked: from then to the next track, what is heard
// is the target run on by the frames played since, whatever Spotify's clock does. For the log only.
static double asm_vitrine_seekTarget = -1;
static uint64_t asm_vitrine_seekWritten;

static void seekAnchor(double target) {
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (!engine) return;
    asm_vitrine_seekTarget = target;
    asm_vitrine_seekWritten = ASMVitrineSingEngineReadStats(engine).written;
}

// Every 5 s while a lead is held or was: Spotify's clock against what the engine pulled and played, for the state
// Shared/Player reports and the one the lyrics read, so a phone's log says which clock Spotify keeps.
static void logClock(ASMVitrineSingEngine *engine) {
    static CFAbsoluteTime last;
    static ASMVitrineSingEngineStats before;
    static double rawBefore = -1;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (!engine || now - last < 5) return;
    ASMVitrineSingEngineStats stats = ASMVitrineSingEngineReadStats(engine);
    if (stats.lead <= 0 && stats.dropped == before.dropped && last) {
        last = now;
        return;
    }
    NSMutableString *line = [NSMutableString stringWithFormat:@"sing: clock: lead %.2f s held, %.2f s dropped", stats.lead, stats.dropped];
    double elapsed = last ? now - last : 0;
    if (elapsed > 0) {
        [line appendFormat:@"; over %.1f s Spotify's mixer gave %.2f s, %.2f s played", elapsed, (double)(stats.written - before.written) / kSGSingRate,
                           (double)(stats.played - before.played) / kSGSingRate];
    }
    SPTPlayerState *reported = ASMVitrinePlayerState();
    id player = ASMVitrineKaraokePlayer();
    SPTPlayerState *read = [player respondsToSelector:@selector(state)] ? [(id<SPTPlayer>)player state] : nil;
    NSArray *states = read && read != reported ? @[reported ?: (id)NSNull.null, read] : @[reported ?: (id)NSNull.null];
    for (NSUInteger i = 0; i < states.count; i++) {
        SPTPlayerState *state = states[i];
        if (![state isKindOfClass:objc_getClass("SPTPlayerState")]) continue;
        double raw = rawPosition(state), correction = ASMVitrineSingLeadOf(state);
        NSDate *at = [state respondsToSelector:@selector(timestamp)] ? state.timestamp : nil;
        [line appendFormat:@"; %@ state: Spotify's position %.2f s (as of %.2f s, stamped %.2f s ago%@), %.2f s taken off", i ? @"the lyrics'" : @"the reported",
                           raw, rawAsOf(state), at ? now - at.timeIntervalSinceReferenceDate : -1, state.isPaused ? @", paused" : @"", correction];
        if (i == 0 && rawBefore >= 0 && elapsed > 0) [line appendFormat:@", moved %.2f s", raw - rawBefore];
        if (i == 0) rawBefore = raw;
        if (i == 0 && asm_vitrine_seekTarget >= 0) {
            double heard = asm_vitrine_seekTarget + ((double)stats.played - (double)asm_vitrine_seekWritten) / kSGSingRate;
            [line appendFormat:@", heard by the last seek %.2f s (Spotify's position less that: %.2f s)", heard, raw - heard];
        }
    }
    ASMVitrineLog(@"%@", line);
    last = now;
    before = stats;
}

// Reading ahead stopped where Spotify's mixer had no sound yet (ASMVitrineSingEngineRender): the first few times a launch, then
// how often a minute.
static void logAheadStops(ASMVitrineSingEngine *engine) {
    static const int kTold = 3;
    static int told;
    static unsigned long long seen, atMinute;
    static CFAbsoluteTime minute;
    if (!engine) return;
    unsigned long long stops = ASMVitrineSingEngineReadStats(engine).aheadStops;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (stops > seen && told < kTold) {
        told++;
        ASMVitrineLog(@"sing: read ahead: Spotify's mixer marked the sound past what plays silent (not decoded yet), so it is not "
              @"taken into the lead and reading ahead stops until the next buffer (%llu so far, %.2f s held)", stops, ASMVitrineSingEngineLead(engine));
    }
    seen = stops;
    if (!minute) {
        minute = now;
        atMinute = stops;
    } else if (now - minute >= 60) {
        if (stops > atMinute) ASMVitrineLog(@"sing: read ahead: stopped %llu times in the last minute where Spotify had not decoded the sound yet", stops - atMinute);
        minute = now;
        atMinute = stops;
    }
}


static void flush(NSString *why) {
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    double lead = ASMVitrineSingHeldLead();
    if (!engine || lead <= 0) return;
    asm_vitrine_lastFlush = CFAbsoluteTimeGetCurrent();
    ASMVitrineSingEngineFlush(engine);
    ASMVitrineLog(@"sing: %@, the %.1f s held ahead are dropped", why, lead);
}

// The lead let go with nothing heard lost: Spotify is seeked back to what was heard, so it resumes in step.
static void dropLead(NSString *why, SPTPlayerState *state) {
    if (!state || ASMVitrineSingHeldLead() <= 0.05) return;
    // Hooked: what is heard, held while paused and run on while playing.
    double heard = state.isPaused ? state.positionAsOfTimestamp : state.position;
    if (heard < 0) return;
    flush([NSString stringWithFormat:@"%@, Spotify seeked back to %.2f s", why, heard]);
    ASMVitrineKaraokeSeek((NSInteger)llround(heard * 1000));
}

// A seek or a skip Spotify was asked for and has not carried out yet: until then its mixer hands over what came before
// it, which read ahead would play after the jump, so nothing is read ahead (a cap of 0) until Spotify reports the new
// track or the target (a seek's, 0 for a skip's), or kLandWithin passes. Hooks set it from any thread, tick and the
// track watcher clear it on main.
static const NSTimeInterval kLandWithin = 5;
static const double kLandedNear = 0.3;
static _Atomic CFAbsoluteTime asm_vitrine_commandAt;   // 0 with none on its way
static double asm_vitrine_commandTarget;               // -1 where it is not known (a relative seek)
static NSString *asm_vitrine_commandTrack;
// On the queue's last track the lead is let play out a second before Spotify's decoder reaches the end, where Spotify
// may stop its output with the lead still held.
static const double kEndMargin = 1;

// The track after this one, the same one on repeat; nil at the end of the queue.
static NSString *nextTrack(SPTPlayerState *state) {
    if (state.options.repeatingTrack) return ASMVitrineURIString(state.track.URI);
    id future = [state respondsToSelector:@selector(future)] ? state.future : nil;
    id next = [future isKindOfClass:NSArray.class] ? [(NSArray *)future firstObject] : nil;
    return [next isKindOfClass:objc_getClass("SPTPlayerTrack")] ? ASMVitrineURIString([(SPTPlayerTrack *)next URI]) : nil;
}

static void commanded(NSString *why, double target) {
    flush(why);
    asm_vitrine_commandTarget = target;
    asm_vitrine_commandTrack = ASMVitrineURIString(ASMVitrinePlayerState().track.URI);
    atomic_store(&asm_vitrine_commandAt, CFAbsoluteTimeGetCurrent());
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (engine) ASMVitrineSingEngineSetLeadCap(engine, 0);
}

static void updateCap(void) {
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    SPTPlayerState *state = ASMVitrinePlayerState();
    if (!engine) return;
    static BOOL wasLast;
    BOOL last = state.duration > 0 && !nextTrack(state) && !state.options.repeatingContext;
    if (last != wasLast) {
        wasLast = last;
        ASMVitrineLog(@"sing: %@", last ? @"the queue's last track: the lead is let play out a second before its end" : @"a track follows: the lead is read ahead to the end");
    }
    double cap = atomic_load(&asm_vitrine_commandAt) ? 0 : last ? fmax(0, state.duration - rawPosition(state) - kEndMargin) : INFINITY;
    ASMVitrineSingEngineSetLeadCap(engine, cap);
}

// The seek or skip on its way landed, or is given up on: the lead is read ahead again.
static void checkLanding(SPTPlayerState *state) {
    CFAbsoluteTime asked = atomic_load(&asm_vitrine_commandAt);
    if (!asked) return;
    NSString *track = ASMVitrineURIString(state.track.URI);
    NSDate *stamp = [state respondsToSelector:@selector(timestamp)] ? state.timestamp : nil;
    double at = state ? rawAsOf(state) : -1;
    BOOL after = [stamp isKindOfClass:NSDate.class] && stamp.timeIntervalSinceReferenceDate >= asked;
    BOOL landed = state && (asm_vitrine_commandTarget < 0 ? after : (track && asm_vitrine_commandTrack && ![track isEqualToString:asm_vitrine_commandTrack]) || fabs(at - asm_vitrine_commandTarget) < kLandedNear);
    double waited = CFAbsoluteTimeGetCurrent() - asked;
    if (!landed && waited < kLandWithin) return;
    atomic_store(&asm_vitrine_commandAt, 0);
    ASMVitrineLog(@"sing: %@ %.2f s after it was asked, the lead is read ahead again", landed ? [NSString stringWithFormat:@"Spotify landed at %.2f s", at]
          : [NSString stringWithFormat:@"no landing reported (Spotify at %.2f s, %@)", at, asm_vitrine_commandTarget < 0 ? @"a relative seek" : [NSString stringWithFormat:@"asked for %.2f s", asm_vitrine_commandTarget]], waited);
    updateCap();
}

// A call, Siri or another app's audio began or ended. iOS does not always say it ended: sound rendered with Spotify
// playing, a second on, says it (tick).
static void interrupted(BOOL began, NSString *why) {
    if (began) asm_vitrine_interruptedAt = CFAbsoluteTimeGetCurrent();
    ASMVitrineLog(@"sing: an interruption (a call, Siri, another app's audio) %@%@", why, began == asm_vitrine_interrupted ? @""
          : began ? [NSString stringWithFormat:@": the worker is held, the model and the %.2f s held ahead kept", ASMVitrineSingHeldLead()] : @": Karaoke separates again");
    if (began == asm_vitrine_interrupted) return;
    asm_vitrine_interrupted = began;
    apply();
    announce();
}

// The headphones Spotify played on are gone, and iOS has it pause: the lead is let go there with nothing heard lost, so
// the song resumes in step on the new route whatever Spotify does with its output meanwhile. A route that plays on
// keeps it, where a seek would be heard; spatial voice and AirPlay are read again for any.
static void routeChanged(AVAudioSessionRouteChangeReason reason) {
    if (!atomic_load(&asm_vitrine_engine)) return;
    NSArray *outputs = [AVAudioSession.sharedInstance.currentRoute.outputs valueForKey:@"portType"];
    ASMVitrineLog(@"sing: the route changed (reason %lu), now %@", (unsigned long)reason, [outputs componentsJoinedByString:@", "]);
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) dropLead(@"the headphones it played on are gone", ASMVitrinePlayerState());
}

static void tick(void) {
    // The Sing page gone a second ago: Sing may rest.
    updateRest();
    ASMVitrineSingState state = ASMVitrineSingCurrentState();
    NSString *text = ASMVitrineSingStatusText();
    if (state != asm_vitrine_shown || ![text isEqualToString:asm_vitrine_shownText]) {
        asm_vitrine_shown = state;
        asm_vitrine_shownText = text;
        announce();
    }
    SPTPlayerState *player = ASMVitrinePlayerState();
    if (player) {
        asm_vitrine_lastRaw = rawPosition(player);
        asm_vitrine_lastDuration = player.duration;
        // Seen soon after it is reported, its lead is kept for as long as it stands (ASMVitrineSingEngineLeadAt).
        ASMVitrineSingLeadOf(player);
    }
    checkLanding(player);
    updateCap();
    // Spotify plays and its music output has not rendered for 3 s, outside an interruption: it plays on another device.
    // Its output reached but not taken over is a failure of its own (ASMVitrineSingCurrentState).
    static CFAbsoluteTime silentSince;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    BOOL rendered = atomic_exchange(&asm_vitrine_rendered, false), playing = player.isPlaying && !player.isPaused && !player.isLoading;
    if (rendered || !playing || asm_vitrine_interrupted) silentSince = 0;
    else if (!silentSince) silentSince = now;
    BOOL elsewhere = silentSince && now - silentSince >= kNoOutputFor && !(atomic_load(&asm_vitrine_outputStarted) && !ASMVitrinePlayerSpeedAllowed());
    if (elsewhere != asm_vitrine_elsewhere) {
        asm_vitrine_elsewhere = elsewhere;
        if (ASMVitrineSingOn() && readRefusal()) {
            apply();
            announce();
        }
    }
    if (asm_vitrine_interrupted && rendered && playing && now - asm_vitrine_interruptedAt > 1) interrupted(NO, @"is over: Spotify plays again");
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    logClock(engine);
    logAheadStops(engine);
    if (state == ASMVitrineSingStateSinging) asm_vitrine_sangThisTrack = YES;
    // A Neural Engine copy that failed a window (Core ML's error) is given up on for the launch. One that is only slow
    // stays: falling behind is the budget's, as on any copy.
    ASMVitrineSingSeparator *current = ASMVitrineSingLoaderSeparator();
    if (current && [current stats].fastFailed) neuralFailed(@"failed a window");
    if (engine && ASMVitrineSingOn() && !asm_vitrine_stopped && ASMVitrineSingEngineGaveUp(engine)) {
        BOOL forGood = ++asm_vitrine_giveUps >= kGiveUpsKept;
        asm_vitrine_stopKind = forGood ? ASMVitrineSingStopForGood : ASMVitrineSingStopBehind;
        asm_vitrine_stopped = forGood ? [NSString stringWithFormat:@"Karaoke could not keep up on this iPhone %d times in a row, so it stopped and songs play as they are. "
                                                          @"Switch Karaoke off and on, or choose another Runs on, to try again.", asm_vitrine_giveUps]
                             : @"Karaoke could not keep up with this song on this iPhone, so it plays as it is. Karaoke tries again with the next song.";
        ASMVitrineLog(@"sing: stopped, the vocals fell short for 8 s, %d in a row%@; %@", asm_vitrine_giveUps, forGood ? @", so until switched off and on" : @"",
              ASMVitrineSingStatusDetail());
        apply();
    }
    // Now and then while on, what the model costs on this iPhone.
    static CFAbsoluteTime summarized;
    if (engine && ASMVitrineSingOn() && CFAbsoluteTimeGetCurrent() - summarized >= 30) {
        summarized = CFAbsoluteTimeGetCurrent();
        ASMVitrineSingEngineStats stats = ASMVitrineSingEngineReadStats(engine);
        ASMVitrineSingSeparator *separator = ASMVitrineSingLoaderSeparator();
        ASMVitrineSingSeparatorStats copies = separator ? [separator stats] : (ASMVitrineSingSeparatorStats){0};
        NSString *fastPart = !neuralWanted() && ASMVitrineSingLoaderFastState() == ASMVitrineSingFastNone ? @"no Neural Engine copy"
            : [NSString stringWithFormat:@"Neural Engine copy %@, %llu at %.0f ms",
               @[@"not started", @"loading", @"ready", @"skipped", @"failed", @"timed out"][(NSUInteger)ASMVitrineSingLoaderFastState()], copies.windows[1], copies.averageMS[1]];
        NSString *last = copies.windows[0] + copies.windows[1] == 0 ? @"none run yet" : copies.fast ? @"the last on the Neural Engine" : @"the last on the CPU";
        ASMVitrineLog(@"sing: %@, %llu windows at %.0f ms each (1500 ms keeps up; CPU copy %llu at %.0f ms, %@, %llu redone on the CPU, %@), "
              @"lead %.2f s of %.2f s (the clock's %.2f s), %.2f s separated ahead, %llu frames dry, %.1f s dropped, %.1f s of 8 s short%@, %llu failures, Spotify %@, "
              @"thermal state %s, %@, Runs on %@%@",
              ASMVitrineSingStatusText(), stats.windows, stats.averageMS, copies.windows[0], copies.averageMS[0], fastPart,
              copies.fallbacks, last, stats.lead, stats.targetLead, player ? ASMVitrineSingLeadOf(player) : 0, stats.ready,
              stats.dryFrames, stats.dropped, stats.budgetSpent, stats.budgetHeld ? @" (held while the Neural Engine copy loads)" : @"", stats.failures, asm_vitrine_active ? @"active" : @"not active", ASMVitrineSingThermalName(),
              ASMVitrineSingMemoryText(), runsOnName(),
              asm_vitrine_spatialListening ? [NSString stringWithFormat:@", the voice %.0f degrees right", stats.voiceAngle * 180 / M_PI] : @"");
    }
    // Off, with the lead let go: nothing left to watch.
    if (!ASMVitrineSingOn() && ASMVitrineSingHeldLead() <= 0) {
        [asm_vitrine_watch invalidate];
        asm_vitrine_watch = nil;
    }
}

static void watch(void) {
    if (asm_vitrine_watch) return;
    asm_vitrine_watch = [NSTimer scheduledTimerWithTimeInterval:kWatchEvery repeats:YES block:^(NSTimer *timer) { tick(); }];
    tick();
}

@interface ASMVitrineSingTrackWatcher : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineSingTrackWatcher
// A new track well before the last one's end was played, not reached: the lead is the old track's.
- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (ASMVitrineSingOn() && readRefusal()) {
        apply();
        announce();
    }
    updateSpatial();
    checkLanding(state);
    // Paused while not separating: the lead is dropped with nothing heard lost. Not through an interruption, which
    // holds the worker and keeps the lead for when Spotify plays again.
    ASMVitrineSingEngine *engine = atomic_load(&asm_vitrine_engine);
    if (state.isPaused && !asm_vitrine_interrupted && !ASMVitrineSingEngineSeparating(engine)) dropLead(@"paused while not separating", state);
    NSString *track = ASMVitrineURIString(state.track.URI);
    BOOL another = track && asm_vitrine_lastTrack && ![track isEqualToString:asm_vitrine_lastTrack];
    if (another) asm_vitrine_seekTarget = -1;
    // The queue's next track, up to a crossfade early, is reached: its lead is kept.
    static NSString *expected;
    double slack = kEndSlack + kWatchEvery + (another && [track isEqualToString:expected] ? kCrossfadeMost : 0);
    if (another && asm_vitrine_lastRaw >= 0 && asm_vitrine_lastDuration > 0 && asm_vitrine_lastDuration - asm_vitrine_lastRaw > slack && CFAbsoluteTimeGetCurrent() - asm_vitrine_lastFlush > 1) {
        flush(@"another track was played");
    }
    if (track) asm_vitrine_lastTrack = track;
    expected = nextTrack(state);
    updateCap();
    if (another) {
        // A track Sing kept up with to its end clears the count of falls behind.
        if (!asm_vitrine_stopped && asm_vitrine_sangThisTrack) asm_vitrine_giveUps = 0;
        asm_vitrine_sangThisTrack = NO;
        retry(@"a new track", YES);
    }
}
@end

#pragma mark - the heat

static void readHeat(void) {
    static NSProcessInfoThermalState last;
    NSProcessInfoThermalState thermal = NSProcessInfo.processInfo.thermalState;
    BOOL cooler = thermal < last;
    last = thermal;
    // A cooler iPhone runs the model faster.
    if (cooler) retry([NSString stringWithFormat:@"the iPhone is cooler (%s)", ASMVitrineSingThermalName()], NO);
    if (cooler) prepareAhead();
    // Serious and Critical hold; Fair lets it run again.
    BOOL hot = thermal >= NSProcessInfoThermalStateSerious;
    if (hot == asm_vitrine_hot) return;
    asm_vitrine_hot = hot;
    ASMVitrineLog(@"sing: the iPhone is %@ (thermal state %s)%@", hot ? @"hot" : @"cool again", ASMVitrineSingThermalName(),
          hot && ASMVitrineHidden(ASMVitrineKeySingIgnoreHeat) ? @", and heat warnings are ignored" : @", the engine held");
    apply();
    announce();
}

#pragma mark - Spotify's clock and commands

%hook SPTPlayerState
// For a paused state, which holds still there.
- (double)positionAsOfTimestamp {
    double position = %orig;
    if (asm_vitrine_rawPosition || position < 0) return position;
    double lead = ASMVitrineSingLeadOf(self);
    return lead != 0 ? MAX(0, position - lead) : position;
}
// Run on, the lead is taken off after, not before: a track reached as the last one ends is reported with less of it
// handed over than the lead holds, and its clock stays at 0 until its first frame plays rather than running on from the
// title change.
- (double)position {
    if (asm_vitrine_rawPosition) return %orig;
    double position = rawPosition(self);
    if (position < 0) return position;
    double lead = ASMVitrineSingLeadOf(self);
    return lead != 0 ? MAX(0, position - lead) : position;
}
%end

// The lock screen's elapsed time, when Spotify gives it its own count, which runs off what is heard by the state's
// lead. Which of the player's getters Spotify's now playing code reads is not known, so the time is moved only when it
// is nearer Spotify's own count than the heard one: one already taken through the hook above is left as it is.
%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    SPTPlayerState *state = ASMVitrinePlayerState();
    double lead = state ? ASMVitrineSingLeadOf(state) : 0;
    NSNumber *elapsed = info[MPNowPlayingInfoPropertyElapsedPlaybackTime];
    if (fabs(lead) > 0.05 && [elapsed isKindOfClass:NSNumber.class]) {
        double raw = rawPosition(state), at = elapsed.doubleValue;
        if (raw >= 0 && fabs(at - raw) < fabs(at - (raw - lead))) {
            NSMutableDictionary *heard = [info mutableCopy];
            heard[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(MAX(0, at - lead));
            %orig(heard);
            return;
        }
    }
    %orig;
}
%end

%hook SPTEsperantoPlayer
// Each seek runs on into the last one with the creator's timestamp (seekTo: 0x1096db0c0 into seekTo:options:, that
// and seekTo:relative: into seekTo:relative:options:, that into the last, which sends the position times 1000 as
// milliseconds), so the anchor is taken there, for an absolute seek (relative 0).
- (id)seekTo:(double)position {
    flush(@"Spotify seeks");
    return %orig;
}
- (id)seekTo:(double)position relative:(long long)relative {
    flush(@"Spotify seeks");
    return %orig;
}
- (id)seekTo:(double)position options:(id)options {
    flush(@"Spotify seeks");
    return %orig;
}
- (id)seekTo:(double)position relative:(long long)relative options:(id)options {
    flush(@"Spotify seeks");
    return %orig;
}
- (id)seekTo:(double)position relative:(long long)relative options:(id)options creatorTimestampPositionMs:(double)creator {
    commanded(@"Spotify seeks", relative == 0 ? position : -1);
    if (relative == 0) seekAnchor(position);
    return %orig;
}
// Every skip of Spotify's ends up in one of these two; a skip back early in a track starts it again, at 0.
- (id)skipToNextTrackWithOptions:(id)options track:(id)track loggingParams:(id)params {
    commanded(@"Spotify skips", 0);
    return %orig;
}
- (id)skipToPreviousTrackWithOptions:(id)options track:(id)track loggingParams:(id)params {
    commanded(@"Spotify skips back", 0);
    return %orig;
}
- (id)stop {
    flush(@"Spotify stops");
    return %orig;
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    asm_vitrine_outputReachable = ASMVitrinePlayerWatchMusicOutput(musicOutputChanged);
    if (!asm_vitrine_outputReachable) ASMVitrineLog(@"sing: Spotify's output cannot be watched, Sing cannot read its format");
    ASMVitrinePlayerSetStage(stage);
    ASMVitrinePlayerSetLeadReaders(ASMVitrineSingHeldLead, ASMVitrineSingLeadOf);
    asm_vitrine_frontSeconds = ASMVitrineSingSpatialFront();
    %init;
    ASMVitrineRequireClasses(@[@"SPTPlayerState", @"SPTEsperantoPlayer"]);
    // Runs on is Automatic or CPU only: GPU, Neural Engine and GPU and Neural Engine (2-4) are Automatic now, as is every
    // value of the earlier key (GPU, GPU and Neural Engine, Neural Engine). The GPU's memory of a stuck load and the
    // one-model test's switch are gone with them.
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (runsOn() > 1) ASMVitrineLog(@"sing: Runs on was %ld, which is gone, so it is Automatic", (long)runsOn());
    if (runsOn() != 1) [defaults removeObjectForKey:ASMVitrineKeySingComputeUnits];
    for (NSString *key in @[ASMVitrineKeySingComputeUnitsBefore, @"asm.interface.vitrine.sing.gpuStuckOn", @"asm.interface.vitrine.sing.oneModel"]) [defaults removeObjectForKey:key];
    // The 489 MB model this one replaces, deleted off the main thread once this one is in (kept and run until then).
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ ASMVitrineSingRemoveOldModel(); });
    dispatch_async(dispatch_get_main_queue(), ^{
        static ASMVitrineSingTrackWatcher *watcher;
        watcher = [ASMVitrineSingTrackWatcher new];
        ASMVitrineAddPlayerStateObserver(watcher);
        ASMVitrineSingLoaderSetChanged(^{ loaderChanged(); });
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        // Posted on whichever thread saw the change: handed to main without waiting.
        [center addObserverForName:NSProcessInfoThermalStateDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            dispatch_async(dispatch_get_main_queue(), ^{ readHeat(); });
        }];
        // Headphones in or out, or iOS's own spatial audio switched.
        for (NSNotificationName name in @[AVAudioSessionRouteChangeNotification, AVAudioSessionSpatialPlaybackCapabilitiesChangedNotification]) {
            // Posted on the audio session's thread: handed to main without waiting, so it cannot deadlock against main.
            [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
                NSNumber *reason = [note.name isEqualToString:AVAudioSessionRouteChangeNotification] ? note.userInfo[AVAudioSessionRouteChangeReasonKey] : nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (reason) routeChanged(reason.unsignedIntegerValue);
                    if (ASMVitrineSingOn() && readRefusal()) {
                        apply();
                        announce();
                    }
                    updateSpatial();
                });
            }];
        }
        // A call, Siri or another app's audio. Posted on the audio session's thread too.
        [center addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            BOOL began = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan;
            BOOL resume = [note.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue] & AVAudioSessionInterruptionOptionShouldResume;
            dispatch_async(dispatch_get_main_queue(), ^{
                interrupted(began, began ? @"began" : resume ? @"ended, iOS says Spotify may resume" : @"ended, iOS says Spotify should not resume");
            });
        }];
        // A load starts only while Spotify is active, so never in a launch into the background.
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            asm_vitrine_active = YES;
            ASMVitrineSingLoaderSetForeground(YES);
            if (ASMVitrineSingOn()) apply();
            prepareAheadSoon();
        }];
        [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            asm_vitrine_active = NO;
            ASMVitrineSingLoaderSetForeground(NO);
        }];
        // Low on memory, the model goes at once, before iOS closes Spotify for it.
        [center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (ASMVitrineHidden(ASMVitrineKeySingIgnoreMemory)) {
                ASMVitrineLog(@"sing: iOS warned that memory is low; the model is kept (Ignore memory warnings)");
                return;
            }
            ASMVitrineSingLoaderPurge(@"iOS warned that memory is low");
            // Over a stop for falling behind, which would load the model again with the next track whatever the memory.
            if (!ASMVitrineSingOn() || (asm_vitrine_stopped && asm_vitrine_stopKind != ASMVitrineSingStopBehind)) return;
            asm_vitrine_stopKind = ASMVitrineSingStopMemory;
            asm_vitrine_stopped = @"Karaoke stopped to free memory, so the song plays as it is. It loads the voice model again with the next song if there is room, "
                         @"or switch Karaoke off and on.";
            apply();
            announce();
        }];
        [center addObserverForName:ASMVitrineSingChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (ASMVitrineSingModelCurrentState() != ASMVitrineSingModelReady) {
                ASMVitrineSingLoaderPurge(@"the voice model is gone from the iPhone");
            } else if (ASMVitrineSingOn() && asm_vitrine_active && !asm_vitrine_resting && !(asm_vitrine_hot && !ASMVitrineHidden(ASMVitrineKeySingIgnoreHeat))
                       && (ASMVitrineSingLoaderCurrentState() == ASMVitrineSingLoaderIdle || ![ASMVitrineSingLoaderURL() isEqual:ASMVitrineSingModelURL()])) {
                // A download finishing with the mic already on loads the model, or the update in place of the old one
                // (whose files are gone; its copies in memory run until the new ones are in).
                apply();
            }
        }];
        asm_vitrine_active = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
        ASMVitrineSingLoaderSetForeground(asm_vitrine_active);
        readHeat();
        readRefusal();
        if (ASMVitrineSingOn()) apply();
        prepareAheadSoon();
    });
}
