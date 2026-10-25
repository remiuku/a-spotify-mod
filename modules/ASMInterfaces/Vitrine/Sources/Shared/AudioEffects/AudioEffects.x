#import "Core/ASMHost.h"
#import "Core/ASMHost.h"
// Audio effects on Spotify's sound (AudioEffects.h): every buffer Spotify's output unit finishes runs
// through ASMVitrineDSPEngine before it reaches the speaker.
//
// Spotify plays through Core Audio units of its own (AudioUnitDriver2 in the binary: converter, EQ, mixer
// and a RemoteIO output unit, started with AudioOutputUnitStart), with no Objective-C method between it and
// the unit, and it can run two such chains at once, one per sample rate. Shared/Player keeps them apart and
// names the music's output (ASMVitrinePlayerMusicOutput); that one gets a render notify. After each render the notify
// reads the buffer bound for the speaker into float lanes, runs the engine over them and writes them back, in
// place: the way the first version of Pitch worked on the phone. A notify stays on a unit that was the music's
// once and does nothing there, so one engine never runs on two render threads. Speed and pitch feeds the
// unit's input, so its sound reaches the notify changed. After the engine, with the switch on or off, the notify
// hands the music's buffer mixed to mono to one reader (ASMVitrineAudioSetOutputReader), the player's Visualizer, which
// only reads it.
//
// The engine is made the first time the output starts with the master switch on, at the output's rate,
// and lives as long as Spotify: the render thread may be holding it at any time. With the switch off the
// notify returns straight away, and Spotify's sound is untouched. Silence goes through the engine too, so a
// reverb or a convolver rings out after a track stops.
//
// Settings apply as they change: ASMVitrineDSPApply marks the effect, and a serial queue reads its keys a moment
// later and sets them, so a slider dragged across comes down to the last few values. The queue also makes
// the engine, follows the output to a new sample rate, and once a second frees what the effects replaced.
//
// Threading: the notify runs on the render thread and touches only atomics, its scratch lanes and the
// engine's render side. Spotify starts its output on a thread of its own. The effects are set on the queue;
// ASMVitrineDSPApply and the curves are main thread; ASMVitrineDSPStatus and ASMVitrineDSPError any thread.
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <os/lock.h>
#import <stdatomic.h>
#import "Core/ASMVitrineCore.h"
#import "Shared/Player/SpeedPitch.h"
#import "AudioEffects.h"
#import "AudioEffectsApply.h"
#import "AudioEffectsPresets.h"
#import "ASMVitrineDSPEngine.h"

// A burst of changes to a setting is gathered this long before it applies.
static const double kApplyAfter = 0.03;
// How often a summary of the engine's work goes to the log while it runs.
static const double kSummaryEvery = 60;

enum { kScratchFrames = 4096 };

// The switches of the effects, in the order they are set when everything is.
static NSArray<NSString *> *effectSwitches(void) {
    return @[ASMVitrineKeyDSPCompander, ASMVitrineKeyDSPBass, ASMVitrineKeyDSPEqualizer, ASMVitrineKeyDSPGraphicEq, ASMVitrineKeyDSPConvolver, ASMVitrineKeyDSPDDC,
             ASMVitrineKeyDSPLiveprog, ASMVitrineKeyDSPReverb, ASMVitrineKeyDSPStereoWide, ASMVitrineKeyDSPCrossfeed, ASMVitrineKeyDSPTube];
}

#pragma mark - shared between the threads

typedef enum { ASMVitrineOutputUnseen, ASMVitrineOutputPCM, ASMVitrineOutputUnsupported } ASMVitrineOutputState;

static _Atomic(ASMVitrineDSPEngine *) asm_vitrine_engine;       // made once on the queue, never freed
static atomic_bool asm_vitrine_running;                 // the switch on and the engine set up for the output
static atomic_int asm_vitrine_outputState;
static BOOL asm_vitrine_reachable;                      // Shared/Player reaches Spotify's output
// The format of the buffers the notify gets: the rate, and the layout packed into one word so the render
// thread never reads half of a change (flags in the low 32 bits, then channels, then bytes per sample).
static atomic_uint_fast64_t asm_vitrine_rateBits;
static atomic_uint_fast64_t asm_vitrine_layout;
static atomic_uint_fast64_t asm_vitrine_skipped;        // renders whose buffers were not laid out as the format says

static os_unfair_lock asm_vitrine_errorLock = OS_UNFAIR_LOCK_INIT;
static NSMutableDictionary<NSString *, NSString *> *asm_vitrine_errors;

