#import "ASMVitrineDSPEffects.h"
#import <stdlib.h>
#import <string.h>
#import "bs2b.h"

// libbs2b's three levels, lightest first: Jan Meier's, Chu Moy's, and its own default.
static const uint32_t kLevels[ASMVitrineDSPCrossfeedPresetCount] = {BS2B_JMEIER_CLEVEL, BS2B_CMOY_CLEVEL, BS2B_DEFAULT_CLEVEL};

struct ASMVitrineDSPCrossfeed {
    t_bs2bd bs2b;
    float interleaved[2 * kSGDSPEffectMaxFrames];
};

// Filled in place rather than with bs2b_open, which allocates.
ASMVitrineDSPCrossfeed *ASMVitrineDSPCrossfeedCreate(double rate, int preset) {
    ASMVitrineDSPCrossfeed *crossfeed = calloc(1, sizeof *crossfeed);
    if (!crossfeed) return NULL;
    crossfeed->bs2b.level = kLevels[preset < 0 ? 0 : preset >= ASMVitrineDSPCrossfeedPresetCount ? ASMVitrineDSPCrossfeedPresetCount - 1 : preset];
    bs2b_set_srate(&crossfeed->bs2b, (uint32_t)rate);
    return crossfeed;
}

void ASMVitrineDSPCrossfeedSet(ASMVitrineDSPCrossfeed *crossfeed, int preset) {
    bs2b_set_level(&crossfeed->bs2b, kLevels[preset < 0 ? 0 : preset >= ASMVitrineDSPCrossfeedPresetCount ? ASMVitrineDSPCrossfeedPresetCount - 1 : preset]);
}

void ASMVitrineDSPCrossfeedRun(void *state, float *left, float *right, uint32_t frames) {
    ASMVitrineDSPCrossfeed *crossfeed = state;
    for (uint32_t i = 0; i < frames; i++) {
        crossfeed->interleaved[2 * i] = left[i];
        crossfeed->interleaved[2 * i + 1] = right[i];
    }
    bs2b_cross_feed_f(&crossfeed->bs2b, crossfeed->interleaved, (int)frames);
    for (uint32_t i = 0; i < frames; i++) {
        left[i] = crossfeed->interleaved[2 * i];
        right[i] = crossfeed->interleaved[2 * i + 1];
    }
}
