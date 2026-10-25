// Audio effects on Spotify's sound: the mod's own engine (ASMVitrineDSPEngine), run on every buffer Spotify's output
// unit finishes, before the speaker. Either look: it draws nothing on Spotify's screens. Mod Settings >
// Audio effects is its page.
//
// What it offers: output gain and limiter, a multiband compander, dynamic bass boost, a 15 band equalizer,
// the Graphic EQ (any curve, as AutoEq writes them), the convolver (impulse responses), ViPER DDC files,
// Liveprog (EEL2 scripts), reverb, stereo widening, crossfeed and analog modeling. Each effect has a switch
// and its own values, kept under its own keys.
//
// Unlike the mod's other switches these apply as they change, not at launch: every setter below stores the
// value and hands the effect it belongs to to the engine, which re-reads that effect's keys off the main
// thread. The engine is made the first time Spotify starts its output with the master switch on.
//
// Threading: everything here is main thread, except ASMVitrineDSPStatus, ASMVitrineDSPError and ASMVitrineAudioSetOutputReader, which any
// thread may call.
#import <Foundation/Foundation.h>

#pragma mark - keys

// The master switch, off until asked for. Off, Spotify's sound is left exactly as it was.
#define ASMVitrineKeyDSP                        @"asm.interface.vitrine.dsp"

// Output control, applied while the master switch is on.
#define ASMVitrineKeyDSPPostGain                @"asm.interface.vitrine.dsp.postGain"            // dB
#define ASMVitrineKeyDSPLimiterThreshold        @"asm.interface.vitrine.dsp.limiterThreshold"    // dB
#define ASMVitrineKeyDSPLimiterRelease          @"asm.interface.vitrine.dsp.limiterRelease"      // ms

#define ASMVitrineKeyDSPCompander               @"asm.interface.vitrine.dsp.compander"
#define ASMVitrineKeyDSPCompanderTime           @"asm.interface.vitrine.dsp.compander.time"      // s, the release
// Seven amounts, "a;a;a;a;a;a;a", one per band at ASMVitrineDSPCompanderFrequencies, each within ASMVitrineDSPCompanderGainLimit:
// over 0 evens the band's loud and quiet moments out, under 0 pulls them apart.
#define ASMVitrineKeyDSPCompanderGains          @"asm.interface.vitrine.dsp.compander.gains"

#define ASMVitrineKeyDSPBass                    @"asm.interface.vitrine.dsp.bass"
#define ASMVitrineKeyDSPBassGain                @"asm.interface.vitrine.dsp.bass.gain"           // dB, the most it lifts

#define ASMVitrineKeyDSPEqualizer               @"asm.interface.vitrine.dsp.eq"
// Fifteen gains in dB, "g;g;...;g", at ASMVitrineDSPEqualizerFrequencies, each within ASMVitrineDSPEqualizerGainLimit.
#define ASMVitrineKeyDSPEqualizerGains          @"asm.interface.vitrine.dsp.eq.gains"

// The Graphic EQ, in AutoEq's GraphicEQ format: "GraphicEQ: 20 -1.2; 21 -1.1; ...".
#define ASMVitrineKeyDSPGraphicEq               @"asm.interface.vitrine.dsp.geq"
#define ASMVitrineKeyDSPGraphicEqNodes          @"asm.interface.vitrine.dsp.geq.nodes"
// The AutoEq headphone the nodes came from, as its folder in AutoEq's results (ASMVitrineAutoEqHeadphone.path);
// empty once the text is edited by hand.
#define ASMVitrineKeyDSPGraphicEqHeadphone      @"asm.interface.vitrine.dsp.geq.headphone"

// File effects name a file in their library (ASMVitrineDSPLibraryFiles), by its name alone: the app's container
// moves on every reinstall, the name does not.
#define ASMVitrineKeyDSPConvolver               @"asm.interface.vitrine.dsp.convolver"
#define ASMVitrineKeyDSPConvolverFile           @"asm.interface.vitrine.dsp.convolver.file"
#define ASMVitrineKeyDSPConvolverMode           @"asm.interface.vitrine.dsp.convolver.mode"      // ASMVitrineDSPConvolverModeNames index

#define ASMVitrineKeyDSPDDC                     @"asm.interface.vitrine.dsp.ddc"
#define ASMVitrineKeyDSPDDCFile                 @"asm.interface.vitrine.dsp.ddc.file"

#define ASMVitrineKeyDSPLiveprog                @"asm.interface.vitrine.dsp.liveprog"
#define ASMVitrineKeyDSPLiveprogFile            @"asm.interface.vitrine.dsp.liveprog.file"

#define ASMVitrineKeyDSPReverb                  @"asm.interface.vitrine.dsp.reverb"
#define ASMVitrineKeyDSPReverbPreset            @"asm.interface.vitrine.dsp.reverb.preset"       // ASMVitrineDSPReverbPresetNames index
#define ASMVitrineKeyDSPReverbAmount            @"asm.interface.vitrine.dsp.reverb.amount"       // %, 50 is the room's own mix

#define ASMVitrineKeyDSPStereoWide              @"asm.interface.vitrine.dsp.wide"
#define ASMVitrineKeyDSPStereoWideLevel         @"asm.interface.vitrine.dsp.wide.level"          // percent, 50 leaving the width as it is

#define ASMVitrineKeyDSPCrossfeed               @"asm.interface.vitrine.dsp.crossfeed"
#define ASMVitrineKeyDSPCrossfeedMode           @"asm.interface.vitrine.dsp.crossfeed.mode"      // ASMVitrineDSPCrossfeedModeNames index