static void storeDouble(atomic_uint_fast64_t *slot, double value) {
    uint64_t bits;
    memcpy(&bits, &value, sizeof bits);
    atomic_store(slot, bits);
}

static double loadDouble(atomic_uint_fast64_t *slot) {
    uint64_t bits = atomic_load_explicit(slot, memory_order_relaxed);
    double value;
    memcpy(&value, &bits, sizeof value);
    return value;
}

#pragma mark - the render thread

static float asm_vitrine_left[kScratchFrames], asm_vitrine_right[kScratchFrames];

static inline float readSample(const void *data, UInt32 index, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4) {
        if (isFloat) return ((const float *)data)[index];
        int32_t value = ((const int32_t *)data)[index];
        return fraction ? (float)((double)value / (double)(1u << fraction)) : (float)(value / 2147483648.0);
    }
    return ((const int16_t *)data)[index] / 32768.0f;
}

// The same scale back as readSample's, rounded, so 16-bit samples the effects leave alone come back exact.
static inline void writeSample(void *data, UInt32 index, float value, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4 && isFloat) {
        ((float *)data)[index] = value;
        return;
    }
    if (bytes == 4) {
        double scale = fraction ? (double)(1u << fraction) : 2147483648.0;
        ((int32_t *)data)[index] = (int32_t)llrint(fmax(-2147483648.0, fmin(value * scale, 2147483647.0)));
    } else {
        ((int16_t *)data)[index] = (int16_t)lrintf(fmaxf(-32768, fminf(value * 32768, 32767)));
    }
}

static BOOL anySound(const float *samples, UInt32 count) {
    for (UInt32 i = 0; i < count; i++) if (samples[i] != 0) return YES;
    return NO;
}

static BOOL laidOut(const AudioBufferList *data, UInt32 frames, UInt32 channels, UInt32 bytes, BOOL split) {
    BOOL fits = split ? data->mNumberBuffers == channels : data->mNumberBuffers == 1 && data->mBuffers[0].mNumberChannels == channels;
    for (UInt32 b = 0; fits && b < data->mNumberBuffers; b++) {
        fits = data->mBuffers[b].mData && data->mBuffers[b].mDataByteSize == frames * bytes * (split ? 1 : channels);
    }
    return fits;
}

