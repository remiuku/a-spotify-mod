// The Visualizer's spectrum (ASMVitrineRSpectrum.h): a ring of the last kSize samples, analyzed every kHop.
#import <Accelerate/Accelerate.h>
#import <math.h>
#import <stdatomic.h>
#import <string.h>
#import "ASMVitrineRSpectrum.h"

enum { kLog2Size = 12, kSize = 1 << kLog2Size, kHalf = kSize / 2, kHop = 1024 };
// The bands' edges: a kick's fundamental at the bottom, the air of cymbals at the top.
static const double kLowest = 50, kHighest = 14000;

// Main thread, once, before the render thread reads them.
static FFTSetup asm_vitrine_setup;
static float asm_vitrine_window[kSize];
static atomic_bool asm_vitrine_prepared;

// The render thread's own.
static float asm_vitrine_ring[kSize], asm_vitrine_windowed[kSize], asm_vitrine_real[kHalf], asm_vitrine_imag[kHalf], asm_vitrine_power[kHalf];
static uint32_t asm_vitrine_at, asm_vitrine_sinceLast, asm_vitrine_filled;
static double asm_vitrine_rate;
static uint32_t asm_vitrine_from[ASMVitrineRSpectrumBands], asm_vitrine_to[ASMVitrineRSpectrumBands];   // bins, the end not included

// Published.
static _Atomic(float) asm_vitrine_levels[ASMVitrineRSpectrumBands];
static _Atomic(uint64_t) asm_vitrine_generation;

void ASMVitrineRSpectrumPrepare(void) {
    if (atomic_load(&asm_vitrine_prepared)) return;
    asm_vitrine_setup = vDSP_create_fftsetup(kLog2Size, kFFTRadix2);
    vDSP_hann_window(asm_vitrine_window, kSize, vDSP_HANN_DENORM);
    for (int band = 0; band < ASMVitrineRSpectrumBands; band++) atomic_store(&asm_vitrine_levels[band], ASMVitrineRSpectrumFloor);
    atomic_store_explicit(&asm_vitrine_prepared, true, memory_order_release);
}

// A band takes the bins whose middles are in it, and at least one, so the low bands, narrower than a bin, still
// read something; two of them can read the same bin.
static void setRate(double rate) {
    asm_vitrine_rate = rate;
    asm_vitrine_at = asm_vitrine_sinceLast = asm_vitrine_filled = 0;
    memset(asm_vitrine_ring, 0, sizeof asm_vitrine_ring);
    double binHz = rate / kSize, ratio = pow(kHighest / kLowest, 1.0 / ASMVitrineRSpectrumBands);
    for (int band = 0; band < ASMVitrineRSpectrumBands; band++) {
        double low = kLowest * pow(ratio, band), high = low * ratio;
        uint32_t from = (uint32_t)fmax(1, ceil(low / binHz)), to = (uint32_t)fmin(kHalf, ceil(high / binHz));
        if (from >= kHalf) from = kHalf - 1;
        asm_vitrine_from[band] = from;
        asm_vitrine_to[band] = to > from ? to : from + 1;
    }
}

// The power over a band, summed, as a full scale sine's: a Hann window keeps 3/8 of a sine's power over its
// bins, and vDSP's real FFT gives twice the DFT, so a sine of amplitude A sums to 3/8 * kSize^2 * A^2 here.
static void analyse(void) {
    // The ring from its oldest sample, windowed.
    uint32_t tail = kSize - asm_vitrine_at;
    vDSP_vmul(asm_vitrine_ring + asm_vitrine_at, 1, asm_vitrine_window, 1, asm_vitrine_windowed, 1, tail);
    vDSP_vmul(asm_vitrine_ring, 1, asm_vitrine_window + tail, 1, asm_vitrine_windowed + tail, 1, asm_vitrine_at);
    DSPSplitComplex split = {asm_vitrine_real, asm_vitrine_imag};
    vDSP_ctoz((const DSPComplex *)asm_vitrine_windowed, 2, &split, 1, kHalf);
    vDSP_fft_zrip(asm_vitrine_setup, &split, 1, kLog2Size, kFFTDirection_Forward);
    // The first bin's imaginary part is the Nyquist bin's real one, which no band reaches.
    asm_vitrine_imag[0] = 0;
    vDSP_zvmags(&split, 1, asm_vitrine_power, 1, kHalf);
    const float scale = 1.0f / (0.375f * (float)kSize * (float)kSize);
    for (int band = 0; band < ASMVitrineRSpectrumBands; band++) {
        float sum = 0;
        vDSP_sve(asm_vitrine_power + asm_vitrine_from[band], 1, &sum, asm_vitrine_to[band] - asm_vitrine_from[band]);
        float level = sum > 0 ? 10 * log10f(sum * scale) : ASMVitrineRSpectrumFloor;
        atomic_store_explicit(&asm_vitrine_levels[band], fmaxf(ASMVitrineRSpectrumFloor, level), memory_order_relaxed);
    }
    atomic_fetch_add_explicit(&asm_vitrine_generation, 1, memory_order_release);
}

void ASMVitrineRSpectrumFeed(const float *samples, uint32_t count, double sampleRate) {
    if (!samples || sampleRate <= 0 || !atomic_load_explicit(&asm_vitrine_prepared, memory_order_acquire)) return;
    if (sampleRate != asm_vitrine_rate) setRate(sampleRate);
    while (count) {
        uint32_t run = count;
        if (run > kSize - asm_vitrine_at) run = kSize - asm_vitrine_at;
        if (run > kHop - asm_vitrine_sinceLast) run = kHop - asm_vitrine_sinceLast;
        memcpy(asm_vitrine_ring + asm_vitrine_at, samples, run * sizeof(float));
        samples += run;
        count -= run;
        asm_vitrine_at = (asm_vitrine_at + run) & (kSize - 1);
        asm_vitrine_sinceLast += run;
        if (asm_vitrine_filled < kSize) asm_vitrine_filled += run;
        if (asm_vitrine_sinceLast == kHop) {
            asm_vitrine_sinceLast = 0;
            // Not before the ring is full once: a window half of zeros would read a step in the sound.
            if (asm_vitrine_filled >= kSize) analyse();
        }
    }
}

uint64_t ASMVitrineRSpectrumRead(float levels[ASMVitrineRSpectrumBands]) {
    uint64_t generation = atomic_load_explicit(&asm_vitrine_generation, memory_order_acquire);
    for (int band = 0; band < ASMVitrineRSpectrumBands; band++) {
        levels[band] = atomic_load_explicit(&asm_vitrine_levels[band], memory_order_relaxed);
    }
    return generation;
}
