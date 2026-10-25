// AirPods gestures: CMHeadphoneMotionManager's attitudes fed to ASMVitrineHeadDetector while the switch is on and
// Spotify plays, or while the page records, tries or holds the motion, and each gesture's action done to
// Spotify's player. The same manager's motion goes to the features listening through ASMVitrineHeadMotionListen
// (Sing's spatial voice), and keeps running for them with the switch off; the detector is fed only while
// the gestures want it.
//
// The actions are the player's own commands (Headers/SPTPlayer.h) on ASMVitrineKaraokePlayer, the ones the Live
// Activity's control menu sends: seekTo:, pause: and resume:, skipToNextTrackWithOptions: and
// skipToPreviousTrackWithOptions:, setShufflingContext:, and setRepeatingContext: with setRepeatingTrack:.
// Like adds the playing track to the collection, which for a track is Liked Songs, through
// -addURL:showUIConfirmation:completion: of Spotify's collection platform. Spotify 9.1.78 has four classes
// with that selector and with -stateProvider (SPTCollectionPlatformImplementation, Collection_PlatformImpl's
// CollectionPlatformImpl and CollectionPlatformMigration, AlignedCuration's ACUCollectionPlatform);
// whichever the app last reached for is kept, weakly, the way Redesigned/Artist/ArtistFollow.x keeps its
// state provider. The lock screen's like (LockScreenBaseRemoteControlPolicy's
// likeButtonPressedWithCompletion:identifier:) is not used: it toggles, and a second nod would take the
// song out again.
//
// The gestures listen while Spotify plays, and while a track is loaded and paused too when one of them is
// set to Play or pause, which could not resume otherwise.
//
// The cue is a tone played through Spotify's own playback session, mixed into the music in the AirPods:
// a system sound would follow the Ring/Silent switch, and a phone in a pocket is often on silent. A rising
// pair says the gesture was done, one low tone that it failed, and a single middle one is the teaching
// sheet's signal to move. A haptic comes with it while Spotify is in front, and Spotify's own "Added to
// Liked Songs" toast shows only then too.
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/Player/PlayerState.h"
#import "HeadGestures.h"

@protocol ASMVitrineCollectionPlatform <NSObject>
- (void)addURL:(NSURL *)url showUIConfirmation:(BOOL)show completion:(id)completion;
@end

// Tink, the passcode key's, should the cue's player not load.
static const SystemSoundID kCueSound = 1057;
// Each of the cue's tones, and how loud, of the most a sample holds; the player plays at the system volume.
static const double kToneSeconds = 0.09;
static const double kToneLevel = 0.5;
static const double kMilli = 1000;
static const double kSeekSeconds = 15;

static CMHeadphoneMotionManager *asm_vitrine_manager;
static NSOperationQueue *asm_vitrine_queue;   // serial: the detector, the recording and the queue's copies live on it alone
static ASMVitrineHeadDetector asm_vitrine_detector;
static NSMutableData *asm_vitrine_recorded;   // a recording's samples, three doubles each
static NSInteger asm_vitrine_queueHeard;      // samples the detector was fed since a try started
static BOOL asm_vitrine_recording, asm_vitrine_trying, asm_vitrine_held;
static void (^asm_vitrine_tryDone)(ASMVitrineHeadGesture gesture, BOOL heard);
static NSUInteger asm_vitrine_ticket;         // which recording or try is current: a stopped one's timer finds it moved on
static BOOL asm_vitrine_listening;            // started with the handler, by updateListening
static BOOL asm_vitrine_detecting;            // the gestures want the motion: the page's listening, or the switch on and Spotify playing
static BOOL asm_vitrine_queueDetecting;       // asm_vitrine_detecting, on asm_vitrine_queue
static NSMutableDictionary<NSString *, void (^)(CMDeviceMotion *)> *asm_vitrine_listeners;   // other features', by name
static NSArray<void (^)(CMDeviceMotion *)> *asm_vitrine_queueListeners;                     // their handlers, on asm_vitrine_queue
static __weak id asm_vitrine_platform;

#pragma mark - the collection platform

