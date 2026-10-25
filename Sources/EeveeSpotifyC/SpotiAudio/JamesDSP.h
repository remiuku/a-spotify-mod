// Adapted from spoti.pw v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a. GPL-3.0.
// See THIRD_PARTY_SPOTI_PW.md for authors, origins and local changes.
// JamesDSP on Spotify's sound: the effects engine of JamesDSP Manager, RootlessJamesDSP and JamesDSP for
// Linux (libjamesdsp, vendor/libjamesdsp), run on every buffer Spotify's output unit finishes, before the
// speaker. Either look: it draws nothing on Spotify's screens. Mod Settings > Audio effects is its page.
//
// What it offers is RootlessJamesDSP's list: output gain and limiter, dynamic range compressor, dynamic bass
// boost, the 15 band multimodal equalizer, the arbitrary response (graphic) equalizer, the convolver
// (impulse responses), ViPER DDC, Liveprog (EEL scripts), reverb, stereo widening, crossfeed and analog
// modelling. Each effect has a switch and its own values, kept under its own keys.
//
// Unlike the mod's other switches these apply as they change, not at launch: every setter below stores the
// value and hands the effect it belongs to to the engine, which re-reads that effect's keys off the main
// thread. The engine is made the first time Spotify starts its output with the master switch on.
//
// Threading: everything here is main thread, except SGDSPStatus and SGDSPError, which any thread may call.
#import <Foundation/Foundation.h>

#pragma mark - keys

// The master switch, off until asked for. Off, Spotify's sound is left exactly as it was.
#define SGKeyDSP                        @"asm.dsp"

// Output control, always applied while the master switch is on.
#define SGKeyDSPPostGain                @"asm.dsp.postGain"            // dB
#define SGKeyDSPLimiterThreshold        @"asm.dsp.limiterThreshold"    // dB
#define SGKeyDSPLimiterRelease          @"asm.dsp.limiterRelease"      // ms

#define SGKeyDSPCompander               @"asm.dsp.compander"
#define SGKeyDSPCompanderTime           @"asm.dsp.compander.time"      // s, the time constant
#define SGKeyDSPCompanderGranularity    @"asm.dsp.compander.granularity"
#define SGKeyDSPCompanderTransform      @"asm.dsp.compander.transform" // SGDSPCompanderTransformNames index
// Seven gains, "g;g;g;g;g;g;g", at SGDSPCompanderFrequencies, each within SGDSPCompanderGainLimit.
#define SGKeyDSPCompanderGains          @"asm.dsp.compander.gains"

#define SGKeyDSPBass                    @"asm.dsp.bass"
#define SGKeyDSPBassGain                @"asm.dsp.bass.gain"           // dB, the most it lifts

#define SGKeyDSPEqualizer               @"asm.dsp.eq"
#define SGKeyDSPEqualizerFilter         @"asm.dsp.eq.filter"           // SGDSPEqualizerFilterNames index
#define SGKeyDSPEqualizerInterpolation  @"asm.dsp.eq.interpolation"    // SGDSPEqualizerInterpolationNames index
// Fifteen gains in dB, "g;g;...;g", at SGDSPEqualizerFrequencies, each within SGDSPEqualizerGainLimit.
#define SGKeyDSPEqualizerGains          @"asm.dsp.eq.gains"

// The arbitrary response equalizer, in AutoEq's GraphicEQ format: "GraphicEQ: 20 -1.2; 21 -1.1; ...".
#define SGKeyDSPGraphicEq               @"asm.dsp.geq"
#define SGKeyDSPGraphicEqNodes          @"asm.dsp.geq.nodes"

// File effects name a file in their library (SGDSPLibraryFiles), by its name alone: the app's container
// moves on every reinstall, the name does not.
#define SGKeyDSPConvolver               @"asm.dsp.convolver"
#define SGKeyDSPConvolverFile           @"asm.dsp.convolver.file"
#define SGKeyDSPConvolverMode           @"asm.dsp.convolver.mode"      // SGDSPConvolverModeNames index
// "-80;-100;0;0;0;0", JamesDSP's advanced waveform editing of the impulse response; no page edits it yet.
#define SGKeyDSPConvolverWaveEdit       @"asm.dsp.convolver.waveEdit"

#define SGKeyDSPDDC                     @"asm.dsp.ddc"
#define SGKeyDSPDDCFile                 @"asm.dsp.ddc.file"

#define SGKeyDSPLiveprog                @"asm.dsp.liveprog"
#define SGKeyDSPLiveprogFile            @"asm.dsp.liveprog.file"

#define SGKeyDSPReverb                  @"asm.dsp.reverb"
#define SGKeyDSPReverbPreset            @"asm.dsp.reverb.preset"       // SGDSPReverbPresets index

