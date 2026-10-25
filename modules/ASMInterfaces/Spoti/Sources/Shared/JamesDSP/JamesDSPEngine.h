// Between JamesDSP's settings (JamesDSPSettings.m) and its engine (JamesDSP.x), inside Shared/JamesDSP.
#import <Foundation/Foundation.h>

// The effect a key belongs to, named by its switch key. The master switch and output control's keys
// belong to ASMSpotiKeyDSP.
NSString *ASMSpotiDSPEffectOf(NSString *key);

// Re-reads the effect's keys into the engine off the main thread, a burst of calls (a slider being dragged)
// coming down to the last. ASMSpotiKeyDSP starts the engine when Spotify's output has started, or bypasses it.
// Main thread.
void ASMSpotiDSPApply(NSString *effect);
