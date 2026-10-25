// JamesDSP on Spotify's sound (JamesDSP.h): every buffer Spotify's output unit finishes runs through
// ASMSpotiDSPEngine before it reaches the speaker.
//
// Spotify plays through Core Audio units of its own (AudioUnitDriver2 in the binary: converter, EQ, mixer
// and a RemoteIO output unit, started with AudioOutputUnitStart), with no Objective-C method between it and
// the unit. So Spotify's import of AudioOutputUnitStart is rebound (Core/ASMSpotiRebind.h; Music Haptics and Speed
// and pitch rebind it too, and each replacement calls on what the slot held), and every RemoteIO unit it
// starts gets a render notify. After each render the notify reads the buffer bound for the speaker into
// float lanes, runs the engine over them and writes them back, in place: the way the first version of Pitch
// worked on the phone. Speed and pitch feeds the unit's input, so its sound reaches the notify changed.
//
// The engine is made the first time the output starts with the master switch on, at the output's rate,
// and lives as long as Spotify: the render thread may be holding it at any time. With the switch off the
// notify returns straight away, and Spotify's sound is untouched. Silence goes through the engine too, so a
// reverb or a convolver rings out after a track stops.
//
// Settings apply as they change: ASMSpotiDSPApply marks the effect, and a serial queue reads its keys a moment
// later and sets them, so a slider dragged across comes down to the last few values. The queue also makes
// the engine, follows the output to a new sample rate, and once a second logs what libjamesdsp printed.
//
// Threading: the notify runs on the render thread and touches only atomics, its scratch lanes and the
// engine's render side. Spotify starts its output on a thread of its own. The effects are set on the queue;
// ASMSpotiDSPApply and the curves are main thread; ASMSpotiDSPStatus and ASMSpotiDSPError any thread.
#import <AudioToolbox/AudioToolbox.h>
#import <os/lock.h>
#import <stdatomic.h>
#import "Core/ASMSpotiCore.h"
#import "Core/ASMSpotiRebind.h"
#import "JamesDSP.h"
#import "JamesDSPEngine.h"
#import "ASMSpotiDSPEngine.h"

// A burst of changes to a setting is gathered this long before it applies.
static const double kApplyAfter = 0.03;
// libjamesdsp's printed lines logged per second at most; the rest are counted.
static const unsigned kLogLinesPerSecond = 8;
// How often a summary of the engine's work goes to the log while it runs.
static const double kSummaryEvery = 60;

enum { kScratchFrames = 4096 };

// The switches of the effects, in the order they are set when everything is.
static NSArray<NSString *> *effectSwitches(void) {
    return @[ASMSpotiKeyDSPCompander, ASMSpotiKeyDSPBass, ASMSpotiKeyDSPEqualizer, ASMSpotiKeyDSPGraphicEq, ASMSpotiKeyDSPConvolver, ASMSpotiKeyDSPDDC,
             ASMSpotiKeyDSPLiveprog, ASMSpotiKeyDSPReverb, ASMSpotiKeyDSPStereoWide, ASMSpotiKeyDSPCrossfeed, ASMSpotiKeyDSPTube];
}

#pragma mark - shared between the threads

typedef enum { ASMSpotiOutputUnseen, ASMSpotiOutputPCM, ASMSpotiOutputUnsupported } ASMSpotiOutputState;

static _Atomic(ASMSpotiDSPEngine *) asm_spotipw_engine;       // made once on the queue, never freed
static atomic_bool asm_spotipw_running;                 // the switch on and the engine set up for the output
static atomic_int asm_spotipw_outputState;
// The format of the buffers the notify gets: the rate, and the layout packed into one word so the render
// thread never reads half of a change (flags in the low 32 bits, then channels, then bytes per sample).
static atomic_uint_fast64_t asm_spotipw_rateBits;
static atomic_uint_fast64_t asm_spotipw_layout;
static atomic_uint_fast64_t asm_spotipw_skipped;        // renders whose buffers were not laid out as the format says

static os_unfair_lock asm_spotipw_errorLock = OS_UNFAIR_LOCK_INIT;
static NSMutableDictionary<NSString *, NSString *> *asm_spotipw_errors;

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

static float asm_spotipw_left[kScratchFrames], asm_spotipw_right[kScratchFrames];

