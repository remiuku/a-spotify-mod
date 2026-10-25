// Vibrations > Music Haptics: the Taptic Engine playing along with the song, taps on the drums and a
// rumble under the bass, the way Apple Music's Music Haptics feels, worked out live from the sound.
//
// Spotify plays through Core Audio units of its own (AudioUnitDriver2 in the binary: converter, EQ, mixer
// and a RemoteIO output unit, started with AudioOutputUnitStart(_outputUnit)), with no Objective-C
// method between it and the unit, and it can run two such chains at once, one per sample rate. Shared/Player
// keeps them apart and names the music's output (ASMVitrinePlayerMusicOutput), and that one gets a render notify:
// after each render, the buffer bound for the speaker is mixed to mono and handed to the analyzer
// (ASMVitrineMusicAnalyzer.h) on the render thread, which puts what it hears into a ring of events. A notify stays on
// a unit that was the music's once and does nothing there, so the one analyzer never hears two outputs. That
// buffer is in the unit's output format, the hardware's, not the one Spotify hands the unit (in the simulator
// 48 kHz float with a buffer per channel, whatever the client: harness/audio-effects/sim, harness/haptics/sim),
// so the analyzer runs at the hardware's rate, and Shared/Player says when it changes. The render timestamp says when
// that buffer reaches the output; AVAudioSession's output latency (large over Bluetooth) is added, so
// a tap lands when its drum is heard. A thread of this file's own takes the events off the ring and
// schedules them with Core Haptics at those times: each hit a transient, the rumble one looping
// continuous event whose intensity follows the level. The strength scales both as they are played, and
// what Music Haptics follows leaves out the snares' taps (Bass) or the rumble (Beat) there too, so a change
// applies to the next event.
// The Vibrations page's preview asks for one kick, which the same thread plays at once through the same
// engine and strength, and while the page shows, each tap played is handed back to it for its rings.
//
// The rebinding and the notify are in place under either look, so the switch works at once; with it
// off the notify returns straight away. Nothing listens while Spotify is not the active app, since iOS
// plays no haptics for an app in the background. Sound that is not Spotify's own output (Connect,
// AirPlay to another device, video) never passes the unit, and plays no haptics.
// Nothing listens either while In the Background (SystemMusicHaptics.x) is finding out whether iOS has a
// haptic track for the song, or has one named: iOS plays it in front of Spotify as well as behind it, so
// the two would double up. The switch is read again every time listening could start, not kept from
// launch, so this one is right whatever order the two came up in.
//
// Threading: the notify runs on the render thread and only touches atomics, the analyzer and the
// ring; the Core Haptics objects belong to the player thread; the switches, the settings and the app's
// state are set on the main thread.
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreHaptics/CoreHaptics.h>
#import <mach/mach_time.h>
#import <os/lock.h>
#import <pthread.h>
#import <stdatomic.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/Player/SpeedPitch.h"
#import "Haptics.h"
#import "ASMVitrineMusicAnalyzer.h"

// Core Haptics takes about this long from a scheduled time to the Taptic Engine's peak.
static const double kHapticLead = 0.012;
// A tap this late is left out rather than played off the beat.
static const double kLatestTap = 0.05;
// Taps are this strong at most, and the rumble this strong at its level's most, at a strength of 100%.
static const float kTapGain = 1, kRumbleGain = 1;
// The rumble starts over this level and stops once it has stayed under the other this long.
static const float kRumbleStart = 0.05f, kRumbleStop = 0.02f;
static const double kRumbleStopAfter = 0.3;
// A level closer than this to the last one sent is skipped, unless it moved by more than kRumbleStep.
static const double kRumbleInterval = 0.025;
static const float kRumbleStep = 0.08f;
static const NSTimeInterval kRumbleLength = 30;
// Without events for this long, or for this many IO buffers if that is longer, the rumble goes quiet (the
// output stopped rendering), and after the longer wait the engine is stopped.
static const double kQuietAfter = 0.1, kQuietAfterBuffers = 2.5, kEngineStopAfter = 5;
// An engine that would not start is not asked again for this long.
static const double kStartRetryAfter = 2;

