// Adapted from spoti.pw v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a. GPL-3.0.
// See THIRD_PARTY_SPOTI_PW.md for authors, origins and local changes.
// Between JamesDSP's settings (JamesDSPSettings.m) and its engine (JamesDSP.x), inside Shared/JamesDSP.
#import <Foundation/Foundation.h>

// The effect a key belongs to, named by its switch key. The master switch and output control's keys
// belong to SGKeyDSP.
NSString *SGDSPEffectOf(NSString *key);

// Re-reads the effect's keys into the engine off the main thread, a burst of calls (a slider being dragged)
// coming down to the last. SGKeyDSP starts the engine when Spotify's output has started, or bypasses it.
// Main thread.
void SGDSPApply(NSString *effect);