static inline float readSample(const void *data, UInt32 index, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4) {
        if (isFloat) return ((const float *)data)[index];
        int32_t value = ((const int32_t *)data)[index];
        return fraction ? (float)((double)value / (double)(1u << fraction)) : (float)(value / 2147483648.0);
    }
    return ((const int16_t *)data)[index] / 32768.0f;
}

static inline void writeSample(void *data, UInt32 index, float value, UInt32 bytes, BOOL isFloat, UInt32 fraction) {
    if (bytes == 4 && isFloat) {
        ((float *)data)[index] = value;
        return;
    }
    value = fmaxf(-1, fminf(value, 1));
    if (bytes == 4) {
        double scale = fraction ? (double)(1u << fraction) : 2147483647.0;
        ((int32_t *)data)[index] = (int32_t)(value * scale);
    } else {
        ((int16_t *)data)[index] = (int16_t)(value * 32767);
    }
}

static BOOL anySound(const float *samples, UInt32 count) {
    for (UInt32 i = 0; i < count; i++) if (samples[i] != 0) return YES;
    return NO;
}

// The buffer through the engine in place, whatever its format: the buffers themselves as the engine's lanes
// when they are float, one per channel (the hardware's usual), otherwise read into the scratch lanes and
// written back. The first two channels are the engine's; a mono output is fed to both and gets their mean.
static void processBuffer(ASMSpotiDSPEngine *engine, AudioUnitRenderActionFlags *flags, UInt32 frames, AudioBufferList *data) {
    uint64_t layout = atomic_load_explicit(&asm_spotipw_layout, memory_order_relaxed);
    UInt32 formatFlags = (UInt32)layout, channels = (UInt32)(layout >> 32) & 0xffff, bytes = (UInt32)(layout >> 48);
    BOOL isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL split = (formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 fraction = (formatFlags & kLinearPCMFormatFlagsSampleFractionMask) >> kLinearPCMFormatFlagsSampleFractionShift;
    if ((bytes != 2 && bytes != 4) || channels < 1) return;
    // Buffers not laid out as the format says are left alone rather than read as noise: the format read at
    // the start can be a moment old.
    BOOL fits = split ? data->mNumberBuffers == channels : data->mNumberBuffers == 1 && data->mBuffers[0].mNumberChannels == channels;
    for (UInt32 b = 0; fits && b < data->mNumberBuffers; b++) {
        fits = data->mBuffers[b].mData && data->mBuffers[b].mDataByteSize == frames * bytes * (split ? 1 : channels);
    }
    if (!fits) {
        atomic_fetch_add_explicit(&asm_spotipw_skipped, 1, memory_order_relaxed);
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
        ASMSpotiDSPEngineProcess(engine, left, right, frames);
        loud = !silent || anySound(left, frames) || anySound(right, frames);
    } else {
        for (UInt32 done = 0; done < frames;) {
            UInt32 count = MIN(frames - done, (UInt32)kScratchFrames);
            const void *first = data->mBuffers[0].mData, *second = split && channels > 1 ? data->mBuffers[1].mData : first;
            UInt32 stride = split ? 1 : channels, secondOffset = !split && channels > 1 ? 1 : 0;
            for (UInt32 i = 0; i < count; i++) {
                UInt32 at = (done + i) * stride;
                asm_spotipw_left[i] = silent ? 0 : readSample(first, at, bytes, isFloat, fraction);
                asm_spotipw_right[i] = silent ? 0 : readSample(second, at + secondOffset, bytes, isFloat, fraction);
            }
            ASMSpotiDSPEngineProcess(engine, asm_spotipw_left, asm_spotipw_right, count);
            loud = loud || !silent || anySound(asm_spotipw_left, count) || anySound(asm_spotipw_right, count);
            void *firstOut = data->mBuffers[0].mData, *secondOut = split && channels > 1 ? data->mBuffers[1].mData : firstOut;
            for (UInt32 i = 0; i < count; i++) {
                UInt32 at = (done + i) * stride;
                if (channels == 1) {
                    writeSample(firstOut, at, 0.5f * (asm_spotipw_left[i] + asm_spotipw_right[i]), bytes, isFloat, fraction);
                } else {
                    writeSample(firstOut, at, asm_spotipw_left[i], bytes, isFloat, fraction);
                    writeSample(secondOut, at + secondOffset, asm_spotipw_right[i], bytes, isFloat, fraction);
                }
            }
            done += count;
        }
    }
    if (loud) *flags &= ~kAudioUnitRenderAction_OutputIsSilence;
}

static OSStatus rendered(void *refCon, AudioUnitRenderActionFlags *flags, const AudioTimeStamp *timestamp, UInt32 bus,
                         UInt32 frames, AudioBufferList *data) {
    if (!(*flags & kAudioUnitRenderAction_PostRender) || bus != 0 || !data || !data->mNumberBuffers || !frames) return noErr;
    if (!atomic_load_explicit(&asm_spotipw_running, memory_order_acquire)) return noErr;
    ASMSpotiDSPEngine *engine = atomic_load_explicit(&asm_spotipw_engine, memory_order_acquire);
    // A new rate is being set up on the queue: until then the sound passes as it is.
    if (!engine || ASMSpotiDSPEngineSampleRate(engine) != loadDouble(&asm_spotipw_rateBits)) return noErr;
    processBuffer(engine, flags, frames, data);
    return noErr;
}

#pragma mark - Spotify's audio thread

static NSString *fourCC(UInt32 code) {
    char text[5] = {(char)(code >> 24), (char)(code >> 16), (char)(code >> 8), (char)code, 0};
    return @(text);
}

static BOOL isRemoteIO(AudioUnit unit) {
    AudioComponentDescription description = {0};
    if (!unit || AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &description) != noErr) return NO;
    return description.componentType == kAudioUnitType_Output && description.componentSubType == kAudioUnitSubType_RemoteIO;
}