enum { kRingSize = 1024, kMonoFrames = 4096 };

#pragma mark - shared between the threads

static atomic_bool asm_vitrine_active, asm_vitrine_systemCovers, asm_vitrine_listening;
static atomic_uint asm_vitrine_generation;
static atomic_uint_fast64_t asm_vitrine_latencyBits;
static atomic_uint asm_vitrine_lastFrames;
// The format of the buffers the notify gets: the rate, and the layout packed into one word so the render
// thread never reads half of a change (flags in the low 32 bits, then channels, then bytes per sample).
static atomic_uint_fast64_t asm_vitrine_sampleRateBits, asm_vitrine_layout;
static atomic_uint_fast64_t asm_vitrine_skipped;   // renders whose buffers were not laid out as the format says
// The strength's factor and what is followed, set on the main thread, read on the player thread.
static atomic_uint_fast64_t asm_vitrine_strengthBits;
static atomic_int asm_vitrine_follows;
// A tap the Vibrations preview asked for, and whether it is watching the taps (ASMVitrineMusicHapticsWatchTaps).
static atomic_bool asm_vitrine_previewAsked, asm_vitrine_watched;

static ASMVitrineMusicEvent asm_vitrine_ring[kRingSize];
static atomic_uint asm_vitrine_head, asm_vitrine_tail;   // head moved by the render thread, tail by the player thread
static dispatch_semaphore_t asm_vitrine_wake;

static double asm_vitrine_secondsPerTick;

static void storeDouble(atomic_uint_fast64_t *slot, double value) {
    uint64_t bits;
    memcpy(&bits, &value, sizeof bits);
    atomic_store(slot, bits);
}

static double loadDouble(atomic_uint_fast64_t *slot) {
    uint64_t bits = atomic_load(slot);
    double value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

#pragma mark - the render thread

static ASMVitrineMusicAnalyzer asm_vitrine_analyzer;
static float asm_vitrine_mono[kMonoFrames];

static void pushEvent(const ASMVitrineMusicEvent *event, void *context) {
    unsigned head = atomic_load_explicit(&asm_vitrine_head, memory_order_relaxed);
    unsigned tail = atomic_load_explicit(&asm_vitrine_tail, memory_order_relaxed);
    if (head - tail >= kRingSize) return;
    asm_vitrine_ring[head & (kRingSize - 1)] = *event;
    atomic_store_explicit(&asm_vitrine_head, head + 1, memory_order_relaxed);
}

static inline float sampleAt(const void *data, UInt32 index, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4) {
        if (isFloat) return ((const float *)data)[index];
        int32_t value = ((const int32_t *)data)[index];
        return fraction ? (float)((double)value / (double)(1u << fraction)) : (float)(value / 2147483648.0);
    }
    return ((const int16_t *)data)[index] / 32768.0f;
}

