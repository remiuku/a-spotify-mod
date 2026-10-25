#import "Core/ASMHost.h"
#import "SpeedPitch.h"
double ASMSpotiPlayerSpeed(void) { double (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerSpeed"); return f ? f() : 1; }
BOOL ASMSpotiPlayerSpeedAllowed(void) { BOOL (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerSpeedAllowed"); return f && f(); }
void ASMSpotiSetPlayerSpeed(double value) { void (*f)(double) = dlsym(RTLD_DEFAULT,"SGSetPlayerSpeed"); if (f) f(value); }
float ASMSpotiPlayerPitch(void) { float (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerPitch"); return f ? f() : 0; }
BOOL ASMSpotiPlayerPitchAvailable(void) { BOOL (*f)(void) = dlsym(RTLD_DEFAULT,"SGPlayerPitchAvailable"); return f && f(); }
void ASMSpotiSetPlayerPitch(float value) { void (*f)(float) = dlsym(RTLD_DEFAULT,"SGSetPlayerPitch"); if (f) f(value); }