static NSString *formatText(AudioStreamBasicDescription format) {
    if (format.mFormatID != kAudioFormatLinearPCM) return [NSString stringWithFormat:@"'%@'", fourCC(format.mFormatID)];
    return [NSString stringWithFormat:@"%.0f Hz, %u channels, %u-bit %@%@", format.mSampleRate, (unsigned)format.mChannelsPerFrame,
            (unsigned)format.mBitsPerChannel, (format.mFormatFlags & kAudioFormatFlagIsFloat) ? @"float" : @"integer",
            (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? @", a buffer per channel" : @", interleaved"];
}

// The format the notify's buffers are in, which is the RemoteIO unit's output side (element 0, output scope):
// the hardware's, not the one Spotify hands the unit (the input scope). In the simulator a 44.1 kHz client
// comes out at 48 kHz, and a 16-bit interleaved one as float, a buffer per channel (harness/jamesdsp/sim).
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
    NSString *text = [NSString stringWithFormat:@"jamesdsp: Spotify's output renders %@, from %@ Spotify hands it%@", formatText(format),
                      formatText(client), takes ? @"" : [NSString stringWithFormat:@"; not a format the engine takes (status %d), its sound passes as it is", (int)status]];
    os_unfair_lock_lock(&lock);
    BOOL changed = ![text isEqualToString:logged];
    logged = text;
    os_unfair_lock_unlock(&lock);
    if (changed) ASMSpotiLog(@"%@", text);
    if (!takes) {
        atomic_store(&asm_spotipw_layout, 0);
        atomic_store(&asm_spotipw_outputState, ASMSpotiOutputUnsupported);
        return NO;
    }
    storeDouble(&asm_spotipw_rateBits, format.mSampleRate);
    atomic_store(&asm_spotipw_layout, (uint64_t)format.mFormatFlags | (uint64_t)(format.mChannelsPerFrame & 0xffff) << 32 | (uint64_t)bytes << 48);
    atomic_store(&asm_spotipw_outputState, ASMSpotiOutputPCM);
    // The engine is made, or follows a new rate, when the switch is on.
    dispatch_async(dispatch_get_main_queue(), ^{
        ASMSpotiDSPApply(ASMSpotiKeyDSP);
    });
    return YES;
}

// The hardware's format changing under a running unit (a route to a device at another rate).
static void formatChanged(void *refCon, AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element) {
    if (property == kAudioUnitProperty_StreamFormat && scope == kAudioUnitScope_Output && element == 0) readFormat(unit);
}

