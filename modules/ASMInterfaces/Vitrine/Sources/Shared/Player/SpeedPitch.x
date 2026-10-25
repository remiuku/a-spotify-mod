#import "Core/ASMHost.h"
#import "SpeedPitch.h"
double ASMVitrinePlayerSpeed(void) { double (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerSpeed"); return f ? f() : 1; }
BOOL ASMVitrinePlayerSpeedAllowed(void) { BOOL (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerSpeedAllowed"); return f && f(); }
void ASMVitrineSetPlayerSpeed(double value) { void (*f)(double) = dlsym(RTLD_DEFAULT,"SGSetPlayerSpeed"); if (f) f(value); }
float ASMVitrinePlayerPitch(void) { float (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerPitch"); return f ? f() : 0; }
BOOL ASMVitrinePlayerPitchAvailable(void) { BOOL (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerPitchAvailable"); return f && f(); }
void ASMVitrineSetPlayerPitch(float value) { void (*f)(float) = dlsym(RTLD_DEFAULT,"SGSetPlayerPitch"); if (f) f(value); }

BOOL ASMVitrinePlayerPitchFollowsSpeed(void) { return NO; }
void ASMVitrineSetPlayerPitchFollowsSpeed(BOOL follows) {}
void ASMVitrinePlayerSetGain(float gain) {}
void ASMVitrinePlayerSetStage(ASMVitrinePlayerStage stage) {}
void ASMVitrinePlayerSetLeadReaders(ASMVitrinePlayerHeldLead held, ASMVitrinePlayerLeadOf of) {}
void ASMVitrinePlayerSetSourceSelector(ASMVitrinePlayerSourceSelector selector) {}
uint64_t ASMVitrinePlayerSourceEpoch(void) { return 0; }
void ASMVitrinePlayerInvalidateSource(void) {}
AudioUnit ASMVitrinePlayerMusicOutput(void) { return NULL; }
BOOL ASMVitrinePlayerMusicClientFormat(AudioStreamBasicDescription *format) { return NO; }
BOOL ASMVitrinePlayerWatchMusicOutput(ASMVitrinePlayerOutputWatcher watcher) { return NO; }
