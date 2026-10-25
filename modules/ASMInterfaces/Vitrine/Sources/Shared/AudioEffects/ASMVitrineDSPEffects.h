// The effects ASMVitrineDSPEngine chains (ASMVitrineDSPTone.m, ASMVitrineDSPDynamics.m, ASMVitrineDSPCrossfeed.m, ASMVitrineDSPReverb.m,
// ASMVitrineDSPLiveprog.m; the convolver is ASMVitrineDSPConvolver.h). Create, Set and Free are never the render thread's, and
// a Set changes a running state, so it is called under the engine's lock. Run never allocates, locks or logs.
#import <stdbool.h>
#import <stddef.h>
#import <stdint.h>
#import "ASMVitrineDSPFilters.h"

typedef void (*ASMVitrineDSPRun)(void *state, float *left, float *right, uint32_t frames);
typedef void (*ASMVitrineDSPFree)(void *state);

// Every Run takes up to this many frames.
enum { kSGDSPEffectMaxFrames = 1024 };

// A low shelf at 100 Hz lifting by up to `maxGainDB`, less while the lows are loud: never past -3 dBFS
// where the headroom allows none.
typedef struct ASMVitrineDSPBass ASMVitrineDSPBass;
ASMVitrineDSPBass *ASMVitrineDSPBassCreate(double rate, double maxGainDB);
void ASMVitrineDSPBassSet(ASMVitrineDSPBass *bass, double maxGainDB);
void ASMVitrineDSPBassRun(void *bass, float *left, float *right, uint32_t frames);

typedef struct ASMVitrineDSPEqualizer ASMVitrineDSPEqualizer;
// `bands` from ASMVitrineDSPDesignEqualizer.
ASMVitrineDSPEqualizer *ASMVitrineDSPEqualizerCreate(const ASMVitrineBiquad bands[15]);
void ASMVitrineDSPEqualizerSet(ASMVitrineDSPEqualizer *equalizer, const ASMVitrineBiquad bands[15]);
void ASMVitrineDSPEqualizerRun(void *equalizer, float *left, float *right, uint32_t frames);

// A cascade of biquads on both channels (ViPER DDC's filters); takes `sections`, which Free frees.
typedef struct ASMVitrineDSPCascade ASMVitrineDSPCascade;
ASMVitrineDSPCascade *ASMVitrineDSPCascadeCreate(ASMVitrineBiquad *sections, int count);
void ASMVitrineDSPCascadeRun(void *cascade, float *left, float *right, uint32_t frames);
void ASMVitrineDSPCascadeFree(void *cascade);

// Mid and side, the side scaled by level / 50 (50 leaves it as it is); widening leaves the side's lows alone.
typedef struct ASMVitrineDSPWide ASMVitrineDSPWide;
ASMVitrineDSPWide *ASMVitrineDSPWideCreate(double rate, double levelPercent);
void ASMVitrineDSPWideSet(ASMVitrineDSPWide *wide, double levelPercent);
void ASMVitrineDSPWideRun(void *wide, float *left, float *right, uint32_t frames);

// Seven Linkwitz-Riley bands around `frequencies`, each band's loud and quiet moments pulled toward its own
// running level by gains[i] (1: 60% less dynamics) or pushed away from it (-1: 60% more), by 12 dB at most.
// `timeConstant` is the release; the attack a tenth of it, the running level ten times it.
typedef struct ASMVitrineDSPCompander ASMVitrineDSPCompander;
ASMVitrineDSPCompander *ASMVitrineDSPCompanderCreate(double rate, double timeConstant, const double frequencies[7], const double gains[7]);
void ASMVitrineDSPCompanderSet(ASMVitrineDSPCompander *compander, double timeConstant, const double gains[7]);
void ASMVitrineDSPCompanderRun(void *compander, float *left, float *right, uint32_t frames);

// An asymmetric soft clip at twice the rate: even harmonics first, the level kept for quiet sounds.
typedef struct ASMVitrineDSPTube ASMVitrineDSPTube;
ASMVitrineDSPTube *ASMVitrineDSPTubeCreate(double rate, double driveDB);
void ASMVitrineDSPTubeSet(ASMVitrineDSPTube *tube, double driveDB);
void ASMVitrineDSPTubeRun(void *tube, float *left, float *right, uint32_t frames);

// preset: ASMVitrineDSPCrossfeedPresetCount of them, lightest first.
enum { ASMVitrineDSPCrossfeedPresetCount = 3 };
typedef struct ASMVitrineDSPCrossfeed ASMVitrineDSPCrossfeed;
ASMVitrineDSPCrossfeed *ASMVitrineDSPCrossfeedCreate(double rate, int preset);
void ASMVitrineDSPCrossfeedSet(ASMVitrineDSPCrossfeed *crossfeed, int preset);
void ASMVitrineDSPCrossfeedRun(void *crossfeed, float *left, float *right, uint32_t frames);

// preset: an index of ASMVitrineDSPReverbPresetCount. NULL when the unit could not be made.
enum { ASMVitrineDSPReverbPresetCount = 9 };
typedef struct ASMVitrineDSPReverb ASMVitrineDSPReverb;
// `amount` scales the room's wet mix: 50 is the room's own, 100 twice it.
ASMVitrineDSPReverb *ASMVitrineDSPReverbCreate(double rate, int preset, float amount);
void ASMVitrineDSPReverbSet(ASMVitrineDSPReverb *reverb, int preset, float amount);
void ASMVitrineDSPReverbRun(void *reverb, float *left, float *right, uint32_t frames);
void ASMVitrineDSPReverbFree(void *reverb);
// Wet only, for a send: what comes out is the room alone, none of what went in.
void ASMVitrineDSPReverbSetSend(ASMVitrineDSPReverb *reverb, int preset);
// Empties the room's tail. Off the render thread, or on it between two runs.
void ASMVitrineDSPReverbReset(ASMVitrineDSPReverb *reverb);

// A script in JSFX's shape: a desc: line and sliderN: defaults, then @init, @slider, @block and @sample
// sections, spl0 and spl1 the samples, srate the rate. NULL and why, with the file's line, when it does
// not compile.
typedef struct ASMVitrineDSPLiveprog ASMVitrineDSPLiveprog;
ASMVitrineDSPLiveprog *ASMVitrineDSPLiveprogCreate(const char *script, double rate, char *error, size_t errorSize);
void ASMVitrineDSPLiveprogRun(void *liveprog, float *left, float *right, uint32_t frames);
void ASMVitrineDSPLiveprogFree(void *liveprog);