// Spotify's platforms wrap one another, so the one kept can change often: logged once per class.
static void keepPlatform(id platform) {
    if (platform == asm_vitrine_platform || ![platform respondsToSelector:@selector(addURL:showUIConfirmation:completion:)]) return;
    NSString *name = NSStringFromClass([platform class]);
    static NSMutableSet<NSString *> *logged;
    // Spotify asks for its state provider from any thread.
    @synchronized (NSObject.class) {
        asm_vitrine_platform = platform;
        if (!logged) logged = [NSMutableSet set];
        if ([logged containsObject:name]) return;
        [logged addObject:name];
    }
    ASMVitrineLog(@"head gestures: collection platform %@", name);
}

%hook SPTCollectionPlatformImplementation
- (id)stateProvider {
    keepPlatform(self);
    return %orig;
}
%end

%hook _TtC23Collection_PlatformImpl22CollectionPlatformImpl
- (id)stateProvider {
    keepPlatform(self);
    return %orig;
}
%end

%hook _TtC23Collection_PlatformImpl27CollectionPlatformMigration
- (id)stateProvider {
    keepPlatform(self);
    return %orig;
}
%end

%hook _TtC26AlignedCuration_CommonImpl21ACUCollectionPlatform
- (id)stateProvider {
    keepPlatform(self);
    return %orig;
}
%end

#pragma mark - the cue

// A WAV in memory of short tones one after the other, each faded in and out so it does not click.
static NSData *tones(NSArray<NSNumber *> *hertz) {
    const uint32_t rate = 44100, perTone = (uint32_t)(rate * kToneSeconds), frames = perTone * (uint32_t)hertz.count;
    NSMutableData *wav = [NSMutableData dataWithLength:44 + frames * sizeof(int16_t)];
    uint8_t *header = wav.mutableBytes;
    // RIFF, then the format chunk (PCM, one channel, 16-bit) and the data chunk; arm64 is little-endian, as WAV is.
    uint32_t words[] = {0x46464952, 36 + frames * 2, 0x45564157, 0x20746d66, 16, 1 | 1 << 16, rate, rate * 2, 2 | 16 << 16,
                        0x61746164, frames * 2};
    memcpy(header, words, sizeof words);
    int16_t *samples = (int16_t *)(header + 44);
    for (NSUInteger tone = 0; tone < hertz.count; tone++) {
        for (uint32_t i = 0; i < perTone; i++) {
            double envelope = sin(M_PI * i / perTone);
            samples[tone * perTone + i] = (int16_t)(kToneLevel * INT16_MAX * envelope * sin(2 * M_PI * hertz[tone].doubleValue * i / rate));
        }
    }
    return wav;
}

// The cue's players live on a queue of their own: loading and starting one goes through the audio
// session, which can hold the main thread up for a moment.
static dispatch_queue_t cueQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("asm.interface.vitrine.headgestures.cue", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

// The middle tone, the rising pair and the low tone, in ASMVitrineHeadCue's order. On cueQueue only.
static AVAudioPlayer *cuePlayer(ASMVitrineHeadCue cue) {
    static AVAudioPlayer *players[3];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSArray<NSNumber *> *> *sounds = @[@[@660], @[@880, @1320], @[@330]];
        for (NSUInteger i = 0; i < sounds.count; i++) {
            NSError *error = nil;
            players[i] = [[AVAudioPlayer alloc] initWithData:tones(sounds[i]) error:&error];
            if (!players[i]) ASMVitrineLog(@"head gestures: no cue player, the system sound instead: %@", error);
            [players[i] prepareToPlay];
        }
    });
    return players[cue];
}

void ASMVitrineHeadGesturesCue(ASMVitrineHeadCue cue) {
    dispatch_async(cueQueue(), ^{
        AVAudioPlayer *player = cuePlayer(cue);
        player.currentTime = 0;
        if (![player play]) AudioServicesPlaySystemSound(kCueSound);
    });
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    if (cue == ASMVitrineHeadCueReady) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        return;
    }
    UINotificationFeedbackGenerator *generator = [UINotificationFeedbackGenerator new];
    [generator notificationOccurred:cue == ASMVitrineHeadCueWorked ? UINotificationFeedbackTypeSuccess : UINotificationFeedbackTypeError];
}

#pragma mark - the actions

ASMVitrineHeadAction ASMVitrineHeadGestureAction(ASMVitrineHeadGesture gesture) {
    BOOL nod = gesture == ASMVitrineHeadGestureDoubleNod;
    NSInteger action = ASMVitrineInt(nod ? ASMVitrineKeyHeadNodAction : ASMVitrineKeyHeadShakeAction, nod ? ASMVitrineHeadActionLike : ASMVitrineHeadActionNext);
    return action >= 0 && action < ASMVitrineHeadActionCount ? action : ASMVitrineHeadActionNothing;
}