// The hardware's format is float with a buffer per channel, but it is read rather than assumed (readFormat),
// and buffers not laid out the way it says are left alone rather than read as noise: the format read at the
// start can be a moment old. `refCon` is the unit; only the music's output is heard.
static OSStatus rendered(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp, UInt32 bus,
                         UInt32 frames, AudioBufferList *data) {
    if (!(*flags & kAudioUnitRenderAction_PostRender) || bus != 0 || !data || !data->mNumberBuffers || !frames) return noErr;
    if (!atomic_load_explicit(&asm_vitrine_listening, memory_order_relaxed) || refCon != ASMVitrinePlayerMusicOutput()) return noErr;
    if (*flags & kAudioUnitRenderAction_OutputIsSilence) return noErr;

    uint64_t layout = atomic_load_explicit(&asm_vitrine_layout, memory_order_relaxed);
    UInt32 formatFlags = (UInt32)layout, channels = (UInt32)(layout >> 32) & 0xffff, bytes = (UInt32)(layout >> 48);
    BOOL isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL split = (formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 fraction = (formatFlags & kLinearPCMFormatFlagsSampleFractionMask) >> kLinearPCMFormatFlagsSampleFractionShift;
    if ((bytes != 2 && bytes != 4) || channels < 1) return noErr;
    BOOL fits = split ? data->mNumberBuffers == channels : data->mNumberBuffers == 1 && data->mBuffers[0].mNumberChannels == channels;
    for (UInt32 b = 0; fits && b < data->mNumberBuffers; b++) {
        fits = data->mBuffers[b].mData && data->mBuffers[b].mDataByteSize == frames * bytes * (split ? 1 : channels);
    }
    if (!fits) {
        atomic_fetch_add_explicit(&asm_vitrine_skipped, 1, memory_order_relaxed);
        return noErr;
    }

    double sampleRate = loadDouble(&asm_vitrine_sampleRateBits);
    static double analyzedRate;
    static unsigned analyzedGeneration;
    unsigned generation = atomic_load_explicit(&asm_vitrine_generation, memory_order_relaxed);
    if (sampleRate <= 0) return noErr;
    if (sampleRate != analyzedRate || generation != analyzedGeneration) {
        ASMVitrineMusicAnalyzerReset(&asm_vitrine_analyzer, sampleRate, 1 / asm_vitrine_secondsPerTick);
        analyzedRate = sampleRate;
        analyzedGeneration = generation;
    }
    atomic_store_explicit(&asm_vitrine_lastFrames, frames, memory_order_relaxed);

    // The first two channels; a mono output is both.
    const void *left = data->mBuffers[0].mData, *right = split && channels > 1 ? data->mBuffers[1].mData : left;
    UInt32 stride = split ? 1 : channels, rightOffset = !split && channels > 1 ? 1 : 0;

    uint64_t hostTime = (timestamp->mFlags & kAudioTimeStampHostTimeValid) ? timestamp->mHostTime : mach_absolute_time();
    unsigned headBefore = atomic_load_explicit(&asm_vitrine_head, memory_order_relaxed);
    for (UInt32 done = 0; done < frames;) {
        UInt32 count = MIN(frames - done, (UInt32)kMonoFrames);
        for (UInt32 i = 0; i < count; i++) {
            UInt32 at = (done + i) * stride;
            asm_vitrine_mono[i] = 0.5f * (sampleAt(left, at, bytes, isFloat, fraction) + sampleAt(right, at + rightOffset, bytes, isFloat, fraction));
        }
        uint64_t chunkTime = hostTime + (uint64_t)(done / sampleRate / asm_vitrine_secondsPerTick);
        ASMVitrineMusicAnalyzerProcess(&asm_vitrine_analyzer, asm_vitrine_mono, count, chunkTime, pushEvent, NULL);
        done += count;
    }
    if (atomic_load_explicit(&asm_vitrine_head, memory_order_relaxed) != headBefore) dispatch_semaphore_signal(asm_vitrine_wake);
    return noErr;
}

#pragma mark - the output unit

static NSString *fourCC(UInt32 code) {
    char text[5] = {(char)(code >> 24), (char)(code >> 16), (char)(code >> 8), (char)code, 0};
    return @(text);
}

static NSString *formatText(AudioStreamBasicDescription format) {
    if (format.mFormatID != kAudioFormatLinearPCM) return [NSString stringWithFormat:@"'%@'", fourCC(format.mFormatID)];
    return [NSString stringWithFormat:@"%.0f Hz, %u channels, %u-bit %@%@", format.mSampleRate, (unsigned)format.mChannelsPerFrame,
            (unsigned)format.mBitsPerChannel, (format.mFormatFlags & kAudioFormatFlagIsFloat) ? @"float" : @"integer",
            (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? @", a buffer per channel" : @", interleaved"];
}

// The format the notify's buffers are in: the RemoteIO unit's output side (element 0, output scope), the
// hardware's, not the one Spotify hands the unit (the input scope). A format the analyzer cannot read
// leaves the buffers alone.
static void readFormat(AudioUnit unit) {
    AudioStreamBasicDescription format = {0}, client = {0};
    UInt32 size = sizeof format;
    OSStatus status = AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &format, &size);
    size = sizeof client;
    AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &client, &size);
    UInt32 bytes = format.mBitsPerChannel / 8;
    BOOL takes = status == noErr && format.mFormatID == kAudioFormatLinearPCM && format.mSampleRate > 0 && format.mChannelsPerFrame >= 1
                 && (bytes == 2 || bytes == 4) && ((format.mFormatFlags & kAudioFormatFlagIsFloat) || (format.mFormatFlags & kAudioFormatFlagIsSignedInteger));
    // Spotify starts its output again after every pause; the format is logged when it is not the last one.
    // Spotify's thread and a format change's may both be here.
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    static NSString *logged;
    NSString *text = [NSString stringWithFormat:@"music haptics: listening to Spotify's output at %@, from %@ Spotify hands it%@", formatText(format),
                      formatText(client), takes ? @"" : [NSString stringWithFormat:@"; not a format the analyzer reads (status %d), nothing plays", (int)status]];
    os_unfair_lock_lock(&lock);
    BOOL changed = ![text isEqualToString:logged];
    logged = text;
    os_unfair_lock_unlock(&lock);
    if (changed) ASMVitrineLog(@"%@", text);
    if (!takes) {
        atomic_store(&asm_vitrine_layout, 0);
        return;
    }
    storeDouble(&asm_vitrine_sampleRateBits, format.mSampleRate);
    atomic_store(&asm_vitrine_layout, (uint64_t)format.mFormatFlags | (uint64_t)(format.mChannelsPerFrame & 0xffff) << 32 | (uint64_t)bytes << 48);
}

