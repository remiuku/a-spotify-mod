#include "ASMTempoCapture.h"
#include <stdatomic.h>
#include <math.h>
#include <string.h>

enum { capacity = 2048 };
static atomic_uint_fast64_t requested, published, written;
static atomic_uint slots[capacity];
// Producer-owned state; the output callback never locks, allocates or logs.
static uint64_t producerConfig, hops;
static double rate, low, coefficient, lowEnergy, fullEnergy, previousLow, previousFull;
static unsigned filled, hopFrames;

void ASMTempoCaptureSetEnabled(bool enabled, uint32_t revision) {
    atomic_store_explicit(&requested, ((uint64_t)revision << 1) | (enabled ? 1 : 0), memory_order_release);
}
bool ASMTempoCaptureIsEnabled(void) { return (atomic_load_explicit(&requested, memory_order_relaxed) & 1) != 0; }
void ASMTempoCaptureProcess(const float *samples, uint32_t count, double sampleRate) {
    uint64_t config = atomic_load_explicit(&requested, memory_order_acquire);
    if (!(config & 1) || !samples || !isfinite(sampleRate) || sampleRate < 8000 || sampleRate > 192000) return;
    if (producerConfig != config || rate != sampleRate) {
        producerConfig = config; rate = sampleRate; hops = 0; filled = 0;
        low = lowEnergy = fullEnergy = previousLow = previousFull = 0;
        coefficient = 1 - exp(-2 * 3.141592653589793 * 180 / sampleRate);
        hopFrames = (unsigned)llround(sampleRate / 100);
        atomic_store_explicit(&written, 0, memory_order_release);
        atomic_store_explicit(&published, config, memory_order_release);
    }
    for (uint32_t i = 0; i < count; i++) {
        double sample = isfinite(samples[i]) ? fmax(-2, fmin(2, samples[i])) : 0;
        low += coefficient * (sample - low);
        lowEnergy += low * low; fullEnergy += sample * sample;
        if (++filled < hopFrames) continue;
        double bass = log1p(100 * sqrt(lowEnergy / filled));
        double full = log1p(100 * sqrt(fullEnergy / filled));
        float onset = (float)(fmax(0, bass - previousLow) + 0.5 * fmax(0, full - previousFull));
        uint32_t bits; memcpy(&bits, &onset, sizeof(bits));
        atomic_store_explicit(&slots[hops % capacity], bits, memory_order_relaxed);
        hops++;
        atomic_store_explicit(&written, hops, memory_order_release);
        previousLow = bass; previousFull = full; lowEnergy = fullEnergy = 0; filled = 0;
    }
}
uint32_t ASMTempoCaptureRead(float *values, uint32_t limit, uint32_t revision, uint64_t *totalHops) {
    uint64_t expected = ((uint64_t)revision << 1) | 1;
    if (totalHops) *totalHops = 0;
    if (!values || !limit || atomic_load_explicit(&requested, memory_order_acquire) != expected ||
        atomic_load_explicit(&published, memory_order_acquire) != expected) return 0;
    uint64_t end = atomic_load_explicit(&written, memory_order_acquire);
    uint32_t count = (uint32_t)(end < capacity ? end : capacity);
    if (count > limit) count = limit;
    for (uint32_t i = 0; i < count; i++) {
        uint32_t bits = atomic_load_explicit(&slots[(end - count + i) % capacity], memory_order_relaxed);
        memcpy(&values[i], &bits, sizeof(bits));
    }
    // If a hop arrived while copying, retry next poll instead of estimating
    // from a torn window. No writer waits for a reader.
    if (atomic_load_explicit(&written, memory_order_acquire) != end ||
        atomic_load_explicit(&published, memory_order_acquire) != expected ||
        atomic_load_explicit(&requested, memory_order_acquire) != expected) return 0;
    if (totalHops) *totalHops = end;
    return count;
}
