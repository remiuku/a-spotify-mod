// Crossfade under Spoof Premium (EeveeSpotify's): the fade engine reads the stored crossfade switch,
// but the duration slider only writes the duration, so the fade stayed off at any length.
#import "Core/ASMSpotiCore.h"
#import "AdBlock.h"

@interface _TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation : NSObject
- (void)setAudioCrossfade:(BOOL)on;
@end

%hook _TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation
- (void)setAudioCrossfadeTime:(NSInteger)time {
    %orig;
    [self setAudioCrossfade:time > 0];
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiHidden(ASMSpotiKeyFakePremium)) return;
    %init;
    ASMSpotiRequireClasses(@[@"_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation"]);
}
