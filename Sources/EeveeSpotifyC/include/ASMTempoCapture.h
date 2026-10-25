#pragma once
#include <stdbool.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Only the existing output callback writes onset strength. No raw audio is
// retained. Main/worker readers exchange generations through lock-free atomics.
void ASMTempoCaptureSetEnabled(bool enabled, uint32_t revision);
bool ASMTempoCaptureIsEnabled(void);
void ASMTempoCaptureProcess(const float *samples, uint32_t count, double sampleRate);
uint32_t ASMTempoCaptureRead(float *values, uint32_t capacity, uint32_t revision, uint64_t *totalHops);
#ifdef __cplusplus
}
#endif
