// Between the audio effects' settings (AudioEffectsSettings.m) and their engine (AudioEffects.x), inside
// Shared/AudioEffects.
#import <Foundation/Foundation.h>

// The effect a key belongs to, named by its switch key. The master switch and output control's keys
// belong to ASMVitrineKeyDSP.
NSString *ASMVitrineDSPEffectOf(NSString *key);

// Re-reads the effect's keys into the engine off the main thread, a burst of calls (a slider being dragged)
// coming down to the last. ASMVitrineKeyDSP starts the engine when Spotify's output has started, or bypasses it.
// Main thread.
void ASMVitrineDSPApply(NSString *effect);