void ASMVitrineSetHeadGestureAction(ASMVitrineHeadGesture gesture, ASMVitrineHeadAction action) {
    ASMVitrineSetInt(gesture == ASMVitrineHeadGestureDoubleNod ? ASMVitrineKeyHeadNodAction : ASMVitrineKeyHeadShakeAction, action);
    ASMVitrineHeadGesturesSettingsChanged();
}

BOOL ASMVitrineLikePlayingTrack(void) {
    NSString *uri = ASMVitrineURIString(ASMVitrinePlayerState().track.URI);
    id platform = asm_vitrine_platform;
    // Only a track: an episode is saved another way, and an ad is nothing to save.
    if (![uri hasPrefix:@"spotify:track:"] || !platform) {
        ASMVitrineLog(@"head gestures: no like for %@, platform %@", uri, platform);
        return NO;
    }
    BOOL inFront = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    // A block that reads no arguments: whatever the completion is called with, it is safe to ignore.
    [(id<ASMVitrineCollectionPlatform>)platform addURL:[NSURL URLWithString:uri] showUIConfirmation:inFront completion:^{
        ASMVitrineLog(@"head gestures: liked %@", uri);
    }];
    return YES;
}

// Whether it was sent: the player answers later, if at all.
static BOOL perform(ASMVitrineHeadAction action) {
    if (action == ASMVitrineHeadActionLike) return ASMVitrineLikePlayingTrack();
    id<SPTPlayer> player = ASMVitrineKaraokePlayer();
    SPTPlayerState *state = [player respondsToSelector:@selector(state)] ? player.state : nil;
    if (!state) {
        ASMVitrineLog(@"head gestures: no player for action %ld", (long)action);
        return NO;
    }
    switch (action) {
        case ASMVitrineHeadActionSeekBack:
        case ASMVitrineHeadActionSeekForward: {
            // A paused state's position would run on from when it was made; positionAsOfTimestamp holds still.
            double at = state.isPaused ? state.positionAsOfTimestamp : state.position;
            double to = at + (action == ASMVitrineHeadActionSeekBack ? -kSeekSeconds : kSeekSeconds);
            if (state.duration > 0) to = MIN(to, state.duration);
            [player seekTo:MAX(0, to)];
            return YES;
        }
        case ASMVitrineHeadActionPlayPause:
            if (state.isPaused) [player resume:nil];
            else [player pause:nil];
            return YES;
        case ASMVitrineHeadActionNext:
            [player skipToNextTrackWithOptions:nil];
            return YES;
        case ASMVitrineHeadActionPrevious:
            [player skipToPreviousTrackWithOptions:nil];
            return YES;
        case ASMVitrineHeadActionShuffle:
            [player setShufflingContext:!state.options.shufflingContext];
            return YES;
        case ASMVitrineHeadActionRepeat:
            // Off, then the playlist or album, then the track, then off again, the way Spotify's button goes.
            if (state.options.repeatingTrack) {
                [player setRepeatingTrack:NO];
                [player setRepeatingContext:NO];
            } else if (state.options.repeatingContext) {
                [player setRepeatingTrack:YES];
            } else {
                [player setRepeatingContext:YES];
            }
            return YES;
        default:
            return NO;
    }
}

// What learning stored for `key`, or the detector's default.
static double learnedOr(NSString *key, double fallback) {
    NSInteger learned = ASMVitrineInt(key, 0);
    return learned > 0 ? learned / kMilli : fallback;
}

static double threshold(NSString *key, double fallback) {
    double sensitivity = MAX(ASMVitrineHeadSensitivityMin, MIN(ASMVitrineHeadSensitivityMax, ASMVitrineInt(ASMVitrineKeyHeadSensitivity, 100))) / 100.0;
    return learnedOr(key, fallback) / sensitivity;
}

// The other gesture's threshold, as set now at a sensitivity of 100%: what learning `axis` checks with.
static double otherThreshold(ASMVitrineHeadAxis axis) {
    return axis == ASMVitrineHeadAxisPitch ? learnedOr(ASMVitrineKeyHeadShake, ASMVitrineHeadDefaultShake) : learnedOr(ASMVitrineKeyHeadNod, ASMVitrineHeadDefaultNod);
}