// The music's output started, changed or changed format (Shared/Player): its format read, the notify on it,
// and the analyzer started over, since what it held came from before.
static void listenTo(AudioUnit unit) {
    if (!unit) return;
    AudioUnitRemoveRenderNotify(unit, rendered, unit);
    readFormat(unit);
    atomic_fetch_add(&asm_vitrine_generation, 1);
    OSStatus status = AudioUnitAddRenderNotify(unit, rendered, unit);
    if (status != noErr) ASMVitrineLog(@"music haptics: the render notify could not be added (%d)", (int)status);
}

#pragma mark - the player thread

static CHHapticEngine *asm_vitrine_engine;
static BOOL asm_vitrine_engineRunning;
static atomic_bool asm_vitrine_engineStopped;
static id<CHHapticAdvancedPatternPlayer> asm_vitrine_rumble;
static BOOL asm_vitrine_rumbling;
static double asm_vitrine_rumbleSentAt, asm_vitrine_quietSince;
static float asm_vitrine_rumbleSent;

typedef struct {
    NSUInteger taps, late, levels;
    double leadSum, leadMin;
} Stats;
static Stats asm_vitrine_stats;

static double hostSeconds(uint64_t ticks) {
    return ticks * asm_vitrine_secondsPerTick;
}

static float strength(void) {
    return (float)loadDouble(&asm_vitrine_strengthBits);
}