#define ASMVitrineKeyDSPTube                    @"asm.interface.vitrine.dsp.tube"
#define ASMVitrineKeyDSPTubeDrive               @"asm.interface.vitrine.dsp.tube.drive"          // dB

#pragma mark - values

// A number setting's bounds, the value it has until set, and the step a slider moves it by.
typedef struct {
    double min, max, fallback, step;
} ASMVitrineDSPRange;

ASMVitrineDSPRange ASMVitrineDSPRangeFor(NSString *key);

// Switches, numbers (clamped to their range) and strings. Setting one applies it.
BOOL ASMVitrineDSPSwitch(NSString *key);
void ASMVitrineDSPSetSwitch(NSString *key, BOOL on);
double ASMVitrineDSPNumber(NSString *key);
void ASMVitrineDSPSetNumber(NSString *key, double value);
NSString *ASMVitrineDSPString(NSString *key);
void ASMVitrineDSPSetString(NSString *key, NSString *value);

// The equalizer's and the compander's gains as numbers (15 and 7 of them), from and to their keys.
NSArray<NSNumber *> *ASMVitrineDSPGains(NSString *key);
void ASMVitrineDSPSetGains(NSString *key, NSArray<NSNumber *> *gains);

// Every key above back to its value until set; the master switch stays as it is.
void ASMVitrineDSPResetAll(void);

#pragma mark - the lists the choices pick from

extern const double ASMVitrineDSPEqualizerFrequencies[15];     // Hz, 25 ... 16000
extern const double ASMVitrineDSPEqualizerGainLimit;           // ±12 dB
extern const double ASMVitrineDSPCompanderFrequencies[7];      // Hz, 95 ... 7500
extern const double ASMVitrineDSPCompanderGainLimit;           // ±1.2

NSArray<NSString *> *ASMVitrineDSPConvolverModeNames(void);
NSArray<NSString *> *ASMVitrineDSPCrossfeedModeNames(void);
NSArray<NSString *> *ASMVitrineDSPReverbPresetNames(void);
// The equalizer's presets, names and their 15 gains.
NSArray<NSString *> *ASMVitrineDSPEqualizerPresetNames(void);
NSArray<NSNumber *> *ASMVitrineDSPEqualizerPreset(NSInteger index);

#pragma mark - file libraries

typedef NS_ENUM(NSInteger, ASMVitrineDSPFileKind) {
    ASMVitrineDSPFileImpulseResponse,   // the convolver's: .wav .flac .irs (a WAV by another name)
    ASMVitrineDSPFileDDC,               // ViPER DDC's .vdc
    ASMVitrineDSPFileLiveprog,          // Liveprog's .eel
};

// Documents/Vitrine/Audio effects/<Convolver|DDC|Liveprog>, made on first use, empty until files are imported.
NSString *ASMVitrineDSPLibraryDirectory(ASMVitrineDSPFileKind kind);
NSArray<NSString *> *ASMVitrineDSPLibraryFiles(ASMVitrineDSPFileKind kind);   // names, sorted
NSArray<NSString *> *ASMVitrineDSPFileExtensions(ASMVitrineDSPFileKind kind); // lowercase, without the dot
// Copies a picked file into the library, replacing one of the same name; answers its name, nil and an
// error when it is not a file of that kind.
NSString *ASMVitrineDSPImportFile(ASMVitrineDSPFileKind kind, NSURL *url, NSError **error);
BOOL ASMVitrineDSPDeleteFile(ASMVitrineDSPFileKind kind, NSString *name);

#pragma mark - what the engine is doing

// One line for the page: off, waiting for Spotify to play, or running (sample rate, load).
NSString *ASMVitrineDSPStatus(void);
// Why an effect's last change did not take, nil when it did: a script that did not compile (with the
// line), an impulse response that could not be read, a DDC file that was not one. Keyed by the effect's
// switch key (ASMVitrineKeyDSPLiveprog, ASMVitrineKeyDSPConvolver, ASMVitrineKeyDSPDDC, ASMVitrineKeyDSPGraphicEq).
NSString *ASMVitrineDSPError(NSString *switchKey);

// The equalizer's magnitude response for the given gains, for drawing the curve: `count` points
// log-spaced from 20 Hz to 20 kHz into `frequencies` and `decibels`.
void ASMVitrineDSPEqualizerResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *decibels);
// The compander's amounts drawn as a smooth curve, the same way.
void ASMVitrineDSPCompanderResponse(NSArray<NSNumber *> *gains, NSInteger count, double *frequencies, double *values);

#pragma mark - the output's sound, read

// Called on the render thread with what Spotify's music output plays (ASMVitrinePlayerMusicOutput), after the effects
// (and Speed and pitch, and Sing): each buffer the notify sees, mixed to mono, as floats, in runs of up to 4096
// frames, at the output's rate; zeros for a buffer marked silent. It runs whether the master switch is on or off,
// but only once Spotify has started its output, and never when Shared/Player cannot reach Spotify's output. It must not allocate, lock, block or
// send an Objective-C message.
typedef void (*ASMVitrineAudioOutputReader)(const float *samples, uint32_t count, double sampleRate);
// One reader at a time; NULL takes it off. Any thread. A reader taken off can still be in a call that began
// before, so what it touches has to outlive it.
void ASMVitrineAudioSetOutputReader(ASMVitrineAudioOutputReader reader);
