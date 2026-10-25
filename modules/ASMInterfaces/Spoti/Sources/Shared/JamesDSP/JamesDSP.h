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
// Threading: everything here is main thread, except ASMSpotiDSPStatus and ASMSpotiDSPError, which any thread may call.
#import <Foundation/Foundation.h>

#pragma mark - keys

// The master switch, off until asked for. Off, Spotify's sound is left exactly as it was.
#define ASMSpotiKeyDSP                        @"asm.interface.spotipw.dsp"

// Output control, always applied while the master switch is on.
#define ASMSpotiKeyDSPPostGain                @"asm.interface.spotipw.dsp.postGain"            // dB
#define ASMSpotiKeyDSPLimiterThreshold        @"asm.interface.spotipw.dsp.limiterThreshold"    // dB
#define ASMSpotiKeyDSPLimiterRelease          @"asm.interface.spotipw.dsp.limiterRelease"      // ms

#define ASMSpotiKeyDSPCompander               @"asm.interface.spotipw.dsp.compander"
#define ASMSpotiKeyDSPCompanderTime           @"asm.interface.spotipw.dsp.compander.time"      // s, the time constant
#define ASMSpotiKeyDSPCompanderGranularity    @"asm.interface.spotipw.dsp.compander.granularity"
#define ASMSpotiKeyDSPCompanderTransform      @"asm.interface.spotipw.dsp.compander.transform" // ASMSpotiDSPCompanderTransformNames index
// Seven gains, "g;g;g;g;g;g;g", at ASMSpotiDSPCompanderFrequencies, each within ASMSpotiDSPCompanderGainLimit.
#define ASMSpotiKeyDSPCompanderGains          @"asm.interface.spotipw.dsp.compander.gains"

#define ASMSpotiKeyDSPBass                    @"asm.interface.spotipw.dsp.bass"
#define ASMSpotiKeyDSPBassGain                @"asm.interface.spotipw.dsp.bass.gain"           // dB, the most it lifts

#define ASMSpotiKeyDSPEqualizer               @"asm.interface.spotipw.dsp.eq"
#define ASMSpotiKeyDSPEqualizerFilter         @"asm.interface.spotipw.dsp.eq.filter"           // ASMSpotiDSPEqualizerFilterNames index
#define ASMSpotiKeyDSPEqualizerInterpolation  @"asm.interface.spotipw.dsp.eq.interpolation"    // ASMSpotiDSPEqualizerInterpolationNames index
// Fifteen gains in dB, "g;g;...;g", at ASMSpotiDSPEqualizerFrequencies, each within ASMSpotiDSPEqualizerGainLimit.
#define ASMSpotiKeyDSPEqualizerGains          @"asm.interface.spotipw.dsp.eq.gains"

// The arbitrary response equalizer, in AutoEq's GraphicEQ format: "GraphicEQ: 20 -1.2; 21 -1.1; ...".
#define ASMSpotiKeyDSPGraphicEq               @"asm.interface.spotipw.dsp.geq"
#define ASMSpotiKeyDSPGraphicEqNodes          @"asm.interface.spotipw.dsp.geq.nodes"

// File effects name a file in their library (ASMSpotiDSPLibraryFiles), by its name alone: the app's container
// moves on every reinstall, the name does not.
#define ASMSpotiKeyDSPConvolver               @"asm.interface.spotipw.dsp.convolver"
#define ASMSpotiKeyDSPConvolverFile           @"asm.interface.spotipw.dsp.convolver.file"
#define ASMSpotiKeyDSPConvolverMode           @"asm.interface.spotipw.dsp.convolver.mode"      // ASMSpotiDSPConvolverModeNames index
// "-80;-100;0;0;0;0", JamesDSP's advanced waveform editing of the impulse response; no page edits it yet.
#define ASMSpotiKeyDSPConvolverWaveEdit       @"asm.interface.spotipw.dsp.convolver.waveEdit"

#define ASMSpotiKeyDSPDDC                     @"asm.interface.spotipw.dsp.ddc"
#define ASMSpotiKeyDSPDDCFile                 @"asm.interface.spotipw.dsp.ddc.file"

#define ASMSpotiKeyDSPLiveprog                @"asm.interface.spotipw.dsp.liveprog"
#define ASMSpotiKeyDSPLiveprogFile            @"asm.interface.spotipw.dsp.liveprog.file"

#define ASMSpotiKeyDSPReverb                  @"asm.interface.spotipw.dsp.reverb"
#define ASMSpotiKeyDSPReverbPreset            @"asm.interface.spotipw.dsp.reverb.preset"       // ASMSpotiDSPReverbPresets index

#define ASMSpotiKeyDSPStereoWide              @"asm.interface.spotipw.dsp.wide"
#define ASMSpotiKeyDSPStereoWideLevel         @"asm.interface.spotipw.dsp.wide.level"          // percent

#define ASMSpotiKeyDSPCrossfeed               @"asm.interface.spotipw.dsp.crossfeed"
#define ASMSpotiKeyDSPCrossfeedMode           @"asm.interface.spotipw.dsp.crossfeed.mode"      // ASMSpotiDSPCrossfeedModeNames index