#define SGKeyDSPStereoWide              @"asm.dsp.wide"
#define SGKeyDSPStereoWideLevel         @"asm.dsp.wide.level"          // percent

#define SGKeyDSPCrossfeed               @"asm.dsp.crossfeed"
#define SGKeyDSPCrossfeedMode           @"asm.dsp.crossfeed.mode"      // SGDSPCrossfeedModeNames index

#define SGKeyDSPTube                    @"asm.dsp.tube"
#define SGKeyDSPTubeDrive               @"asm.dsp.tube.drive"          // dB

#pragma mark - values

// A number setting's bounds, the value it has until set, and the step a slider moves it by. Ranges are
// RootlessJamesDSP's.
typedef struct {
    double min, max, fallback, step;
} SGDSPRange;

SGDSPRange SGDSPRangeFor(NSString *key);

// Switches, numbers (clamped to their range) and strings. Setting one applies it.
BOOL SGDSPSwitch(NSString *key);
void SGDSPSetSwitch(NSString *key, BOOL on);
double SGDSPNumber(NSString *key);
void SGDSPSetNumber(NSString *key, double value);
NSString *SGDSPString(NSString *key);
void SGDSPSetString(NSString *key, NSString *value);

// The equalizer's and the compressor's gains as numbers (15 and 7 of them), from and to their keys.
NSArray<NSNumber *> *SGDSPGains(NSString *key);
void SGDSPSetGains(NSString *key, NSArray<NSNumber *> *gains);

// Every key above back to its value until set; the master switch stays as it is.
void SGDSPResetAll(void);

#pragma mark - the lists the choices pick from

extern const double SGDSPEqualizerFrequencies[15];     // Hz, 25 ... 16000
extern const double SGDSPEqualizerGainLimit;           // ±12 dB
extern const double SGDSPCompanderFrequencies[7];      // Hz, 95 ... 7500
extern const double SGDSPCompanderGainLimit;           // ±1.2

NSArray<NSString *> *SGDSPEqualizerFilterNames(void);
NSArray<NSString *> *SGDSPEqualizerInterpolationNames(void);
NSArray<NSString *> *SGDSPCompanderTransformNames(void);
NSArray<NSString *> *SGDSPConvolverModeNames(void);
NSArray<NSString *> *SGDSPCrossfeedModeNames(void);
NSArray<NSString *> *SGDSPReverbPresetNames(void);
// The equalizer presets of JamesDSP (Acoustic, Bass, ... Vocal Booster), names and their 15 gains.
NSArray<NSString *> *SGDSPEqualizerPresetNames(void);
NSArray<NSNumber *> *SGDSPEqualizerPreset(NSInteger index);

#pragma mark - file libraries

typedef NS_ENUM(NSInteger, SGDSPFileKind) {
    SGDSPFileImpulseResponse,   // the convolver's: .wav .flac .irs (a WAV by another name)
    SGDSPFileDDC,               // ViPER DDC's .vdc
    SGDSPFileLiveprog,          // Liveprog's .eel
};

// Documents/spoti.pw/JamesDSP/<Convolver|DDC|Liveprog>, made on first use and holding the files JamesDSP
// ships (Liveprog scripts, DDC presets) the first time it is made.
NSString *SGDSPLibraryDirectory(SGDSPFileKind kind);
NSArray<NSString *> *SGDSPLibraryFiles(SGDSPFileKind kind);   // names, sorted
NSArray<NSString *> *SGDSPFileExtensions(SGDSPFileKind kind); // lowercase, without the dot
// Copies a picked file into the library, replacing one of the same name; answers its name, nil and an
// error when it is not a file of that kind.
NSString *SGDSPImportFile(SGDSPFileKind kind, NSURL *url, NSError **error);
BOOL SGDSPDeleteFile(SGDSPFileKind kind, NSString *name);

#pragma mark - what the engine is doing

// One line for the page: off, waiting for Spotify to play, or running (sample rate, load).
NSString *SGDSPStatus(void);
// Why an effect's last change did not take, nil when it did: a script that did not compile (with the
// line), an impulse response that could not be read, a DDC file that was not one. Keyed by the effect's
// switch key (SGKeyDSPLiveprog, SGKeyDSPConvolver, SGKeyDSPDDC, SGKeyDSPGraphicEq).
NSString *SGDSPError(NSString *switchKey);

// The equalizer's magnitude response for the stored filter and the given gains, for drawing the curve:
// `count` points log-spaced from 20 Hz to 20 kHz into `frequencies` and `decibels`.
void SGDSPEqualizerResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *decibels);
// The compressor's response curve for the given gains, the same way.
void SGDSPCompanderResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *values);
