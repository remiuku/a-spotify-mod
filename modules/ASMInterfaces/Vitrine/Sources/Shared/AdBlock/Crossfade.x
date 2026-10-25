// Crossfade under Spoof Premium (EeveeSpotify's): the fade engine reads the stored crossfade switch,
// but the duration slider only writes the duration, so the fade stayed off at any length.
#import "Core/ASMVitrineCore.h"
#import "Shared/SpotifyPrefs/SpotifyPrefs.h"
#import "AdBlock.h"

%hook _TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation
- (void)setAudioCrossfadeTime:(NSInteger)time {
    %orig;
    [self setAudioCrossfade:time > 0];
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineHidden(ASMVitrineKeyFakePremium)) return;
    %init;
    ASMVitrineRequireClasses(@[@"_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation"]);
}
