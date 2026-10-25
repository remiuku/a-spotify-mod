#import "ASMVitrineDSPEffects.h"
#import <math.h>
#import <stdlib.h>
#import <string.h>

#pragma mark - bass boost

static const double kShelfFrequency = 100, kDetectorFrequency = 150, kKneeDB = -3;
enum { kBassStep = 32 };   // frames between the shelf's redesigns

struct ASMVitrineDSPBass {
    double rate, maxGain, gain;
    double level, levelAttack, levelRelease, gainAttack, gainRelease;
    ASMVitrineBiquad detector, shelf;
    ASMVitrineBiquadState detectorState, shelfState[2];
};

ASMVitrineDSPBass *ASMVitrineDSPBassCreate(double rate, double maxGainDB) {
    ASMVitrineDSPBass *bass = calloc(1, sizeof *bass);
    if (!bass) return NULL;
    bass->rate = rate;
    bass->detector = ASMVitrineBiquadLowPass(rate, kDetectorFrequency, M_SQRT1_2);
    bass->levelAttack = exp(-1 / (0.005 * rate));
    bass->levelRelease = exp(-1 / (0.2 * rate));
    bass->gainAttack = exp(-kBassStep / (0.01 * rate));
    bass->gainRelease = exp(-kBassStep / (0.3 * rate));
    ASMVitrineDSPBassSet(bass, maxGainDB);
    bass->gain = bass->maxGain;
    bass->shelf = ASMVitrineBiquadLowShelf(rate, kShelfFrequency, M_SQRT1_2, bass->gain);
    return bass;
}

void ASMVitrineDSPBassSet(ASMVitrineDSPBass *bass, double maxGainDB) {
    bass->maxGain = fmax(0, maxGainDB);
}

void ASMVitrineDSPBassRun(void *state, float *left, float *right, uint32_t frames) {
    ASMVitrineDSPBass *bass = state;
    for (uint32_t start = 0; start < frames; start += kBassStep) {
        uint32_t end = start + kBassStep < frames ? start + kBassStep : frames;
        for (uint32_t i = start; i < end; i++) {
            double low = fabs(ASMVitrineBiquadTick(&bass->detector, &bass->detectorState, 0.5 * (left[i] + right[i])));
            double coefficient = low > bass->level ? bass->levelAttack : bass->levelRelease;
            bass->level = low + (bass->level - low) * coefficient;
        }
        // As much lift as keeps the lows' peaks under the knee, and no more than asked for.
        double levelDB = 20 * log10(bass->level + 1e-9);
        double target = fmax(0, fmin(bass->maxGain, kKneeDB - levelDB));
        double coefficient = target < bass->gain ? bass->gainAttack : bass->gainRelease;
        double gain = target + (bass->gain - target) * coefficient;
        if (fabs(gain - bass->gain) > 0.005) {
            bass->gain = gain;
            bass->shelf = ASMVitrineBiquadLowShelf(bass->rate, kShelfFrequency, M_SQRT1_2, gain);
        }
        ASMVitrineBiquadRun(&bass->shelf, &bass->shelfState[0], 1, left + start, end - start);
        ASMVitrineBiquadRun(&bass->shelf, &bass->shelfState[1], 1, right + start, end - start);
    }
}

#pragma mark - the equalizer

struct ASMVitrineDSPEqualizer {
    ASMVitrineBiquad bands[15];
    ASMVitrineBiquadState states[2][15];
};

ASMVitrineDSPEqualizer *ASMVitrineDSPEqualizerCreate(const ASMVitrineBiquad bands[15]) {
    ASMVitrineDSPEqualizer *equalizer = calloc(1, sizeof *equalizer);
    if (equalizer) ASMVitrineDSPEqualizerSet(equalizer, bands);
    return equalizer;
}

void ASMVitrineDSPEqualizerSet(ASMVitrineDSPEqualizer *equalizer, const ASMVitrineBiquad bands[15]) {
    memcpy(equalizer->bands, bands, sizeof equalizer->bands);
}

void ASMVitrineDSPEqualizerRun(void *state, float *left, float *right, uint32_t frames) {
    ASMVitrineDSPEqualizer *equalizer = state;
    ASMVitrineBiquadRun(equalizer->bands, equalizer->states[0], 15, left, frames);
    ASMVitrineBiquadRun(equalizer->bands, equalizer->states[1], 15, right, frames);
}

#pragma mark - ViPER DDC

struct ASMVitrineDSPCascade {
    ASMVitrineBiquad *sections;
    ASMVitrineBiquadState *states[2];
    int count;
};

ASMVitrineDSPCascade *ASMVitrineDSPCascadeCreate(ASMVitrineBiquad *sections, int count) {
    ASMVitrineDSPCascade *cascade = calloc(1, sizeof *cascade);
    if (!cascade) {
        free(sections);
        return NULL;
    }
    cascade->sections = sections;
    cascade->count = count;
    cascade->states[0] = calloc(count ? count : 1, sizeof(ASMVitrineBiquadState));
    cascade->states[1] = calloc(count ? count : 1, sizeof(ASMVitrineBiquadState));
    if (!cascade->states[0] || !cascade->states[1]) {
        ASMVitrineDSPCascadeFree(cascade);
        return NULL;
    }
    return cascade;
}

void ASMVitrineDSPCascadeRun(void *state, float *left, float *right, uint32_t frames) {
    ASMVitrineDSPCascade *cascade = state;
    ASMVitrineBiquadRun(cascade->sections, cascade->states[0], cascade->count, left, frames);
    ASMVitrineBiquadRun(cascade->sections, cascade->states[1], cascade->count, right, frames);
}

void ASMVitrineDSPCascadeFree(void *state) {
    ASMVitrineDSPCascade *cascade = state;
    if (!cascade) return;
    free(cascade->sections);
    free(cascade->states[0]);
    free(cascade->states[1]);
    free(cascade);
}

#pragma mark - stereo widening

struct ASMVitrineDSPWide {
    double side;
    ASMVitrineBiquad highs;
    ASMVitrineBiquadState highsState;
};

ASMVitrineDSPWide *ASMVitrineDSPWideCreate(double rate, double levelPercent) {
    ASMVitrineDSPWide *wide = calloc(1, sizeof *wide);
    if (!wide) return NULL;
    wide->highs = ASMVitrineBiquadHighPass(rate, 150, M_SQRT1_2);
    ASMVitrineDSPWideSet(wide, levelPercent);
    return wide;
}

void ASMVitrineDSPWideSet(ASMVitrineDSPWide *wide, double levelPercent) {
    wide->side = fmax(0, levelPercent) / 50;
}

void ASMVitrineDSPWideRun(void *state, float *left, float *right, uint32_t frames) {
    ASMVitrineDSPWide *wide = state;
    double extra = wide->side - 1;
    for (uint32_t i = 0; i < frames; i++) {
        double mid = 0.5 * ((double)left[i] + right[i]), side = 0.5 * ((double)left[i] - right[i]);
        // Narrowing scales the whole side; widening adds to it over 150 Hz only, so the bass stays centered.
        double highs = ASMVitrineBiquadTick(&wide->highs, &wide->highsState, side);
        side = extra > 0 ? side + extra * highs : side * wide->side;
        left[i] = (float)(mid + side);
        right[i] = (float)(mid - side);
    }
}