static BOOL startEngine(void) {
    static BOOL supported, checked;
    static double retryAt;
    if (!checked) {
        checked = YES;
        supported = CHHapticEngine.capabilitiesForHardware.supportsHaptics;
        if (!supported) ASMVitrineLog(@"music haptics: this device has no Taptic Engine for Core Haptics");
    }
    if (!supported) return NO;
    NSError *error = nil;
    if (!asm_vitrine_engine) {
        // Spotify's own session rather than a new one, and haptics only, so nothing touches its audio.
        asm_vitrine_engine = [[CHHapticEngine alloc] initWithAudioSession:AVAudioSession.sharedInstance error:&error];
        if (!asm_vitrine_engine) {
            ASMVitrineLog(@"music haptics: no haptic engine: %@", error);
            return NO;
        }
        asm_vitrine_engine.playsHapticsOnly = YES;
        asm_vitrine_engine.autoShutdownEnabled = NO;
        asm_vitrine_engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
            atomic_store(&asm_vitrine_engineStopped, true);
            ASMVitrineLog(@"music haptics: the engine stopped (reason %ld)", (long)reason);
        };
        asm_vitrine_engine.resetHandler = ^{
            atomic_store(&asm_vitrine_engineStopped, true);
            ASMVitrineLog(@"music haptics: the engine was reset");
        };
    }
    if (atomic_exchange(&asm_vitrine_engineStopped, false)) {
        asm_vitrine_engineRunning = NO;
        asm_vitrine_rumble = nil;
        asm_vitrine_rumbling = NO;
    }
    if (asm_vitrine_engineRunning) return YES;
    double now = hostSeconds(mach_absolute_time());
    if (now < retryAt) return NO;
    if (![asm_vitrine_engine startAndReturnError:&error]) {
        retryAt = now + kStartRetryAfter;
        static int logged;
        if (logged++ < 3) ASMVitrineLog(@"music haptics: the engine did not start: %@", error);
        return NO;
    }
    asm_vitrine_engineRunning = YES;
    return YES;
}

static void stopEngine(void) {
    [asm_vitrine_rumble stopAtTime:CHHapticTimeImmediate error:nil];
    asm_vitrine_rumble = nil;
    asm_vitrine_rumbling = NO;
    if (asm_vitrine_engineRunning) [asm_vitrine_engine stopWithCompletionHandler:nil];
    asm_vitrine_engineRunning = NO;
}

// When `hostTime`'s sound is heard, in the engine's clock; `lead` is how far ahead of now that is.
static NSTimeInterval engineTime(uint64_t hostTime, double *lead) {
    double now = hostSeconds(mach_absolute_time());
    double heard = hostSeconds(hostTime) + loadDouble(&asm_vitrine_latencyBits) - kHapticLead;
    *lead = heard - now;
    return asm_vitrine_engine.currentTime + MAX(0, *lead);
}

static CHHapticEventParameter *parameter(CHHapticEventParameterID identifier, float value) {
    return [[CHHapticEventParameter alloc] initWithParameterID:identifier value:value];
}

static void (^asm_vitrine_watcher)(float intensity);   // main thread

static void tellWatcher(float intensity, double lead) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MAX(0, lead) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (asm_vitrine_watcher) asm_vitrine_watcher(intensity);
    });
}

static void playTap(const ASMVitrineMusicEvent *event) {
    double lead;
    NSTimeInterval at = engineTime(event->hostTime, &lead);
    if (lead < -kLatestTap) {
        asm_vitrine_stats.late++;
        return;
    }
    CHHapticEvent *hit = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[
        parameter(CHHapticEventParameterIDHapticIntensity, MIN(1, event->intensity * kTapGain * strength())),
        parameter(CHHapticEventParameterIDHapticSharpness, event->sharpness),
    ] relativeTime:0];
    NSError *error = nil;
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[hit] parameters:@[] error:&error];
    id<CHHapticPatternPlayer> player = pattern ? [asm_vitrine_engine createPlayerWithPattern:pattern error:&error] : nil;
    if (!player || ![player startAtTime:at error:&error]) {
        static int logged;
        if (logged++ < 3) ASMVitrineLog(@"music haptics: a tap did not play: %@", error);
        if (error.code == CHHapticErrorCodeEngineNotRunning || error.code == CHHapticErrorCodeServerInterrupted) atomic_store(&asm_vitrine_engineStopped, true);
        return;
    }
    asm_vitrine_stats.taps++;
    if (atomic_load_explicit(&asm_vitrine_watched, memory_order_relaxed)) tellWatcher(event->intensity, lead);
    asm_vitrine_stats.leadSum += lead;
    asm_vitrine_stats.leadMin = asm_vitrine_stats.taps == 1 ? lead : MIN(asm_vitrine_stats.leadMin, lead);
}

