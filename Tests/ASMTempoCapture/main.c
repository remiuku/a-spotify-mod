#include "ASMTempoCapture.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    float input[257], result[1600]; uint64_t total = 0;
    ASMTempoCaptureSetEnabled(false, 1);
    memset(input, 0, sizeof(input)); ASMTempoCaptureProcess(input, 257, 48000);
    assert(ASMTempoCaptureRead(result, 1600, 1, &total) == 0);
    double bpm = argc > 1 ? atof(argv[1]) : 120;
    ASMTempoCaptureSetEnabled(true, 2);
    for (unsigned done = 0; done < 48000 * 24;) {
        unsigned count = 48000 * 24 - done; if (count > 257) count = 257;
        for (unsigned i = 0; i < count; i++) {
            double t = (done + i) / 48000.0, phase = fmod(t, 60 / bpm);
            input[i] = (float)(0.6 * sin(2 * 3.141592653589793 * 80 * t) * exp(-phase * 45) + 0.08 * sin(2 * 3.141592653589793 * 440 * t));
        }
        float original = input[0]; ASMTempoCaptureProcess(input, count, 48000); assert(input[0] == original); done += count;
    }
    uint32_t count = ASMTempoCaptureRead(result, 1600, 2, &total);
    assert(count == 1600 && total == 2400);
    for (unsigned i = 0; i < count; i++) assert(isfinite(result[i]) && result[i] >= 0);
    if (argc > 1) { fwrite(result, sizeof(float), count, stdout); return 0; }
    assert(ASMTempoCaptureRead(result, 1600, 1, &total) == 0);
    ASMTempoCaptureSetEnabled(false, 3); assert(ASMTempoCaptureRead(result, 1600, 3, &total) == 0);
    ASMTempoCaptureSetEnabled(true, 4); assert(ASMTempoCaptureRead(result, 1600, 4, &total) == 0);
    for (unsigned i = 0; i < 257; i++) input[i] = NAN;
    for (unsigned i = 0; i < 10; i++) ASMTempoCaptureProcess(input, 257, 48000);
    count = ASMTempoCaptureRead(result, 1600, 4, &total); assert(count == 5 && total == 5);
    for (unsigned i = 0; i < count; i++) assert(result[i] == 0);
    ASMTempoCaptureProcess(input, 257, NAN); ASMTempoCaptureProcess(input, 257, 0);
    puts("PASS actual tempo collector: disabled isolation, immutable PCM, fixed memory ring, revision reset, warmup and non-finite samples");
}
