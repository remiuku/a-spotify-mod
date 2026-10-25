#pragma once
#import <Foundation/Foundation.h>

// Main-thread control surface; the C audio engine exposes its own realtime API.
double SGPlayerSpeed(void);
BOOL SGPlayerSpeedAllowed(void);
void SGSetPlayerSpeed(double speed);
float SGPlayerPitch(void);
void SGSetPlayerPitch(float semitones);
BOOL SGPlayerPitchAvailable(void);
double ASMPlaybackRate(void);
typedef void (*ASMAudioOutputReader)(const float *samples, uint32_t count, double sampleRate);
// A read-only, allocation-free tap for the selected interface's visualizer.
void ASMSetAudioOutputReader(ASMAudioOutputReader reader);

typedef struct { double min, max, fallback, step; } ASMDSPRange;
ASMDSPRange ASMDSPRangeFor(NSString *key);
BOOL SGDSPSwitch(NSString *key);
void SGDSPSetSwitch(NSString *key, BOOL on);
double SGDSPNumber(NSString *key);
void SGDSPSetNumber(NSString *key, double value);
NSString *SGDSPString(NSString *key);
void SGDSPSetString(NSString *key, NSString *value);
NSArray<NSNumber *> *SGDSPGains(NSString *key);
void SGDSPSetGains(NSString *key, NSArray<NSNumber *> *gains);
void SGDSPResetAll(void);
NSArray<NSString *> *SGDSPEqualizerPresetNames(void);
NSArray<NSNumber *> *SGDSPEqualizerPreset(NSInteger index);
NSString *SGDSPStatus(void);
NSString *SGDSPError(NSString *key);
NSArray<NSString *> *ASMDSPFiles(NSInteger kind);
NSString *ASMDSPImport(NSInteger kind, NSURL *url, NSError **error) __attribute__((swift_error(none)));
BOOL ASMDSPDelete(NSInteger kind, NSString *name);