#define ASMSpotiKeyDSPTube                    @"asm.interface.spotipw.dsp.tube"
#define ASMSpotiKeyDSPTubeDrive               @"asm.interface.spotipw.dsp.tube.drive"          // dB

#pragma mark - values

// A number setting's bounds, the value it has until set, and the step a slider moves it by. Ranges are
// RootlessJamesDSP's.
typedef struct {
    double min, max, fallback, step;
} ASMSpotiDSPRange;

ASMSpotiDSPRange ASMSpotiDSPRangeFor(NSString *key);

// Switches, numbers (clamped to their range) and strings. Setting one applies it.
BOOL ASMSpotiDSPSwitch(NSString *key);
void ASMSpotiDSPSetSwitch(NSString *key, BOOL on);
double ASMSpotiDSPNumber(NSString *key);
void ASMSpotiDSPSetNumber(NSString *key, double value);
NSString *ASMSpotiDSPString(NSString *key);
void ASMSpotiDSPSetString(NSString *key, NSString *value);

// The equalizer's and the compressor's gains as numbers (15 and 7 of them), from and to their keys.
NSArray<NSNumber *> *ASMSpotiDSPGains(NSString *key);
void ASMSpotiDSPSetGains(NSString *key, NSArray<NSNumber *> *gains);

// Every key above back to its value until set; the master switch stays as it is.
void ASMSpotiDSPResetAll(void);

#pragma mark - the lists the choices pick from

extern const double ASMSpotiDSPEqualizerFrequencies[15];     // Hz, 25 ... 16000
extern const double ASMSpotiDSPEqualizerGainLimit;           // ±12 dB
extern const double ASMSpotiDSPCompanderFrequencies[7];      // Hz, 95 ... 7500
extern const double ASMSpotiDSPCompanderGainLimit;           // ±1.2

NSArray<NSString *> *ASMSpotiDSPEqualizerFilterNames(void);
NSArray<NSString *> *ASMSpotiDSPEqualizerInterpolationNames(void);
NSArray<NSString *> *ASMSpotiDSPCompanderTransformNames(void);
NSArray<NSString *> *ASMSpotiDSPConvolverModeNames(void);
NSArray<NSString *> *ASMSpotiDSPCrossfeedModeNames(void);
NSArray<NSString *> *ASMSpotiDSPReverbPresetNames(void);
// The equalizer presets of JamesDSP (Acoustic, Bass, ... Vocal Booster), names and their 15 gains.
NSArray<NSString *> *ASMSpotiDSPEqualizerPresetNames(void);
NSArray<NSNumber *> *ASMSpotiDSPEqualizerPreset(NSInteger index);

#pragma mark - file libraries

typedef NS_ENUM(NSInteger, ASMSpotiDSPFileKind) {
    ASMSpotiDSPFileImpulseResponse,   // the convolver's: .wav .flac .irs (a WAV by another name)
    ASMSpotiDSPFileDDC,               // ViPER DDC's .vdc
    ASMSpotiDSPFileLiveprog,          // Liveprog's .eel
};

// Documents/spoti.pw/JamesDSP/<Convolver|DDC|Liveprog>, made on first use and holding the files JamesDSP
// ships (Liveprog scripts, DDC presets) the first time it is made.
NSString *ASMSpotiDSPLibraryDirectory(ASMSpotiDSPFileKind kind);
NSArray<NSString *> *ASMSpotiDSPLibraryFiles(ASMSpotiDSPFileKind kind);   // names, sorted
NSArray<NSString *> *ASMSpotiDSPFileExtensions(ASMSpotiDSPFileKind kind); // lowercase, without the dot
// Copies a picked file into the library, replacing one of the same name; answers its name, nil and an
// error when it is not a file of that kind.
NSString *ASMSpotiDSPImportFile(ASMSpotiDSPFileKind kind, NSURL *url, NSError **error);
BOOL ASMSpotiDSPDeleteFile(ASMSpotiDSPFileKind kind, NSString *name);

#pragma mark - what the engine is doing

// One line for the page: off, waiting for Spotify to play, or running (sample rate, load).
NSString *ASMSpotiDSPStatus(void);
// Why an effect's last change did not take, nil when it did: a script that did not compile (with the
// line), an impulse response that could not be read, a DDC file that was not one. Keyed by the effect's
// switch key (ASMSpotiKeyDSPLiveprog, ASMSpotiKeyDSPConvolver, ASMSpotiKeyDSPDDC, ASMSpotiKeyDSPGraphicEq).
NSString *ASMSpotiDSPError(NSString *switchKey);

// The equalizer's magnitude response for the stored filter and the given gains, for drawing the curve:
// `count` points log-spaced from 20 Hz to 20 kHz into `frequencies` and `decibels`.
void ASMSpotiDSPEqualizerResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *decibels);
// The compressor's response curve for the given gains, the same way.
void ASMSpotiDSPCompanderResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *values);
