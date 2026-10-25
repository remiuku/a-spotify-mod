#pragma once
#import <Foundation/Foundation.h>
#import "ASMVitrineAnchorRing.h"

#if ASMVitrine_DRIVER
// Main thread only. The event's epoch and host time are captured where it happened.
void ASMVitrineAnchorLog(NSString *kind, NSString *evidence, uint64_t epoch, uint64_t host);
// SpeedPitch owns the rings; only the diagnostic's main-thread drain calls this.
bool ASMVitrinePlayerAnchorRead(ASMVitrineAnchorSample *latest, unsigned *dropped);
double ASMVitrinePlayerAnchorLatency(bool *engaged);
#else
static inline void ASMVitrineAnchorLog(NSString *kind, NSString *evidence, uint64_t epoch, uint64_t host) {}
#endif