#pragma mark - listening

// Nil to the other features' handlers: the motion has stopped. On asm_vitrine_queue.
static void motionStopped(void) {
    for (void (^handler)(CMDeviceMotion *) in asm_vitrine_queueListeners) handler(nil);
}

static void endTry(NSUInteger ticket, ASMVitrineHeadGesture gesture, BOOL heard);

static void sample(CMDeviceMotion *motion) {
    for (void (^handler)(CMDeviceMotion *) in asm_vitrine_queueListeners) handler(motion);
    double time = motion.timestamp, pitch = motion.attitude.pitch, yaw = motion.attitude.yaw;
    if (asm_vitrine_recorded) {
        double values[3] = {time, pitch, yaw};
        [asm_vitrine_recorded appendBytes:values length:sizeof values];
        return;
    }
    // Running for another feature alone, the gestures off or Spotify paused: no gestures.
    if (!asm_vitrine_queueDetecting) return;
    asm_vitrine_queueHeard++;
    ASMVitrineHeadGesture gesture = ASMVitrineHeadDetectorFeed(&asm_vitrine_detector, time, pitch, yaw);
    if (gesture == ASMVitrineHeadGestureNone) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        ASMVitrineLog(@"head gestures: %@", gesture == ASMVitrineHeadGestureDoubleNod ? @"double nod" : @"shake");
        if (asm_vitrine_trying) {
            endTry(asm_vitrine_ticket, gesture, YES);
            return;
        }
        if (asm_vitrine_recording || asm_vitrine_held || !ASMVitrineFlag(ASMVitrineKeyHeadGestures, NO)) return;
        ASMVitrineHeadAction action = ASMVitrineHeadGestureAction(gesture);
        if (action == ASMVitrineHeadActionNothing) return;
        BOOL worked = perform(action);
        if (ASMVitrineFlag(ASMVitrineKeyHeadChime, YES)) ASMVitrineHeadGesturesCue(worked ? ASMVitrineHeadCueWorked : ASMVitrineHeadCueFailed);
    });
}

// The headphones taken out or off: the listeners hear that their motion stopped. Called on the queue the motion
// comes on.
@interface ASMVitrineHeadMotionDelegate : NSObject <CMHeadphoneMotionManagerDelegate>
@end

@implementation ASMVitrineHeadMotionDelegate
- (void)headphoneMotionManagerDidDisconnect:(CMHeadphoneMotionManager *)manager {
    [asm_vitrine_queue addOperationWithBlock:^{ motionStopped(); }];
}
@end

static CMHeadphoneMotionManager *manager(void) {
    static ASMVitrineHeadMotionDelegate *delegate;   // the manager holds its delegate weakly
    if (!asm_vitrine_manager) {
        asm_vitrine_manager = [CMHeadphoneMotionManager new];
        asm_vitrine_queue = [NSOperationQueue new];
        asm_vitrine_queue.maxConcurrentOperationCount = 1;
        asm_vitrine_queue.qualityOfService = NSQualityOfServiceUserInitiated;
        delegate = [ASMVitrineHeadMotionDelegate new];
        asm_vitrine_manager.delegate = delegate;
    }
    return asm_vitrine_manager;
}

// A fresh detector at the thresholds set now.
static void resetDetector(void) {
    double nod = threshold(ASMVitrineKeyHeadNod, ASMVitrineHeadDefaultNod), shake = threshold(ASMVitrineKeyHeadShake, ASMVitrineHeadDefaultShake);
    [asm_vitrine_queue addOperationWithBlock:^{ ASMVitrineHeadDetectorReset(&asm_vitrine_detector, nod, shake); }];
}

