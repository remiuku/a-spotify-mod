#include "SGDSPEngine.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static float left[4096], right[4096];
static double sine(unsigned sample, unsigned channel) { return sin(sample * 2 * 3.141592653589793 * 440 / 48000) * (channel ? 0.05 : 0.1); }
static double render(SGDSPEngine *engine, int blocks, int checkDelay) {
    const unsigned chunks[] = {1024, 470, 4096, 31, 512, 471};
    unsigned sample = 0, measured = 0;
    double sum = 0;
    for (int block = 0; block < blocks; block++) {
        unsigned count = chunks[block % 6];
        for (unsigned i = 0; i < count; i++) { left[i] = sine(sample + i, 0); right[i] = sine(sample + i, 1); }
        SGDSPEngineProcess(engine, left, right, count);
        for (unsigned i = 0; i < count; i++) {
            assert(isfinite(left[i]) && isfinite(right[i]));
            assert(fabs(left[i]) <= 1.001 && fabs(right[i]) <= 1.001);
            unsigned at = sample + i;
            if (checkDelay) {
                double expected = at < kSGDSPEngineBlock ? 0 : sine(at - kSGDSPEngineBlock, 0);
                assert(fabs(left[i] - expected) < 0.000002);
                expected = at < kSGDSPEngineBlock ? 0 : sine(at - kSGDSPEngineBlock, 1);
                assert(fabs(right[i] - expected) < 0.000002);
            }
            if (at > 30000) { sum += left[i] * left[i]; measured++; }
        }
        sample += count;
    }
    return measured ? sqrt(sum / measured) : 0;
}
int main(void) {
    SGDSPEngine *engine = SGDSPEngineCreate(48000);
    assert(engine && SGDSPEngineSampleRate(engine) == 48000);
    double dry = render(engine, 100, 1);
    SGDSPEngineRestart(engine);
    SGDSPEngineSetOutput(engine, -6, -0.1, 60);
    double attenuated = render(engine, 100, 0);
    assert(fabs(attenuated / dry - pow(10, -6.0/20)) < 0.015);
    SGDSPEngineSetBassBoost(engine, true, 5);
    SGDSPEngineSetReverb(engine, true, 0);
    SGDSPEngineSetStereoWide(engine, true, 60);
    SGDSPEngineSetCrossfeed(engine, true, 0);
    SGDSPEngineSetTube(engine, true, 2);
    render(engine, 120, 0);
    char error[300] = "";
    assert(!SGDSPEngineSetGraphicEq(engine, true, "not a graphic EQ", error, sizeof error));
    assert(strlen(error) > 0);
    assert(!SGDSPEngineSetDDC(engine, true, "not a DDC", error, sizeof error));
    assert(!SGDSPEngineSetLiveprog(engine, true, "@sample\nthis is ! not valid", error, sizeof error));
    unsigned count = 0;
    const char *kind, *name; const void *data; size_t length;
    while (SGDSPEngineBundledFile(count, &kind, &name, &data, &length)) { assert(name && data && length > 0); count++; }
    assert(count == 43);
    SGDSPEngineSetSampleRate(engine, 44100);
    assert(SGDSPEngineSampleRate(engine) == 44100);
    SGDSPEngineReset(engine);
    render(engine, 60, 0);
    assert(SGDSPEngineReadStats(engine, false).faults == 0);
    SGDSPEngineFree(engine);
    puts("PASS real JamesDSP engine: varied buffers, exact bypass delay, -6 dB gain, finite/limited effects, invalid files, 43 bundled assets and sample-rate reset");
}