static void listenTo(AudioUnit unit) {
    AudioUnitRemoveRenderNotify(unit, rendered, NULL);
    AudioUnitRemovePropertyListenerWithUserData(unit, kAudioUnitProperty_StreamFormat, formatChanged, NULL);
    AudioUnitAddPropertyListener(unit, kAudioUnitProperty_StreamFormat, formatChanged, NULL);
    if (!readFormat(unit)) return;
    // The sound held from before the output stopped would play first; the stream starts over instead.
    ASMSpotiDSPEngine *engine = atomic_load(&asm_spotipw_engine);
    if (engine) ASMSpotiDSPEngineRestart(engine);
    OSStatus status = AudioUnitAddRenderNotify(unit, rendered, NULL);
    if (status != noErr) ASMSpotiLog(@"jamesdsp: the render notify could not be added (%d)", (int)status);
}

static OSStatus (*asm_spotipw_startOutput)(AudioUnit unit);

static OSStatus startOutput(AudioUnit unit) {
    if (isRemoteIO(unit)) listenTo(unit);
    return asm_spotipw_startOutput(unit);
}

#pragma mark - errors

// An effect's name in the log, by its switch key.
static NSString *effectName(NSString *effect) {
    NSDictionary<NSString *, NSString *> *names = @{
        ASMSpotiKeyDSPCompander: @"compander", ASMSpotiKeyDSPBass: @"bass boost", ASMSpotiKeyDSPEqualizer: @"equalizer", ASMSpotiKeyDSPGraphicEq: @"graphic EQ",
        ASMSpotiKeyDSPConvolver: @"convolver", ASMSpotiKeyDSPDDC: @"DDC", ASMSpotiKeyDSPLiveprog: @"Liveprog", ASMSpotiKeyDSPReverb: @"reverb",
        ASMSpotiKeyDSPStereoWide: @"stereo widening", ASMSpotiKeyDSPCrossfeed: @"crossfeed", ASMSpotiKeyDSPTube: @"analog modelling",
    };
    return names[effect] ?: effect;
}

static void setError(NSString *effect, NSString *message) {
    os_unfair_lock_lock(&asm_spotipw_errorLock);
    if (!asm_spotipw_errors) asm_spotipw_errors = [NSMutableDictionary dictionary];
    asm_spotipw_errors[effect] = message;
    os_unfair_lock_unlock(&asm_spotipw_errorLock);
    if (message) ASMSpotiLog(@"jamesdsp: %@ did not take: %@", effectName(effect), message);
}

NSString *ASMSpotiDSPError(NSString *switchKey) {
    if (!switchKey) return nil;
    os_unfair_lock_lock(&asm_spotipw_errorLock);
    NSString *message = asm_spotipw_errors[switchKey];
    os_unfair_lock_unlock(&asm_spotipw_errorLock);
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
    NSInteger index = (NSInteger)ASMSpotiDSPNumber(key);
    return index >= 0 && index < (NSInteger)names.count ? names[index] : @(index).stringValue;
}

// A file effect's file, from its library by name: its path, nil and an error when there is none to read.
static NSString *libraryFile(ASMSpotiDSPFileKind kind, NSString *nameKey, NSString *effect, BOOL on) {
    NSString *name = ASMSpotiDSPString(nameKey);
    if (!on) return nil;
    if (!name.length) {
        setError(effect, @"No file is chosen");
        return nil;
    }
    NSString *path = [ASMSpotiDSPLibraryDirectory(kind) stringByAppendingPathComponent:name.lastPathComponent];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        setError(effect, [NSString stringWithFormat:@"%@ is not in the library any more", name]);
        return nil;
    }
    return path;
}

// A text file with a NUL after it, for libjamesdsp's parsers.
static NSData *textFile(NSString *path) {
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    [data appendBytes:"" length:1];
    return data;
}

static void applyOutput(ASMSpotiDSPEngine *engine) {
    double gain = ASMSpotiDSPNumber(ASMSpotiKeyDSPPostGain), threshold = ASMSpotiDSPNumber(ASMSpotiKeyDSPLimiterThreshold), release = ASMSpotiDSPNumber(ASMSpotiKeyDSPLimiterRelease);
    ASMSpotiDSPEngineSetOutput(engine, gain, threshold, release);
    // Set again on every start of Spotify's output; logged when it changed.
    static NSString *logged;
    NSString *text = [NSString stringWithFormat:@"jamesdsp: output gain %+.1f dB, limiter at %.1f dB releasing in %.1f ms", gain, threshold, release];
    if (![text isEqualToString:logged]) ASMSpotiLog(@"%@", text);
    logged = text;
}