// The preview's kick: a tap at the strength a full kick plays at, and under it a moment of the rumble unless
// only the beat is followed, both now rather than when a sound is heard.
static void playPreview(BOOL rumbles) {
    NSMutableArray<CHHapticEvent *> *events = [NSMutableArray arrayWithObject:[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[
        parameter(CHHapticEventParameterIDHapticIntensity, MIN(1, kTapGain * strength())),
        parameter(CHHapticEventParameterIDHapticSharpness, 0.4f),
    ] relativeTime:0]];
    if (rumbles) {
        [events addObject:[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[
            parameter(CHHapticEventParameterIDHapticIntensity, MIN(1, 0.5f * kRumbleGain * strength())),
            parameter(CHHapticEventParameterIDHapticSharpness, 0),
        ] relativeTime:0.02 duration:0.22]];
    }
    NSError *error = nil;
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:events parameters:@[] error:&error];
    id<CHHapticPatternPlayer> player = pattern ? [asm_vitrine_engine createPlayerWithPattern:pattern error:&error] : nil;
    if (!player || ![player startAtTime:CHHapticTimeImmediate error:&error]) ASMVitrineLog(@"music haptics: the preview did not play: %@", error);
}

static void stopRumble(NSTimeInterval at) {
    if (!asm_vitrine_rumbling) return;
    [asm_vitrine_rumble stopAtTime:at error:nil];
    asm_vitrine_rumbling = NO;
}

static void playLevel(const ASMVitrineMusicEvent *event) {
    asm_vitrine_stats.levels++;
    double lead;
    NSTimeInterval at = engineTime(event->hostTime, &lead);
    double heard = hostSeconds(event->hostTime);
    // Whether it rumbles is decided at 100%, so the strength changes how hard, not how often.
    float level = MIN(1, event->intensity * kRumbleGain);
    float played = MIN(1, level * strength());

    if (level < kRumbleStop) {
        if (!asm_vitrine_quietSince) asm_vitrine_quietSince = heard;
        if (heard - asm_vitrine_quietSince >= kRumbleStopAfter) stopRumble(at);
    } else {
        asm_vitrine_quietSince = 0;
    }
    if (!asm_vitrine_rumbling && level < kRumbleStart) return;
    if (asm_vitrine_rumbling && heard - asm_vitrine_rumbleSentAt < kRumbleInterval && fabsf(level - asm_vitrine_rumbleSent) < kRumbleStep) return;

    NSError *error = nil;
    if (!asm_vitrine_rumble) {
        // Sharpness 0 under a control that adds the level's own.
        CHHapticEvent *hum = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[
            parameter(CHHapticEventParameterIDHapticIntensity, 1),
            parameter(CHHapticEventParameterIDHapticSharpness, 0),
        ] relativeTime:0 duration:kRumbleLength];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[hum] parameters:@[] error:&error];
        asm_vitrine_rumble = pattern ? [asm_vitrine_engine createAdvancedPlayerWithPattern:pattern error:&error] : nil;
        asm_vitrine_rumble.loopEnabled = YES;
        if (!asm_vitrine_rumble) {
            static int logged;
            if (logged++ < 3) ASMVitrineLog(@"music haptics: no rumble: %@", error);
            return;
        }
    }
    NSArray<CHHapticDynamicParameter *> *controls = @[
        [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl value:played relativeTime:0],
        [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticSharpnessControl value:event->sharpness relativeTime:0],
    ];
    if (!asm_vitrine_rumbling) {
        [asm_vitrine_rumble sendParameters:controls atTime:CHHapticTimeImmediate error:nil];
        if (![asm_vitrine_rumble startAtTime:at error:&error]) {
            static int logged;
            if (logged++ < 3) ASMVitrineLog(@"music haptics: the rumble did not start: %@", error);
            asm_vitrine_rumble = nil;
            return;
        }
        asm_vitrine_rumbling = YES;
    } else {
        [asm_vitrine_rumble sendParameters:controls atTime:at error:nil];
    }
    asm_vitrine_rumbleSentAt = heard;
    asm_vitrine_rumbleSent = level;
}

