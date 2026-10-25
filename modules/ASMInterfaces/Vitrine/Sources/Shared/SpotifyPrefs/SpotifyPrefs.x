// Spotify's preferences object: made on Spotify's core thread at launch, and read only when Settings > Playback
// opens, so its getters are too late to capture it. Captured in every launch, since AutoMix's switch takes effect
// without a restart.
#import "Core/ASMVitrineCore.h"
#import "Shared/AutoMix/AutoMix.h"
#import "Shared/Lossless/LosslessQuality.h"
#import "Shared/Lossless/ASMVitrineLossless.h"
#import "SpotifyPrefs.h"

static __weak SPTPreferences *asm_vitrine_preferences, *asm_vitrine_loaded;

SPTPreferences *ASMVitrineSpotifyPreferences(void) {
    SPTPreferences *preferences = asm_vitrine_preferences;
    // The playback speed is the user's one setting that is never 0, so it tells the settings loaded from not yet.
    if (preferences && preferences != asm_vitrine_loaded && preferences.playbackSpeed > 0) asm_vitrine_loaded = preferences;
    return preferences == asm_vitrine_loaded ? preferences : nil;
}

// Every half second until the user's settings are in, then what a switch left to do when they were not.
static void reconcileWhenLoaded(void) {
    if (!asm_vitrine_preferences) return;
    if (!ASMVitrineSpotifyPreferences()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{ reconcileWhenLoaded(); });
        return;
    }
    ASMVitrineLog(@"spotify prefs: the user's settings are in");
    // Lowered when Spotify last quit, and lossless is off now: nothing else would put it back.
    if (!ASMVitrineHidden(ASMVitrineKeyLossless)) ASMVitrineLosslessLowerQuality(NO);
    ASMVitrineAutoMixReconcile();
}

%hook _TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation
- (id)initWithScheduler:(id)scheduler {
    id made = %orig;
    asm_vitrine_preferences = made;
    dispatch_async(dispatch_get_main_queue(), ^{ reconcileWhenLoaded(); });
    return made;
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    %init;
    ASMVitrineRequireClasses(@[@"_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation"]);
}