static void applyEffect(ASMSpotiDSPEngine *engine, NSString *effect) {
    BOOL on = ASMSpotiDSPSwitch(effect);
    char error[300] = "";
    BOOL ok = YES;
    NSString *what = @"";
    if ([effect isEqualToString:ASMSpotiKeyDSPCompander]) {
        NSArray<NSNumber *> *gains = ASMSpotiDSPGains(ASMSpotiKeyDSPCompanderGains);
        double values[7];
        for (int i = 0; i < 7; i++) values[i] = gains[i].doubleValue;
        double time = ASMSpotiDSPNumber(ASMSpotiKeyDSPCompanderTime);
        int granularity = (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPCompanderGranularity), transform = (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPCompanderTransform);
        ASMSpotiDSPEngineSetCompander(engine, on, time, granularity, transform, ASMSpotiDSPCompanderFrequencies, values);
        what = [NSString stringWithFormat:@"compander %@, %.2f s, granularity %d, %@, gains %@", onOff(on), time, granularity,
                choice(ASMSpotiDSPCompanderTransformNames(), ASMSpotiKeyDSPCompanderTransform), gainsText(gains)];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPBass]) {
        double gain = ASMSpotiDSPNumber(ASMSpotiKeyDSPBassGain);
        ASMSpotiDSPEngineSetBassBoost(engine, on, gain);
        what = [NSString stringWithFormat:@"bass boost %@, %.1f dB", onOff(on), gain];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPEqualizer]) {
        NSArray<NSNumber *> *gains = ASMSpotiDSPGains(ASMSpotiKeyDSPEqualizerGains);
        double values[15];
        for (int i = 0; i < 15; i++) values[i] = gains[i].doubleValue;
        int filter = (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPEqualizerFilter), interpolation = (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPEqualizerInterpolation);
        ASMSpotiDSPEngineSetEqualizer(engine, on, filter, interpolation, ASMSpotiDSPEqualizerFrequencies, values);
        what = [NSString stringWithFormat:@"equalizer %@, %@, %@, gains %@", onOff(on), choice(ASMSpotiDSPEqualizerFilterNames(), ASMSpotiKeyDSPEqualizerFilter),
                choice(ASMSpotiDSPEqualizerInterpolationNames(), ASMSpotiKeyDSPEqualizerInterpolation), gainsText(gains)];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPGraphicEq]) {
        NSString *nodes = ASMSpotiDSPString(ASMSpotiKeyDSPGraphicEqNodes);
        ok = ASMSpotiDSPEngineSetGraphicEq(engine, on, nodes.UTF8String, error, sizeof error);
        NSUInteger count = [nodes componentsSeparatedByString:@";"].count;
        what = [NSString stringWithFormat:@"graphic EQ %@, about %lu nodes", onOff(on), (unsigned long)(count > 1 ? count - 1 : count)];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPConvolver]) {
        NSString *path = libraryFile(ASMSpotiDSPFileImpulseResponse, ASMSpotiKeyDSPConvolverFile, effect, on);
        if (on && !path) {
            ASMSpotiDSPEngineSetConvolver(engine, false, NULL, 0, NULL, error, sizeof error);
            return;
        }
        ok = ASMSpotiDSPEngineSetConvolver(engine, on, path.fileSystemRepresentation, (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPConvolverMode),
                                     ASMSpotiDSPString(ASMSpotiKeyDSPConvolverWaveEdit).UTF8String, error, sizeof error);
        what = [NSString stringWithFormat:@"convolver %@%@%@", onOff(on), on ? @", " : @"", on ? [NSString stringWithFormat:@"%@ (%@)",
                path.lastPathComponent, choice(ASMSpotiDSPConvolverModeNames(), ASMSpotiKeyDSPConvolverMode)] : @""];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPDDC]) {
        NSString *path = libraryFile(ASMSpotiDSPFileDDC, ASMSpotiKeyDSPDDCFile, effect, on);
        if (on && !path) {
            ASMSpotiDSPEngineSetDDC(engine, false, NULL, error, sizeof error);
            return;
        }
        NSData *text = on ? textFile(path) : nil;
        ok = ASMSpotiDSPEngineSetDDC(engine, on && text, text.bytes, error, sizeof error);
        what = [NSString stringWithFormat:@"DDC %@%@%@", onOff(on), on ? @", " : @"", on ? path.lastPathComponent : @""];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPLiveprog]) {
        NSString *path = libraryFile(ASMSpotiDSPFileLiveprog, ASMSpotiKeyDSPLiveprogFile, effect, on);
        if (on && !path) {
            ASMSpotiDSPEngineSetLiveprog(engine, false, NULL, error, sizeof error);
            return;
        }
        NSData *script = on ? textFile(path) : nil;
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        ok = ASMSpotiDSPEngineSetLiveprog(engine, on && script, script.bytes, error, sizeof error);
        what = [NSString stringWithFormat:@"Liveprog %@%@%@", onOff(on), on ? @", " : @"", on ? [NSString stringWithFormat:@"%@ compiled in %.0f ms",
                path.lastPathComponent, (CFAbsoluteTimeGetCurrent() - start) * 1000] : @""];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPReverb]) {
        // The page's list leaves out some of libjamesdsp's presets, as RootlessJamesDSP's does.
        static const int presets[] = {0, 1, 2, 4, 5, 7, 8, 9, 11, 15, 16, 17, 18};
        NSInteger index = MAX(0, MIN((NSInteger)(sizeof presets / sizeof *presets) - 1, (NSInteger)ASMSpotiDSPNumber(ASMSpotiKeyDSPReverbPreset)));
        ASMSpotiDSPEngineSetReverb(engine, on, presets[index]);
        what = [NSString stringWithFormat:@"reverb %@, %@", onOff(on), choice(ASMSpotiDSPReverbPresetNames(), ASMSpotiKeyDSPReverbPreset)];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPStereoWide]) {
        double level = ASMSpotiDSPNumber(ASMSpotiKeyDSPStereoWideLevel);
        ASMSpotiDSPEngineSetStereoWide(engine, on, level);
        what = [NSString stringWithFormat:@"stereo widening %@, %.0f%%", onOff(on), level];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPCrossfeed]) {
        ASMSpotiDSPEngineSetCrossfeed(engine, on, (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPCrossfeedMode));
        what = [NSString stringWithFormat:@"crossfeed %@, %@", onOff(on), choice(ASMSpotiDSPCrossfeedModeNames(), ASMSpotiKeyDSPCrossfeedMode)];
    } else if ([effect isEqualToString:ASMSpotiKeyDSPTube]) {
        double drive = ASMSpotiDSPNumber(ASMSpotiKeyDSPTubeDrive);
        ASMSpotiDSPEngineSetTube(engine, on, drive);
        what = [NSString stringWithFormat:@"analog modelling %@, %.1f dB", onOff(on), drive];
    } else {
        return;
    }
    setError(effect, ok ? nil : @(error));
    if (ok) ASMSpotiLog(@"jamesdsp: %@", what);
}