// The buffer through the engine in place, whatever its format: the buffers themselves as the engine's lanes
// when they are float, one per channel (the hardware's usual), otherwise read into the scratch lanes and
// written back. The first two channels are the engine's; a mono output is fed to both and gets their mean.
static void processBuffer(ASMVitrineDSPEngine *engine, AudioUnitRenderActionFlags *flags, UInt32 frames, AudioBufferList *data) {
    uint64_t layout = atomic_load_explicit(&asm_vitrine_layout, memory_order_relaxed);
    UInt32 formatFlags = (UInt32)layout, channels = (UInt32)(layout >> 32) & 0xffff, bytes = (UInt32)(layout >> 48);
    BOOL isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL split = (formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 fraction = (formatFlags & kLinearPCMFormatFlagsSampleFractionMask) >> kLinearPCMFormatFlagsSampleFractionShift;
    if ((bytes != 2 && bytes != 4) || channels < 1) return;
    // Buffers not laid out as the format says are left alone rather than read as noise: the format read at
    // the start can be a moment old.
    if (!laidOut(data, frames, channels, bytes, split)) {
        atomic_fetch_add_explicit(&asm_vitrine_skipped, 1, memory_order_relaxed);
        return;
    }
    // A silent buffer's contents are not promised; the engine gets zeros, and its tail replaces them.
    BOOL silent = (*flags & kAudioUnitRenderAction_OutputIsSilence) != 0;
    BOOL loud = NO;

    if (split && isFloat && bytes == 4 && channels >= 2) {
        float *left = data->mBuffers[0].mData, *right = data->mBuffers[1].mData;
        if (silent) {
            memset(left, 0, frames * sizeof(float));
            memset(right, 0, frames * sizeof(float));
        }
        ASMVitrineDSPEngineProcess(engine, left, right, frames);
        loud = !silent || anySound(left, frames) || anySound(right, frames);
    } else {
        for (UInt32 done = 0; done < frames;) {
            UInt32 count = MIN(frames - done, (UInt32)kScratchFrames);
            const void *first = data->mBuffers[0].mData, *second = split && channels > 1 ? data->mBuffers[1].mData : first;
            UInt32 stride = split ? 1 : channels, secondOffset = !split && channels > 1 ? 1 : 0;
            for (UInt32 i = 0; i < count; i++) {
                UInt32 at = (done + i) * stride;
                asm_vitrine_left[i] = silent ? 0 : readSample(first, at, bytes, isFloat, fraction);
                asm_vitrine_right[i] = silent ? 0 : readSample(second, at + secondOffset, bytes, isFloat, fraction);
            }
            ASMVitrineDSPEngineProcess(engine, asm_vitrine_left, asm_vitrine_right, count);
            loud = loud || !silent || anySound(asm_vitrine_left, count) || anySound(asm_vitrine_right, count);
            void *firstOut = data->mBuffers[0].mData, *secondOut = split && channels > 1 ? data->mBuffers[1].mData : firstOut;
            for (UInt32 i = 0; i < count; i++) {
                UInt32 at = (done + i) * stride;
                if (channels == 1) {
                    writeSample(firstOut, at, 0.5f * (asm_vitrine_left[i] + asm_vitrine_right[i]), bytes, isFloat, fraction);
                } else {
                    writeSample(firstOut, at, asm_vitrine_left[i], bytes, isFloat, fraction);
                    writeSample(secondOut, at + secondOffset, asm_vitrine_right[i], bytes, isFloat, fraction);
                }
            }
            done += count;
        }
    }
    if (loud) *flags &= ~kAudioUnitRenderAction_OutputIsSilence;
}

#pragma mark - the output's sound, read (AudioEffects.h)

static _Atomic(ASMVitrineAudioOutputReader) asm_vitrine_reader;
static float asm_vitrine_mono[kScratchFrames];

void ASMVitrineAudioSetOutputReader(ASMVitrineAudioOutputReader reader) {
    void (*set)(ASMVitrineAudioOutputReader) = dlsym(RTLD_DEFAULT,"ASMSetAudioOutputReader");
    if (set) set(reader);
}

// The buffer, as the effects left it, mixed to mono for the reader: its first two channels, or its one.
static void readOut(ASMVitrineAudioOutputReader reader, AudioUnitRenderActionFlags flags, UInt32 frames, const AudioBufferList *data) {
    uint64_t layout = atomic_load_explicit(&asm_vitrine_layout, memory_order_relaxed);
    UInt32 formatFlags = (UInt32)layout, channels = (UInt32)(layout >> 32) & 0xffff, bytes = (UInt32)(layout >> 48);
    BOOL isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0, split = (formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 fraction = (formatFlags & kLinearPCMFormatFlagsSampleFractionMask) >> kLinearPCMFormatFlagsSampleFractionShift;
    if ((bytes != 2 && bytes != 4) || channels < 1 || !laidOut(data, frames, channels, bytes, split)) return;
    BOOL silent = (flags & kAudioUnitRenderAction_OutputIsSilence) != 0;
    double rate = loadDouble(&asm_vitrine_rateBits);
    const void *first = data->mBuffers[0].mData, *second = split && channels > 1 ? data->mBuffers[1].mData : first;
    UInt32 stride = split ? 1 : channels, secondOffset = !split && channels > 1 ? 1 : 0;
    for (UInt32 done = 0; done < frames;) {
        UInt32 count = MIN(frames - done, (UInt32)kScratchFrames);
        for (UInt32 i = 0; i < count; i++) {
            UInt32 at = (done + i) * stride;
            asm_vitrine_mono[i] = silent ? 0 : 0.5f * (readSample(first, at, bytes, isFloat, fraction) + readSample(second, at + secondOffset, bytes, isFloat, fraction));
        }
        reader(asm_vitrine_mono, count, rate);
        done += count;
    }
}

// `refCon` is the unit; only the music's output is processed and read.
static OSStatus rendered(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp, UInt32 bus,
                         UInt32 frames, AudioBufferList *data) {
    if (!(*flags & kAudioUnitRenderAction_PostRender) || bus != 0 || !data || !data->mNumberBuffers || !frames) return noErr;
    if (refCon != ASMVitrinePlayerMusicOutput()) return noErr;
    if (atomic_load_explicit(&asm_vitrine_running, memory_order_acquire)) {
        ASMVitrineDSPEngine *engine = atomic_load_explicit(&asm_vitrine_engine, memory_order_acquire);
        // A new rate is being set up on the queue: until then the sound passes as it is.
        if (engine && ASMVitrineDSPEngineSampleRate(engine) == loadDouble(&asm_vitrine_rateBits)) processBuffer(engine, flags, frames, data);
    }
    ASMVitrineAudioOutputReader reader = atomic_load_explicit(&asm_vitrine_reader, memory_order_acquire);
    if (reader) readOut(reader, *flags, frames, data);
    return noErr;
}

#pragma mark - Spotify's audio thread

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

// The format the notify's buffers are in, which is the RemoteIO unit's output side (element 0, output scope):
// the hardware's, not the one Spotify hands the unit (the input scope). In the simulator a 44.1 kHz client
// comes out at 48 kHz, and a 16-bit interleaved one as float, a buffer per channel (harness/audio-effects/sim).
// Answers whether the engine can take it.
static BOOL readFormat(AudioUnit unit) {
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
    NSString *text = [NSString stringWithFormat:@"dsp: Spotify's output renders %@, from %@ Spotify hands it%@", formatText(format),
                      formatText(client), takes ? @"" : [NSString stringWithFormat:@"; not a format the engine takes (status %d), its sound passes as it is", (int)status]];
    os_unfair_lock_lock(&lock);
    BOOL changed = ![text isEqualToString:logged];
    logged = text;
    os_unfair_lock_unlock(&lock);
    if (changed) ASMVitrineLog(@"%@", text);
    if (!takes) {
        atomic_store(&asm_vitrine_layout, 0);
        atomic_store(&asm_vitrine_outputState, ASMVitrineOutputUnsupported);
        return NO;
    }
    storeDouble(&asm_vitrine_rateBits, format.mSampleRate);
    atomic_store(&asm_vitrine_layout, (uint64_t)format.mFormatFlags | (uint64_t)(format.mChannelsPerFrame & 0xffff) << 32 | (uint64_t)bytes << 48);
    atomic_store(&asm_vitrine_outputState, ASMVitrineOutputPCM);
    // The engine is made, or follows a new rate, when the switch is on.
    dispatch_async(dispatch_get_main_queue(), ^{
        ASMVitrineDSPApply(ASMVitrineKeyDSP);
    });
    return YES;
}

// The music's output started, changed or changed format (Shared/Player): its format read, the notify on it.
static void listenTo(AudioUnit unit) {
    if (!unit) return;
    AudioUnitRemoveRenderNotify(unit, rendered, unit);
    if (!readFormat(unit)) return;
    // The sound held from before the output stopped, or from another output, would play first; the stream
    // starts over instead.
    ASMVitrineDSPEngine *engine = atomic_load(&asm_vitrine_engine);
    if (engine) ASMVitrineDSPEngineRestart(engine);
    OSStatus status = AudioUnitAddRenderNotify(unit, rendered, unit);
    if (status != noErr) ASMVitrineLog(@"dsp: the render notify could not be added (%d)", (int)status);
}

#pragma mark - errors

// An effect's name in the log, by its switch key.
static NSString *effectName(NSString *effect) {
    NSDictionary<NSString *, NSString *> *names = @{
        ASMVitrineKeyDSPCompander: @"compander", ASMVitrineKeyDSPBass: @"bass boost", ASMVitrineKeyDSPEqualizer: @"equalizer", ASMVitrineKeyDSPGraphicEq: @"graphic EQ",
        ASMVitrineKeyDSPConvolver: @"convolver", ASMVitrineKeyDSPDDC: @"DDC", ASMVitrineKeyDSPLiveprog: @"Liveprog", ASMVitrineKeyDSPReverb: @"reverb",
        ASMVitrineKeyDSPStereoWide: @"stereo widening", ASMVitrineKeyDSPCrossfeed: @"crossfeed", ASMVitrineKeyDSPTube: @"analog modeling",
    };
    return names[effect] ?: effect;
}

static void setError(NSString *effect, NSString *message) {
    os_unfair_lock_lock(&asm_vitrine_errorLock);
    if (!asm_vitrine_errors) asm_vitrine_errors = [NSMutableDictionary dictionary];
    asm_vitrine_errors[effect] = message;
    os_unfair_lock_unlock(&asm_vitrine_errorLock);
    if (message) ASMVitrineLog(@"dsp: %@ did not take: %@", effectName(effect), message);
}

NSString *ASMVitrineDSPError(NSString *switchKey) {
    if (!switchKey) return nil;
    os_unfair_lock_lock(&asm_vitrine_errorLock);
    NSString *message = asm_vitrine_errors[switchKey];
    os_unfair_lock_unlock(&asm_vitrine_errorLock);
    return message;
}

#pragma mark - the queue: setting the effects

static NSString *onOff(BOOL on) {
    return on ? @"on" : @"off";
}

static NSString *gainsText(NSArray<NSNumber *> *gains) {
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:gains.count];
    for (NSNumber *gain in gains) [parts addObject:[NSString stringWithFormat:@"%g", gain.doubleValue]];
    return [parts componentsJoinedByString:@" "];
}

static NSString *choice(NSArray<NSString *> *names, NSString *key) {
    NSInteger index = (NSInteger)ASMVitrineDSPNumber(key);
    return index >= 0 && index < (NSInteger)names.count ? names[index] : @(index).stringValue;
}

// A file effect's file, from its library by name: its path, nil and an error when there is none to read.
static NSString *libraryFile(ASMVitrineDSPFileKind kind, NSString *nameKey, NSString *effect, BOOL on) {
    NSString *name = ASMVitrineDSPString(nameKey);
    if (!on) return nil;
    if (!name.length) {
        setError(effect, @"No file is chosen");
        return nil;
    }
    NSString *path = [ASMVitrineDSPLibraryDirectory(kind) stringByAppendingPathComponent:name.lastPathComponent];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        setError(effect, [NSString stringWithFormat:@"%@ is not in the library any more", name]);
        return nil;
    }
    return path;
}

