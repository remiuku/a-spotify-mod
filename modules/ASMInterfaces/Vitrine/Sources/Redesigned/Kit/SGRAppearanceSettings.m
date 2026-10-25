#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "ASMVitrineRAccent.h"

// The preset is read off the color stored, so the hooks keep the one key they read and a color set before
// presets existed stays in effect: Apple Music's red reads as Apple Music, Spotify's own (-1) as Spotify, and
// any other color as Custom, the redesign's own green when nothing is stored among them. The custom color
// is put aside while a preset is in place, so Custom brings it back.
static NSArray<NSString *> *presets(void) {
    return @[@"Spotify", @"Apple Music", @"Custom"];
}

static NSInteger preset(void) {
    NSInteger rgb = ASMVitrineInt(ASMVitrineRKeyAccent, ASMVitrineRDefaultAccent);
    if (rgb < 0 || rgb > 0xFFFFFF) return 0;
    return rgb == ASMVitrineAppleMusicRed ? 1 : 2;
}

static void choosePreset(NSInteger index) {
    if (preset() == 2) ASMVitrineSetInt(ASMVitrineRKeyAccentCustom, ASMVitrineRAccentRGB());
    NSInteger custom = ASMVitrineInt(ASMVitrineRKeyAccentCustom, ASMVitrineRDefaultAccent);
    if (custom < 0 || custom > 0xFFFFFF) custom = ASMVitrineRDefaultAccent;
    ASMVitrineSetInt(ASMVitrineRKeyAccent, index == 0 ? -1 : index == 1 ? ASMVitrineAppleMusicRed : custom);
}

// The redesign's rows of the Appearance page (App/Pages.m): the preset from a menu, then the color in effect,
// which opens the picker; a color stored from there is Custom. AMOLED has no row: the redesign is always black.
NSArray<ASMVitrineModRow *> *ASMVitrineRAppearanceRows(void) {
    ASMVitrineModRow *menu = ASMVitrineMenuRow(@"Accent color preset", presets(), ^NSString *{ return presets()[(NSUInteger)preset()]; },
                               ^(NSInteger index) { choosePreset(index); });
    ASMVitrineModRow *colour = ASMVitrineStatActionRow(@"Accent color", nil, ^NSString *{ return [NSString stringWithFormat:@"#%06lX", (long)ASMVitrineRAccentRGB()]; }, ^{
        ASMVitrinePickColor(@"Accent color", ASMVitrineRAccentRGB(), ^(NSInteger rgb) {
            ASMVitrineSetInt(ASMVitrineRKeyAccent, rgb);
            ASMVitrineSetInt(ASMVitrineRKeyAccentCustom, rgb);
        });
    });
    colour.swatch = ^UIColor *{ return ASMVitrineColorRGB(ASMVitrineRAccentRGB()); };
    return @[
        ASMVitrineWithSymbol(menu, @"paintpalette"),
        ASMVitrineWithSymbol(colour, @"eyedropper"),
        ASMVitrineWithSymbol(ASMVitrineOptionRow(@"Plain checkmark", @"A saved song's tick without its circle, in the accent", ASMVitrineRKeyPlainCheck), @"checkmark"),
    ];
}
