#pragma once
#include <stddef.h>
#include <stdint.h>

// Pure display transform. Returns required UTF-8 bytes excluding NUL. Passing a
// NULL output measures the result; callers can then allocate exactly once.
size_t ASMUwuText(const char *input, char *output, size_t capacity);
// Repeatable randomness keeps measurement and playback redraws consistent.
size_t ASMUwuDecoratedText(const char *input, uint32_t seed, char *output, size_t capacity);
uint32_t ASMUwuStableSeed(const char *input, uint32_t seed);