// A text file with a NUL after it, for the parsers.
static NSData *textFile(NSString *path) {
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    [data appendBytes:"" length:1];
    return data;
}

static void applyOutput(ASMVitrineDSPEngine *engine) {
    double gain = ASMVitrineDSPNumber(ASMVitrineKeyDSPPostGain), threshold = ASMVitrineDSPNumber(ASMVitrineKeyDSPLimiterThreshold), release = ASMVitrineDSPNumber(ASMVitrineKeyDSPLimiterRelease);
    ASMVitrineDSPEngineSetOutput(engine, gain, threshold, release);
    // Set again on every start of Spotify's output; logged when it changed.
    static NSString *logged;
    NSString *text = [NSString stringWithFormat:@"dsp: output gain %+.1f dB, limiter at %.1f dB releasing in %.1f ms", gain, threshold, release];
    if (![text isEqualToString:logged]) ASMVitrineLog(@"%@", text);
    logged = text;
}

static void applyEffect(ASMVitrineDSPEngine *engine, NSString *effect) {
    BOOL on = ASMVitrineDSPSwitch(effect);
    char error[300] = "";
    BOOL ok = YES;
    NSString *what = @"";
    if ([effect isEqualToString:ASMVitrineKeyDSPCompander]) {
        NSArray<NSNumber *> *gains = ASMVitrineDSPGains(ASMVitrineKeyDSPCompanderGains);
        double values[7];
        for (int i = 0; i < 7; i++) values[i] = gains[i].doubleValue;
        double time = ASMVitrineDSPNumber(ASMVitrineKeyDSPCompanderTime);
        ASMVitrineDSPEngineSetCompander(engine, on, time, ASMVitrineDSPCompanderFrequencies, values);
        what = [NSString stringWithFormat:@"compander %@, %.2f s, amounts %@", onOff(on), time, gainsText(gains)];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPBass]) {
        double gain = ASMVitrineDSPNumber(ASMVitrineKeyDSPBassGain);
        ASMVitrineDSPEngineSetBassBoost(engine, on, gain);
        what = [NSString stringWithFormat:@"bass boost %@, %.1f dB", onOff(on), gain];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPEqualizer]) {
        NSArray<NSNumber *> *gains = ASMVitrineDSPGains(ASMVitrineKeyDSPEqualizerGains);
        double values[15];
        for (int i = 0; i < 15; i++) values[i] = gains[i].doubleValue;
        ASMVitrineDSPEngineSetEqualizer(engine, on, ASMVitrineDSPEqualizerFrequencies, values);
        what = [NSString stringWithFormat:@"equalizer %@, gains %@", onOff(on), gainsText(gains)];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPGraphicEq]) {
        NSString *nodes = ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqNodes);
        ok = ASMVitrineDSPEngineSetGraphicEq(engine, on, nodes.UTF8String, error, sizeof error);
        NSUInteger count = [nodes componentsSeparatedByString:@";"].count;
        what = [NSString stringWithFormat:@"Graphic EQ %@, about %lu points", onOff(on), (unsigned long)(count > 1 ? count - 1 : count)];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPConvolver]) {
        NSString *path = libraryFile(ASMVitrineDSPFileImpulseResponse, ASMVitrineKeyDSPConvolverFile, effect, on);
        if (on && !path) {
            ASMVitrineDSPEngineSetConvolver(engine, false, NULL, 0, error, sizeof error);
            return;
        }
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        ok = ASMVitrineDSPEngineSetConvolver(engine, on, path.fileSystemRepresentation, (int)ASMVitrineDSPNumber(ASMVitrineKeyDSPConvolverMode), error, sizeof error);
        what = [NSString stringWithFormat:@"convolver %@%@%@", onOff(on), on ? @", " : @"", on ? [NSString stringWithFormat:@"%@ (%@) read in %.0f ms",
                path.lastPathComponent, choice(ASMVitrineDSPConvolverModeNames(), ASMVitrineKeyDSPConvolverMode), (CFAbsoluteTimeGetCurrent() - start) * 1000] : @""];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPDDC]) {
        NSString *path = libraryFile(ASMVitrineDSPFileDDC, ASMVitrineKeyDSPDDCFile, effect, on);
        if (on && !path) {
            ASMVitrineDSPEngineSetDDC(engine, false, NULL, error, sizeof error);
            return;
        }
        NSData *text = on ? textFile(path) : nil;
        ok = ASMVitrineDSPEngineSetDDC(engine, on, text.bytes, error, sizeof error);
        what = [NSString stringWithFormat:@"DDC %@%@%@", onOff(on), on ? @", " : @"", on ? path.lastPathComponent : @""];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPLiveprog]) {
        NSString *path = libraryFile(ASMVitrineDSPFileLiveprog, ASMVitrineKeyDSPLiveprogFile, effect, on);
        if (on && !path) {
            ASMVitrineDSPEngineSetLiveprog(engine, false, NULL, error, sizeof error);
            return;
        }
        NSData *script = on ? textFile(path) : nil;
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        ok = ASMVitrineDSPEngineSetLiveprog(engine, on, script.bytes, error, sizeof error);
        what = [NSString stringWithFormat:@"Liveprog %@%@%@", onOff(on), on ? @", " : @"", on ? [NSString stringWithFormat:@"%@ compiled in %.0f ms",
                path.lastPathComponent, (CFAbsoluteTimeGetCurrent() - start) * 1000] : @""];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPReverb]) {
        ASMVitrineDSPEngineSetReverb(engine, on, (int)ASMVitrineDSPNumber(ASMVitrineKeyDSPReverbPreset), (float)ASMVitrineDSPNumber(ASMVitrineKeyDSPReverbAmount));
        what = [NSString stringWithFormat:@"reverb %@, %@", onOff(on), choice(ASMVitrineDSPReverbPresetNames(), ASMVitrineKeyDSPReverbPreset)];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPStereoWide]) {
        double level = ASMVitrineDSPNumber(ASMVitrineKeyDSPStereoWideLevel);
        ASMVitrineDSPEngineSetStereoWide(engine, on, level);
        what = [NSString stringWithFormat:@"stereo widening %@, %.0f%%", onOff(on), level];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPCrossfeed]) {
        ASMVitrineDSPEngineSetCrossfeed(engine, on, (int)ASMVitrineDSPNumber(ASMVitrineKeyDSPCrossfeedMode));
        what = [NSString stringWithFormat:@"crossfeed %@, %@", onOff(on), choice(ASMVitrineDSPCrossfeedModeNames(), ASMVitrineKeyDSPCrossfeedMode)];
    } else if ([effect isEqualToString:ASMVitrineKeyDSPTube]) {
        double drive = ASMVitrineDSPNumber(ASMVitrineKeyDSPTubeDrive);
        ASMVitrineDSPEngineSetTube(engine, on, drive);
        what = [NSString stringWithFormat:@"analog modeling %@, %.1f dB", onOff(on), drive];
    } else {
        return;
    }
    setError(effect, ok ? nil : @(error));
    if (ok) ASMVitrineLog(@"dsp: %@", what);
}

