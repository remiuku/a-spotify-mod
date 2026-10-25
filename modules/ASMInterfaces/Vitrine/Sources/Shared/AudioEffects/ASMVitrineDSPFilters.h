// The effects' filter math: biquads and their designs, the gain a design makes, ViPER DDC and GraphicEQ text
// read, and minimum phase responses made from a magnitude. ASMVitrineBiquadTick and ASMVitrineBiquadRun are the render
// thread's; the rest allocates.
#import <stdbool.h>
#import <stddef.h>
#import <stdint.h>

// y = b0 x + b1 x1 + b2 x2 - a1 y1 - a2 y2, run as transposed direct form II in double.
typedef struct {
    double b0, b1, b2, a1, a2;
} ASMVitrineBiquad;

typedef struct {
    double s1, s2;
} ASMVitrineBiquadState;

static inline double ASMVitrineBiquadTick(const ASMVitrineBiquad *q, ASMVitrineBiquadState *s, double x) {
    double y = q->b0 * x + s->s1;
    s->s1 = q->b1 * x - q->a1 * y + s->s2;
    s->s2 = q->b2 * x - q->a2 * y;
    return y;
}

// A lane through `count` sections in turn, in place.
void ASMVitrineBiquadRun(const ASMVitrineBiquad *sections, ASMVitrineBiquadState *states, int count, float *lane, uint32_t frames);

ASMVitrineBiquad ASMVitrineBiquadPeak(double rate, double frequency, double q, double gainDB);
ASMVitrineBiquad ASMVitrineBiquadLowShelf(double rate, double frequency, double q, double gainDB);
ASMVitrineBiquad ASMVitrineBiquadLowPass(double rate, double frequency, double q);
ASMVitrineBiquad ASMVitrineBiquadHighPass(double rate, double frequency, double q);
ASMVitrineBiquad ASMVitrineBiquadAllPass(double rate, double frequency, double q);
double ASMVitrineBiquadGainDB(const ASMVitrineBiquad *sections, int count, double rate, double frequency);

// Peaking bands at `frequencies`, their own gains solved so that the whole cascade meets each band's gain
// at its center. A band at or over 0.46 of the rate stays flat.
void ASMVitrineDSPDesignEqualizer(double rate, const double frequencies[15], const double gains[15], ASMVitrineBiquad bands[15]);

// `count` frequencies log spaced from 20 Hz to 20 kHz.
void ASMVitrineDSPLogFrequencies(int count, double *frequencies);

// A smooth curve through points on a log frequency axis (monotone cubic, flat past the ends), for drawing.
double ASMVitrineDSPSmoothCurve(const double *frequencies, const double *values, int count, double frequency);

#pragma mark - ViPER DDC

// A .vdc file: biquads for 44.1 and for 48 kHz, five numbers each (b0, b1, b2 and the two feedback
// coefficients, whose sign is read from the file: the one that makes every filter stable).
typedef struct {
    ASMVitrineBiquad *sections[2];
    int counts[2];
} ASMVitrineDSPDDC;

bool ASMVitrineDSPParseDDC(const char *text, ASMVitrineDSPDDC *ddc, char *error, size_t errorSize);
void ASMVitrineDSPFreeDDC(ASMVitrineDSPDDC *ddc);
// The file's filters at `rate`: its own at 44.1 or 48 kHz, otherwise the nearer set moved to the rate by
// a bilinear frequency warp. malloc'd, `count` of them.
ASMVitrineBiquad *ASMVitrineDSPDDCFor(const ASMVitrineDSPDDC *ddc, double rate, int *count);

#pragma mark - GraphicEQ and minimum phase

// AutoEq's "GraphicEQ: 20 -1.2; 21 -1.1; ...": its points, sorted by frequency.
typedef struct {
    double *frequencies, *gains;
    int count;
} ASMVitrineDSPGraphicCurve;

bool ASMVitrineDSPParseGraphicEq(const char *text, ASMVitrineDSPGraphicCurve *curve);
void ASMVitrineDSPFreeGraphicEq(ASMVitrineDSPGraphicCurve *curve);
// dB at `frequency`: straight between points on a log frequency axis, flat past the ends.
double ASMVitrineDSPGraphicEqAt(const ASMVitrineDSPGraphicCurve *curve, double frequency);
// The curve as a minimum phase FIR at `rate`, `*taps` long (malloc'd); NULL when out of memory.
float *ASMVitrineDSPDesignGraphicEq(const ASMVitrineDSPGraphicCurve *curve, double rate, int *taps);

// The minimum phase impulse response of a magnitude given at the n / 2 + 1 bins of an n = 2^log2n point
// spectrum, its first `taps` samples into `impulse`. false when out of memory.
bool ASMVitrineDSPMinimumPhase(const double *magnitude, int log2n, float *impulse, int taps);