static void report(void) {
    static double lastReport;
    static int reports;
    double now = hostSeconds(mach_absolute_time());
    if (!lastReport) lastReport = now;
    if (now - lastReport < 30 || reports >= 4 || !asm_vitrine_stats.levels) return;
    lastReport = now;
    reports++;
    ASMVitrineLog(@"music haptics: %lu taps (%lu too late), lead %.0f ms on average and %.0f ms at the least, %lu levels, rumble %@, buffers of %u frames at %.0f Hz (%llu skipped), output latency %.0f ms, strength %.0f%%, follows %d",
          (unsigned long)asm_vitrine_stats.taps, (unsigned long)asm_vitrine_stats.late, asm_vitrine_stats.taps ? asm_vitrine_stats.leadSum / asm_vitrine_stats.taps * 1000 : 0, asm_vitrine_stats.leadMin * 1000,
          (unsigned long)asm_vitrine_stats.levels, asm_vitrine_rumbling ? @"on" : @"off", atomic_load(&asm_vitrine_lastFrames), loadDouble(&asm_vitrine_sampleRateBits),
          (unsigned long long)atomic_load(&asm_vitrine_skipped), loadDouble(&asm_vitrine_latencyBits) * 1000, strength() * 100, atomic_load(&asm_vitrine_follows));
    asm_vitrine_stats = (Stats){0};
}

static double quietAfter(void) {
    double rate = loadDouble(&asm_vitrine_sampleRateBits);
    double buffer = rate > 0 ? atomic_load(&asm_vitrine_lastFrames) / rate : 0;
    return MAX(kQuietAfter, kQuietAfterBuffers * buffer);
}

static void *playerLoop(void *unused) {
    pthread_setname_np("asm.interface.vitrine.music-haptics");
    double lastEvent = 0;
    BOOL idle = YES;
    for (;;) {
        dispatch_time_t wait = idle ? DISPATCH_TIME_FOREVER : dispatch_time(DISPATCH_TIME_NOW, (int64_t)(quietAfter() * NSEC_PER_SEC));
        dispatch_semaphore_wait(asm_vitrine_wake, wait);
        @autoreleasepool {
            double now = hostSeconds(mach_absolute_time());
            if (!atomic_load(&asm_vitrine_listening)) {
                atomic_store(&asm_vitrine_previewAsked, false);
                atomic_store(&asm_vitrine_tail, atomic_load(&asm_vitrine_head));
                stopEngine();
                idle = YES;
                continue;
            }
            ASMVitrineMusicFollows follows = (ASMVitrineMusicFollows)atomic_load(&asm_vitrine_follows);
            BOOL rumbles = follows != ASMVitrineMusicFollowsBeat, snares = follows != ASMVitrineMusicFollowsBass;
            if (!rumbles) stopRumble(CHHapticTimeImmediate);
            BOOL any = NO;
            if (atomic_exchange(&asm_vitrine_previewAsked, false) && startEngine()) {
                playPreview(rumbles);
                any = YES;
            }
            unsigned head = atomic_load(&asm_vitrine_head), tail = atomic_load(&asm_vitrine_tail);
            if (tail != head && startEngine()) {
                for (; tail != head; tail++) {
                    ASMVitrineMusicEvent event = asm_vitrine_ring[tail & (kRingSize - 1)];
                    if (event.kind == ASMVitrineMusicEventLevel) {
                        if (rumbles) playLevel(&event);
                    } else if (event.kind == ASMVitrineMusicEventKick || snares) {
                        playTap(&event);
                    }
                }
                any = YES;
            }
            atomic_store(&asm_vitrine_tail, head);
            if (any) {
                lastEvent = now;
                idle = NO;
                report();
                continue;
            }
            if (now - lastEvent >= quietAfter()) stopRumble(CHHapticTimeImmediate);
            if (now - lastEvent >= kEngineStopAfter) {
                stopEngine();
                idle = YES;
            }
        }
    }
    return NULL;
}