#pragma mark - the queue: the engine

static dispatch_queue_t applyQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("asm.interface.vitrine.dsp", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    });
    return queue;
}

static void applyAll(ASMVitrineDSPEngine *engine) {
    applyOutput(engine);
    for (NSString *effect in effectSwitches()) applyEffect(engine, effect);
}

// Once a second while the engine lives: what the effects replaced freed, an engine gone non-finite started
// over, and now and then a summary.
static void tend(void) {
    ASMVitrineDSPEngine *engine = atomic_load(&asm_vitrine_engine);
    ASMVitrineDSPEngineCollect(engine);
    static uint64_t faults, blocks, skipped;
    static CFAbsoluteTime summarized, skipsLogged;
    ASMVitrineDSPEngineStats stats = ASMVitrineDSPEngineReadStats(engine, true);
    if (stats.faults != faults) {
        faults = stats.faults;
        ASMVitrineLog(@"dsp: the output stopped being finite (%llu blocks silenced), the engine starts over", stats.faults);
        ASMVitrineDSPEngineReset(engine);
        applyAll(engine);
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    uint64_t skippedNow = atomic_load(&asm_vitrine_skipped);
    if (skippedNow != skipped && now - skipsLogged >= 10) {
        ASMVitrineLog(@"dsp: %llu renders left alone, their buffers not laid out as the output's format says", skippedNow - skipped);
        skipped = skippedNow;
        skipsLogged = now;
    }
    if (stats.blocks != blocks && now - summarized >= kSummaryEvery) {
        summarized = now;
        ASMVitrineLog(@"dsp: %llu blocks processed, %llu passed dry while settings changed, %.2f ms a block (%.1f%% of its time), %.2f ms at most",
              stats.blocks - blocks, stats.dry, stats.averageMS, stats.load * 100, stats.peakMS);
        blocks = stats.blocks;
    }
}

// The engine is read out once a second while it runs. With the switch off there is nothing in it to
// read, so the source is suspended rather than left ticking for the rest of the app's life: the engine
// is never freed, and a timer tied to its making would outlive every use of it. Only ever touched from
// applyMaster, which is to say on applyQueue().
static dispatch_source_t asm_vitrine_tendTimer;
static BOOL asm_vitrine_tending;

static void setTending(BOOL on) {
    if (!asm_vitrine_tendTimer || on == asm_vitrine_tending) return;
    asm_vitrine_tending = on;
    if (on) dispatch_resume(asm_vitrine_tendTimer);
    else dispatch_suspend(asm_vitrine_tendTimer);
}

// The switch and the output's format: the engine made or moved to the output's rate, everything set when
// it was, and the notify let in or kept out. Answers whether every effect was set.
static BOOL applyMaster(void) {
    if (!ASMVitrineDSPSwitch(ASMVitrineKeyDSP)) {
        setTending(NO);
        if (atomic_exchange(&asm_vitrine_running, false)) ASMVitrineLog(@"dsp: off, Spotify's sound passes as it is");
        return NO;
    }
    double rate = loadDouble(&asm_vitrine_rateBits);
    if (atomic_load(&asm_vitrine_outputState) != ASMVitrineOutputPCM || rate <= 0) {
        ASMVitrineLog(@"dsp: on, waiting for Spotify to start its output");
        return NO;
    }
    ASMVitrineDSPEngine *engine = atomic_load(&asm_vitrine_engine);
    BOOL everything = NO;
    if (!engine) {
        engine = ASMVitrineDSPEngineCreate(rate);
        if (!engine) {
            ASMVitrineLog(@"dsp: the engine could not be made at %.0f Hz", rate);
            return NO;
        }
        ASMVitrineLog(@"dsp: engine made at %.0f Hz, blocks of %d frames, so the sound is %.1f ms later", rate, kSGDSPEngineBlock,
              kSGDSPEngineBlock / rate * 1000);
        atomic_store(&asm_vitrine_engine, engine);
        // A source comes up suspended; setTending below is what starts it.
        asm_vitrine_tendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, applyQueue());
        dispatch_source_set_timer(asm_vitrine_tendTimer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 4);
        dispatch_source_set_event_handler(asm_vitrine_tendTimer, ^{
            tend();
        });
        everything = YES;
    } else if (ASMVitrineDSPEngineSampleRate(engine) != rate) {
        ASMVitrineDSPEngineSetSampleRate(engine, rate);
        ASMVitrineLog(@"dsp: the engine follows the output to %.0f Hz", rate);
        everything = YES;
    }
    if (everything) applyAll(engine);
    else applyOutput(engine);
    if (!atomic_load(&asm_vitrine_running)) {
        ASMVitrineDSPEngineRestart(engine);
        atomic_store_explicit(&asm_vitrine_running, true, memory_order_release);
        ASMVitrineLog(@"dsp: on");
    }
    setTending(YES);
    return everything;
}