#pragma mark - the queue: the engine

static dispatch_queue_t applyQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("asm.interface.spotipw.dsp", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    });
    return queue;
}

static void logPrinted(const char *text, void *context) {
    unsigned *count = context;
    for (NSString *line in [@(text) componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length && (*count)++ < kLogLinesPerSecond) ASMSpotiLog(@"jamesdsp: %@", trimmed);
    }
}

static void applyAll(ASMSpotiDSPEngine *engine) {
    applyOutput(engine);
    for (NSString *effect in effectSwitches()) applyEffect(engine, effect);
}

// Once a second while the engine lives: what libjamesdsp printed, an engine gone non-finite started over,
// and now and then a summary.
static void tend(void) {
    ASMSpotiDSPEngine *engine = atomic_load(&asm_spotipw_engine);
    unsigned count = 0;
    unsigned dropped = ASMSpotiDSPEngineReadLog(logPrinted, &count, 64);
    if (count > kLogLinesPerSecond || dropped) {
        ASMSpotiLog(@"jamesdsp: %u more lines of libjamesdsp's output left out", count - MIN(count, kLogLinesPerSecond) + dropped);
    }
    static uint64_t faults, blocks, skipped;
    static CFAbsoluteTime summarized, skipsLogged;
    ASMSpotiDSPEngineStats stats = ASMSpotiDSPEngineReadStats(engine, true);
    if (stats.faults != faults) {
        faults = stats.faults;
        ASMSpotiLog(@"jamesdsp: the output stopped being finite (%llu blocks silenced), the engine starts over", stats.faults);
        ASMSpotiDSPEngineReset(engine);
        applyAll(engine);
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    uint64_t skippedNow = atomic_load(&asm_spotipw_skipped);
    if (skippedNow != skipped && now - skipsLogged >= 10) {
        ASMSpotiLog(@"jamesdsp: %llu renders left alone, their buffers not laid out as the output's format says", skippedNow - skipped);
        skipped = skippedNow;
        skipsLogged = now;
    }
    if (stats.blocks != blocks && now - summarized >= kSummaryEvery) {
        summarized = now;
        ASMSpotiLog(@"jamesdsp: %llu blocks processed, %llu passed dry while settings changed, %.2f ms a block (%.1f%% of its time), %.2f ms at most",
              stats.blocks - blocks, stats.dry, stats.averageMS, stats.load * 100, stats.peakMS);
        blocks = stats.blocks;
    }
}

// The engine is read out once a second while it runs. With the switch off there is nothing in it to
// read, so the source is suspended rather than left ticking for the rest of the app's life: the engine
// is never freed, and a timer tied to its making would outlive every use of it. Only ever touched from
// applyMaster, which is to say on applyQueue().
static dispatch_source_t asm_spotipw_tendTimer;
static BOOL asm_spotipw_tending;

static void setTending(BOOL on) {
    if (!asm_spotipw_tendTimer || on == asm_spotipw_tending) return;
    asm_spotipw_tending = on;
    if (on) dispatch_resume(asm_spotipw_tendTimer);
    else dispatch_suspend(asm_spotipw_tendTimer);
}

// The switch and the output's format: the engine made or moved to the output's rate, everything set when
// it was, and the notify let in or kept out. Answers whether every effect was set.
static BOOL applyMaster(void) {
    if (!ASMSpotiDSPSwitch(ASMSpotiKeyDSP)) {
        setTending(NO);
        if (atomic_exchange(&asm_spotipw_running, false)) ASMSpotiLog(@"jamesdsp: off, Spotify's sound passes as it is");
        return NO;
    }
    double rate = loadDouble(&asm_spotipw_rateBits);
    if (atomic_load(&asm_spotipw_outputState) != ASMSpotiOutputPCM || rate <= 0) {
        ASMSpotiLog(@"jamesdsp: on, waiting for Spotify to start its output");
        return NO;
    }
    ASMSpotiDSPEngine *engine = atomic_load(&asm_spotipw_engine);
    BOOL everything = NO;
    if (!engine) {
        engine = ASMSpotiDSPEngineCreate(rate);
        if (!engine) {
            ASMSpotiLog(@"jamesdsp: the engine could not be made at %.0f Hz", rate);
            return NO;
        }
        ASMSpotiLog(@"jamesdsp: engine made at %.0f Hz, blocks of %d frames, so the sound is %.1f ms later", rate, kSGDSPEngineBlock,
              kSGDSPEngineBlock / rate * 1000);
        atomic_store(&asm_spotipw_engine, engine);
        // A source comes up suspended; setTending below is what starts it.
        asm_spotipw_tendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, applyQueue());
        dispatch_source_set_timer(asm_spotipw_tendTimer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 4);
        dispatch_source_set_event_handler(asm_spotipw_tendTimer, ^{
            tend();
        });
        everything = YES;
    } else if (ASMSpotiDSPEngineSampleRate(engine) != rate) {
        ASMSpotiDSPEngineSetSampleRate(engine, rate);
        ASMSpotiLog(@"jamesdsp: the engine follows the output to %.0f Hz", rate);
        everything = YES;
    }
    if (everything) applyAll(engine);
    else applyOutput(engine);
    if (!atomic_load(&asm_spotipw_running)) {
        ASMSpotiDSPEngineRestart(engine);
        atomic_store_explicit(&asm_spotipw_running, true, memory_order_release);
        ASMSpotiLog(@"jamesdsp: on");
    }
    setTending(YES);
    return everything;
}

