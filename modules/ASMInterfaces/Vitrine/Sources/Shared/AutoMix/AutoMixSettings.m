// The AutoMix page (App/ModSettings.x links it from the root, under either look): the switch, then the style and
// the blend length, which read Spotify's own settings and gray out while the switch is off.
// It has no restart note: Spotify's player takes a new setting at the next track change.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "AutoMix.h"

// Spotify's own crossfade slider (Settings > Playback) runs from 0, which is off and is the switch here, to 12 s.
static const double kShortest = 1, kLongest = 12;

UIViewController *ASMVitrineAutoMixSettingsPage(void) {
    ASMVitrineModRow *toggle = ASMVitrineOptionRow(@"AutoMix", nil, ASMVitrineKeyAutoMix);
    toggle.changed = ^(BOOL on) { ASMVitrineAutoMixApply(on); };

    NSArray<NSString *> *styles = @[@"Beat-matched", @"Crossfade"];
    ASMVitrineModRow *style = ASMVitrineMenuRow(@"Style", styles, ^NSString *{ return styles[(NSUInteger)ASMVitrineAutoMixCurrentStyle()]; },
                                ^(NSInteger index) { ASMVitrineAutoMixSetStyle(index); });
    style.waitsOn = ASMVitrineKeyAutoMix;

    ASMVitrineModRow *blend = ASMVitrineSliderRow(@"Blend length", nil, kShortest, kLongest, 1,
        ^double {
            ASMVitrineTransitionSettings s;
            return ASMVitrineTransitionSettingsRead(&s) ? MAX(kShortest, MIN(kLongest, s.milliseconds / 1000.0)) : 5;
        },
        ^(double value) { ASMVitrineAutoMixSetSeconds(lround(value)); },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld s", lround(value)]; });
    blend.waitsOn = ASMVitrineKeyAutoMix;

    NSString *note = ASMVitrineAutoMixAccountAllows() ? nil : @"AutoMix needs Premium, or Spoof Premium under Premium, ads & privacy.";
    return [[ASMVitrineModPage alloc] initWithTitle:@"AutoMix" intro:nil sections:@[
        ASMVitrineNotedSection(nil, @[toggle, style, blend], note),
    ] footer:nil];
}