static os_unfair_lock asm_vitrine_pendingLock = OS_UNFAIR_LOCK_INIT;
static NSMutableOrderedSet<NSString *> *asm_vitrine_pending;
static BOOL asm_vitrine_drainScheduled;

static void drain(void) {
    os_unfair_lock_lock(&asm_vitrine_pendingLock);
    NSArray<NSString *> *effects = asm_vitrine_pending.array;
    asm_vitrine_pending = nil;
    asm_vitrine_drainScheduled = NO;
    os_unfair_lock_unlock(&asm_vitrine_pendingLock);
    if ([effects containsObject:ASMVitrineKeyDSP] && applyMaster()) return;
    ASMVitrineDSPEngine *engine = atomic_load(&asm_vitrine_engine);
    // Without an engine nothing is set: it is set up with every effect when it is made.
    if (!engine) return;
    for (NSString *effect in effects) {
        if (![effect isEqualToString:ASMVitrineKeyDSP]) applyEffect(engine, effect);
    }
}

void ASMVitrineDSPApply(NSString *effect) {
    if (!effect) return;
    os_unfair_lock_lock(&asm_vitrine_pendingLock);
    if (!asm_vitrine_pending) asm_vitrine_pending = [NSMutableOrderedSet orderedSet];
    [asm_vitrine_pending addObject:effect];
    BOOL schedule = !asm_vitrine_drainScheduled;
    asm_vitrine_drainScheduled = YES;
    os_unfair_lock_unlock(&asm_vitrine_pendingLock);
    if (schedule) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kApplyAfter * NSEC_PER_SEC)), applyQueue(), ^{
        drain();
    });
}