// The gestures want the motion while the page listens or holds it, or while the switch is on and Spotify
// plays (or has a track paused, for Play or pause); the manager runs then and while another feature listens.
// It sends nothing until headphones that track motion are in, so starting it with none costs nothing.
static void updateListening(void) {
    // isPlaying stays on while a track is loaded and paused; isPaused is what tells.
    SPTPlayerState *state = ASMVitrinePlayerState();
    BOOL resumes = ASMVitrineHeadGestureAction(ASMVitrineHeadGestureDoubleNod) == ASMVitrineHeadActionPlayPause
                   || ASMVitrineHeadGestureAction(ASMVitrineHeadGestureShake) == ASMVitrineHeadActionPlayPause;
    BOOL wanted = state.isPlaying && (!state.isPaused || resumes);
    BOOL detect = asm_vitrine_recording || asm_vitrine_trying || asm_vitrine_held || (ASMVitrineFlag(ASMVitrineKeyHeadGestures, NO) && wanted);
    if (detect != asm_vitrine_detecting) {
        asm_vitrine_detecting = detect;
        manager();
        if (detect) {
            resetDetector();
            // Loaded now rather than with the first gesture's cue, which then plays on time.
            dispatch_async(cueQueue(), ^{ cuePlayer(ASMVitrineHeadCueWorked); });
        }
        [asm_vitrine_queue addOperationWithBlock:^{ asm_vitrine_queueDetecting = detect; }];
    }
    BOOL listen = detect || asm_vitrine_listeners.count;
    if (listen == asm_vitrine_listening) return;
    asm_vitrine_listening = listen;
    ASMVitrineLog(@"head gestures: %@", listen ? @"listening" : @"stopped");
    if (!listen) {
        [asm_vitrine_manager stopDeviceMotionUpdates];
        return;
    }
    [asm_vitrine_manager startDeviceMotionUpdatesToQueue:asm_vitrine_queue withHandler:^(CMDeviceMotion *motion, NSError *error) {
        if (motion) sample(motion);
    }];
}

void ASMVitrineHeadMotionListen(NSString *name, void (^handler)(CMDeviceMotion *motion)) {
    if (!asm_vitrine_listeners) asm_vitrine_listeners = [NSMutableDictionary dictionary];
    void (^old)(CMDeviceMotion *) = asm_vitrine_listeners[name];
    if (!old && !handler) return;
    asm_vitrine_listeners[name] = [handler copy];
    manager();
    NSArray<void (^)(CMDeviceMotion *)> *handlers = asm_vitrine_listeners.allValues;
    [asm_vitrine_queue addOperationWithBlock:^{
        asm_vitrine_queueListeners = handlers;
        if (old) old(nil);
    }];
    updateListening();
}

void ASMVitrineHeadMotionAskPermission(void) {
    // Motion's permission is asked the first time the manager starts. With nothing playing that would be the
    // first song, maybe from the lock screen, so a page asks while it is in front.
    if (asm_vitrine_listening || CMHeadphoneMotionManager.authorizationStatus != CMAuthorizationStatusNotDetermined) return;
    [manager() startDeviceMotionUpdates];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!asm_vitrine_listening) [asm_vitrine_manager stopDeviceMotionUpdates];
    });
}

void ASMVitrineHeadGesturesSettingsChanged(void) {
    if (asm_vitrine_manager) resetDetector();
    updateListening();
    if (ASMVitrineFlag(ASMVitrineKeyHeadGestures, NO)) ASMVitrineHeadMotionAskPermission();
}

BOOL ASMVitrineHeadGesturesAvailable(void) {
    return manager().deviceMotionAvailable;
}

#pragma mark - the page's listening

void ASMVitrineHeadGesturesStopListening(void) {
    if (!asm_vitrine_recording && !asm_vitrine_trying) return;
    asm_vitrine_recording = asm_vitrine_trying = NO;
    asm_vitrine_tryDone = nil;
    asm_vitrine_ticket++;
    [asm_vitrine_queue addOperationWithBlock:^{ asm_vitrine_recorded = nil; }];
    ASMVitrineLog(@"head gestures: the page's listening stopped");
    ASMVitrineHeadGesturesSettingsChanged();
}

void ASMVitrineHeadGesturesHold(BOOL hold) {
    if (hold == asm_vitrine_held) return;
    asm_vitrine_held = hold;
    manager();
    ASMVitrineHeadGesturesSettingsChanged();
}

void ASMVitrineHeadGesturesRecord(double seconds, void (^done)(NSData *motion)) {
    ASMVitrineHeadGesturesStopListening();
    asm_vitrine_recording = YES;
    NSUInteger ticket = ++asm_vitrine_ticket;
    manager();
    [asm_vitrine_queue addOperationWithBlock:^{ asm_vitrine_recorded = [NSMutableData data]; }];
    ASMVitrineHeadGesturesSettingsChanged();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (ticket != asm_vitrine_ticket) return;
        [asm_vitrine_queue addOperationWithBlock:^{
            NSData *motion = asm_vitrine_recorded ?: [NSData data];
            asm_vitrine_recorded = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ticket != asm_vitrine_ticket) return;
                asm_vitrine_recording = NO;
                ASMVitrineHeadGesturesSettingsChanged();
                done(motion);
            });
        }];
    });
}

