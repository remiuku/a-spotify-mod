#pragma once
#include <stdint.h>
#include <stdbool.h>

// A single physical activation must not replay both event registrations.
static inline uint64_t ASMControlTapEvent(uint64_t available, uint64_t preferred, uint64_t fallback) {
    if (available & preferred) return preferred;
    return (available & fallback) ? fallback : 0;
}
static inline bool ASMControlTapBegin(bool *active) {
    if (*active) return false;
    *active = true; return true;
}
static inline void ASMControlTapEnd(bool *active) { *active = false; }
