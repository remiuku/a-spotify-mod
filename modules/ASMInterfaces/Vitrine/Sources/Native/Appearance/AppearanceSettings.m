#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "Appearance.h"

// The preset is read off the color stored, so the hooks keep the one key they read and a color set before
// presets existed stays in effect: Apple Music's red reads as Apple Music, any other color as Custom, none
// as Spotify. The custom color is put aside while a preset is in place, so Custom brings it back.
static NSArray<NSString *> *presets(void) {
    return @[@"Spotify", @"Apple Music", @"Custom"];
}

static NSInteger preset(void) {
    NSInteger rgb = ASMVitrineInt(ASMVitrineKeyAccent, -1);
    if (rgb < 0 || rgb > 0xFFFFFF) return 0;
    return rgb == ASMVitrineAppleMusicRed ? 1 : 2;
}

static void choosePreset(NSInteger index) {
    if (preset() == 2) ASMVitrineSetInt(ASMVitrineKeyAccentCustom, ASMVitrineInt(ASMVitrineKeyAccent, -1));
    NSInteger custom = ASMVitrineInt(ASMVitrineKeyAccentCustom, ASMVitrineSpotifyGreen);
    if (custom < 0 || custom > 0xFFFFFF) custom = ASMVitrineSpotifyGreen;
    ASMVitrineSetInt(ASMVitrineKeyAccent, index == 0 ? -1 : index == 1 ? ASMVitrineAppleMusicRed : custom);
}

// The native look's rows of the Appearance page (App/Pages.m): the preset from a menu, then the color in
// effect, which opens the picker; a color stored from there is Custom.
NSArray<ASMVitrineModRow *> *ASMVitrineNativeAppearanceRows(void) {
    ASMVitrineModRow *menu = ASMVitrineMenuRow(@"Accent color preset", presets(), ^NSString *{ return presets()[(NSUInteger)preset()]; },
                               ^(NSInteger index) { choosePreset(index); });
    ASMVitrineModRow *colour = ASMVitrineStatActionRow(@"Accent color", nil, ^NSString *{ return [NSString stringWithFormat:@"#%06lX", (long)ASMVitrineAccentRGB()]; }, ^{
        ASMVitrinePickColor(@"Accent color", ASMVitrineAccentRGB(), ^(NSInteger rgb) {
            ASMVitrineSetInt(ASMVitrineKeyAccent, rgb);
            ASMVitrineSetInt(ASMVitrineKeyAccentCustom, rgb);
        });
    });
    colour.swatch = ^UIColor *{ return ASMVitrineColorRGB(ASMVitrineAccentRGB()); };
    return @[
        ASMVitrineWithSymbol(ASMVitrineOptionRow(@"AMOLED background", nil, ASMVitrineKeyAmoled), @"moon"),
        ASMVitrineWithSymbol(menu, @"paintpalette"),
        ASMVitrineWithSymbol(colour, @"eyedropper"),
    ];
}