static void endTry(NSUInteger ticket, ASMVitrineHeadGesture gesture, BOOL heard) {
    if (!asm_vitrine_trying || ticket != asm_vitrine_ticket) return;
    void (^done)(ASMVitrineHeadGesture, BOOL) = asm_vitrine_tryDone;
    asm_vitrine_trying = NO;
    asm_vitrine_tryDone = nil;
    asm_vitrine_ticket++;
    ASMVitrineHeadGesturesSettingsChanged();
    done(gesture, heard);
}

void ASMVitrineHeadGesturesTry(double seconds, void (^done)(ASMVitrineHeadGesture gesture, BOOL heard)) {
    ASMVitrineHeadGesturesStopListening();
    asm_vitrine_trying = YES;
    asm_vitrine_tryDone = [done copy];
    NSUInteger ticket = ++asm_vitrine_ticket;
    manager();
    [asm_vitrine_queue addOperationWithBlock:^{ asm_vitrine_queueHeard = 0; }];
    // A fresh detector, at the thresholds and sensitivity set now, even if the gestures were listening already.
    ASMVitrineHeadGesturesSettingsChanged();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (ticket != asm_vitrine_ticket) return;
        [asm_vitrine_queue addOperationWithBlock:^{
            BOOL heard = asm_vitrine_queueHeard > 0;
            dispatch_async(dispatch_get_main_queue(), ^{ endTry(ticket, ASMVitrineHeadGestureNone, heard); });
        }];
    });
}

#pragma mark - learning

// A recording's samples as the detector's three arrays, in one buffer: free the time's.
static ASMVitrineHeadRecording unpack(NSData *motion) {
    int count = (int)(motion.length / (3 * sizeof(double)));
    const double *values = motion.bytes;
    double *buffer = malloc(sizeof(double) * 3 * MAX(count, 1));
    for (int i = 0; i < count; i++) {
        buffer[i] = values[3 * i];
        buffer[count + i] = values[3 * i + 1];
        buffer[2 * count + i] = values[3 * i + 2];
    }
    return (ASMVitrineHeadRecording){buffer, buffer + count, buffer + 2 * count, count};
}

double ASMVitrineHeadGesturesSampleThreshold(NSData *motion, ASMVitrineHeadAxis axis) {
    ASMVitrineHeadRecording recording = unpack(motion);
    double learned = ASMVitrineHeadLearn(recording.time, recording.pitch, recording.yaw, recording.count, axis, otherThreshold(axis));
    free((void *)recording.time);
    return learned;
}

double ASMVitrineHeadGesturesLearnFrom(NSArray<NSData *> *motions, ASMVitrineHeadAxis axis) {
    int n = (int)motions.count;
    ASMVitrineHeadRecording *recordings = calloc(MAX(n, 1), sizeof *recordings);
    for (int i = 0; i < n; i++) recordings[i] = unpack(motions[i]);
    double learned = ASMVitrineHeadLearnSamples(recordings, n, axis, otherThreshold(axis), MAX(1, n - 1));
    for (int i = 0; i < n; i++) free((void *)recordings[i].time);
    free(recordings);
    ASMVitrineLog(@"head gestures: learned %.2f rad/s for %@ from %d recordings", learned, axis == ASMVitrineHeadAxisPitch ? @"nod" : @"shake", n);
    if (learned > 0) {
        ASMVitrineSetInt(axis == ASMVitrineHeadAxisPitch ? ASMVitrineKeyHeadNod : ASMVitrineKeyHeadShake, lround(learned * kMilli));
        ASMVitrineHeadGesturesSettingsChanged();
    }
    return learned;
}

// Playing or not, from the one player hook every feature shares.
@interface ASMVitrineHeadGesturesObserver : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineHeadGesturesObserver
- (void)playerStateDidChange:(SPTPlayerState *)state {
    updateListening();
}
@end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMVitrineRequireClasses(@[@"SPTCollectionPlatformImplementation", @"_TtC23Collection_PlatformImpl22CollectionPlatformImpl"]);
    static ASMVitrineHeadGesturesObserver *observer;
    observer = [ASMVitrineHeadGesturesObserver new];
    ASMVitrineAddPlayerStateObserver(observer);
}