#pragma mark - what the page shows

NSString *ASMVitrineDSPStatus(void) {
    if (!ASMVitrineDSPSwitch(ASMVitrineKeyDSP)) return @"Off";
    if (atomic_load(&asm_vitrine_outputState) == ASMVitrineOutputUnsupported) return @"Spotify's output is in a format the engine does not take";
    ASMVitrineDSPEngine *engine = atomic_load(&asm_vitrine_engine);
    if (!asm_vitrine_reachable) return @"Unavailable: Spotify's output could not be reached";
    if (!engine || !atomic_load(&asm_vitrine_running)) return @"Waiting for Spotify to play";
    double rate = ASMVitrineDSPEngineSampleRate(engine);
    double load = ASMVitrineDSPEngineReadStats(engine, false).load;
    return [NSString stringWithFormat:@"Running at %@ kHz, %.1f%% load", [NSString stringWithFormat:@"%g", rate / 1000], load * 100];
}

void ASMVitrineDSPEqualizerResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *decibels) {
    if (count <= 0 || !frequencies || !decibels) return;
    double values[15] = {0};
    for (NSUInteger i = 0; i < 15 && i < gains.count; i++) values[i] = gains[i].doubleValue;
    ASMVitrineDSPEngineEqualizerCurve(ASMVitrineDSPEqualizerFrequencies, values, (int)count, frequencies, decibels);
}

void ASMVitrineDSPCompanderResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *values) {
    if (count <= 0 || !frequencies || !values) return;
    double bands[7] = {0};
    for (NSUInteger i = 0; i < 7 && i < gains.count; i++) bands[i] = gains[i].doubleValue;
    ASMVitrineDSPEngineCompanderCurve(ASMVitrineDSPCompanderFrequencies, bands, (int)count, frequencies, values);
}

// The output audio goes to now, for the corrections remembered per output (AutoEq.m).
static void followRoute(void) {
    AVAudioSessionPortDescription *port = AVAudioSession.sharedInstance.currentRoute.outputs.firstObject;
    if (port) ASMVitrineAutoEqOutputChanged(port.UID, port.portName);
}

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    // Posted on the audio session's thread: handed to main without waiting, so it cannot deadlock against main.
    [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{ followRoute(); });
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        followRoute();
    });
    asm_vitrine_reachable = ASMVitrinePlayerWatchMusicOutput(listenTo);
    if (!asm_vitrine_reachable) {
        ASMVitrineLog(@"dsp: Spotify's output cannot be reached, the effects cannot reach its sound");
        return;
    }
    ASMVitrineLog(@"dsp: listening for Spotify's output unit (%@)", ASMVitrineDSPSwitch(ASMVitrineKeyDSP) ? @"on" : @"off");
}