static os_unfair_lock asm_spotipw_pendingLock = OS_UNFAIR_LOCK_INIT;
static NSMutableOrderedSet<NSString *> *asm_spotipw_pending;
static BOOL asm_spotipw_drainScheduled;

static void drain(void) {
    os_unfair_lock_lock(&asm_spotipw_pendingLock);
    NSArray<NSString *> *effects = asm_spotipw_pending.array;
    asm_spotipw_pending = nil;
    asm_spotipw_drainScheduled = NO;
    os_unfair_lock_unlock(&asm_spotipw_pendingLock);
    if ([effects containsObject:ASMSpotiKeyDSP] && applyMaster()) return;
    ASMSpotiDSPEngine *engine = atomic_load(&asm_spotipw_engine);
    // Without an engine nothing is set: it is set up with every effect when it is made.
    if (!engine) return;
    for (NSString *effect in effects) {
        if (![effect isEqualToString:ASMSpotiKeyDSP]) applyEffect(engine, effect);
    }
}

void ASMSpotiDSPApply(NSString *effect) {
    if (!effect) return;
    os_unfair_lock_lock(&asm_spotipw_pendingLock);
    if (!asm_spotipw_pending) asm_spotipw_pending = [NSMutableOrderedSet orderedSet];
    [asm_spotipw_pending addObject:effect];
    BOOL schedule = !asm_spotipw_drainScheduled;
    asm_spotipw_drainScheduled = YES;
    os_unfair_lock_unlock(&asm_spotipw_pendingLock);
    if (schedule) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kApplyAfter * NSEC_PER_SEC)), applyQueue(), ^{
        drain();
    });
}