#pragma mark - the switch and the app

static void readLatency(void) {
    AVAudioSession *session = AVAudioSession.sharedInstance;
    storeDouble(&asm_vitrine_latencyBits, session.outputLatency);
    static int logged;
    if (logged++ < 6) ASMVitrineLog(@"music haptics: output latency %.0f ms, IO buffer %.0f ms, route %@", session.outputLatency * 1000, session.IOBufferDuration * 1000, session.currentRoute.outputs.firstObject.portType);
}

static void updateListening(void) {
    BOOL listening = ASMVitrineMusicHapticsOn() && atomic_load(&asm_vitrine_active) && !atomic_load(&asm_vitrine_systemCovers);
    if (atomic_exchange(&asm_vitrine_listening, listening) == listening) return;
    if (listening) {
        atomic_fetch_add(&asm_vitrine_generation, 1);
        readLatency();
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            pthread_attr_t attributes;
            pthread_attr_init(&attributes);
            pthread_attr_set_qos_class_np(&attributes, QOS_CLASS_USER_INTERACTIVE, 0);
            pthread_t thread;
            pthread_create(&thread, &attributes, playerLoop, NULL);
            pthread_attr_destroy(&attributes);
        });
    }
    dispatch_semaphore_signal(asm_vitrine_wake);
}

void ASMVitrineMusicHapticsSetSystemCovers(BOOL covers) {
    if (atomic_exchange(&asm_vitrine_systemCovers, covers) == covers || !asm_vitrine_wake) return;
    if (ASMVitrineMusicHapticsOn()) ASMVitrineLog(@"music haptics: %@", covers ? @"iOS's own covers this song, standing down" : @"iOS's own does not play this song, playing along");
    updateListening();
}

static void readSettings(void) {
    storeDouble(&asm_vitrine_strengthBits, ASMVitrineHapticsStrength(ASMVitrineKeyMusicStrength));
    atomic_store(&asm_vitrine_follows, (int)ASMVitrineMusicHapticsFollows());
}

void ASMVitrineMusicHapticsSettingsChanged(void) {
    if (!asm_vitrine_wake) return;
    readSettings();
    // A rumble that is not to play any more stops now rather than with the next event.
    dispatch_semaphore_signal(asm_vitrine_wake);
}

void ASMVitrineMusicHapticsPreview(void) {
    if (!asm_vitrine_wake || !atomic_load(&asm_vitrine_listening)) return;
    atomic_store(&asm_vitrine_previewAsked, true);
    dispatch_semaphore_signal(asm_vitrine_wake);
}

void ASMVitrineMusicHapticsWatchTaps(void (^watcher)(float intensity)) {
    asm_vitrine_watcher = [watcher copy];
    atomic_store(&asm_vitrine_watched, watcher != nil);
}

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    ASMVitrineMigrateMusicHaptics();
    ASMVitrineMigrateKey(ASMVitrineKeyMusicStrengthWas, ASMVitrineKeyMusicStrength);
    ASMVitrineMigrateKey(ASMVitrineKeyMusicFollowsWas, ASMVitrineKeyMusicFollows);
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    asm_vitrine_secondsPerTick = (double)timebase.numer / timebase.denom / 1e9;
    if (!ASMVitrinePlayerWatchMusicOutput(listenTo)) {
        ASMVitrineLog(@"music haptics: Spotify's output cannot be reached, Music Haptics is inactive");
        return;
    }
    asm_vitrine_wake = dispatch_semaphore_create(0);
    readSettings();
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:ASMVitrineMusicHapticsSwitchesChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        updateListening();
    }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        atomic_store(&asm_vitrine_active, true);
        updateListening();
    }];
    [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        atomic_store(&asm_vitrine_active, false);
        updateListening();
    }];
    // Posted on the audio session's thread: a main-queue observer would make it wait for main (AGENTS.md).
    [center addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (atomic_load(&asm_vitrine_listening)) readLatency();
        });
    }];
}