#pragma mark - what the page shows

NSString *ASMSpotiDSPStatus(void) {
    if (!ASMSpotiDSPSwitch(ASMSpotiKeyDSP)) return @"Off";
    if (atomic_load(&asm_spotipw_outputState) == ASMSpotiOutputUnsupported) return @"Spotify's output is in a format the engine does not take";
    ASMSpotiDSPEngine *engine = atomic_load(&asm_spotipw_engine);
    if (!asm_spotipw_startOutput) return @"Unavailable: Spotify's output could not be reached";
    if (!engine || !atomic_load(&asm_spotipw_running)) return @"Waiting for Spotify to play";
    double rate = ASMSpotiDSPEngineSampleRate(engine);
    double load = ASMSpotiDSPEngineReadStats(engine, false).load;
    return [NSString stringWithFormat:@"Running at %@ kHz, %.1f%% load", [NSString stringWithFormat:@"%g", rate / 1000], load * 100];
}

void ASMSpotiDSPEqualizerResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *decibels) {
    if (count <= 0 || !frequencies || !decibels) return;
    double values[15] = {0};
    for (NSUInteger i = 0; i < 15 && i < gains.count; i++) values[i] = gains[i].doubleValue;
    ASMSpotiDSPEngineEqualizerCurve((int)ASMSpotiDSPNumber(ASMSpotiKeyDSPEqualizerFilter), (int)ASMSpotiDSPNumber(ASMSpotiKeyDSPEqualizerInterpolation),
                              ASMSpotiDSPEqualizerFrequencies, values, (int)count, frequencies, decibels);
}

void ASMSpotiDSPCompanderResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *values) {
    if (count <= 0 || !frequencies || !values) return;
    double bands[7] = {0};
    for (NSUInteger i = 0; i < 7 && i < gains.count; i++) bands[i] = gains[i].doubleValue;
    ASMSpotiDSPEngineCompanderCurve(ASMSpotiDSPCompanderFrequencies, bands, (int)count, frequencies, values);
}

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiRebindImport("AudioOutputUnitStart", startOutput, (void **)&asm_spotipw_startOutput) || !asm_spotipw_startOutput) {
        asm_spotipw_startOutput = NULL;
        ASMSpotiLog(@"jamesdsp: Spotify does not import AudioOutputUnitStart, the effects cannot reach its sound");
        return;
    }
    ASMSpotiLog(@"jamesdsp: listening for Spotify's output unit (%@)", ASMSpotiDSPSwitch(ASMSpotiKeyDSP) ? @"on" : @"off");
}
