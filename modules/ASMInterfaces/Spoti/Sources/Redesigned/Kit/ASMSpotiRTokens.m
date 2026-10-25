#import <CoreText/SFNTLayoutTypes.h>
#import "Core/ASMSpotiCore.h"
#import "ASMSpotiRTokens.h"
#import "ASMSpotiRAccent.h"

const CGFloat ASMSpotiRSideMargin = 16;
const CGFloat ASMSpotiRGrid = 8;
const CGFloat ASMSpotiRRadiusArtwork = 12;
const CGFloat ASMSpotiRRadiusCard = 16;
const CGFloat ASMSpotiRRadiusCover = 8;
const CGFloat ASMSpotiRRadiusThumb = 6;
const CGFloat ASMSpotiRGlassCircleSize = 44;
const CGFloat ASMSpotiRActionHeight = 48;
const CGFloat ASMSpotiRActionSpacing = 12;
const CGFloat ASMSpotiRGlassSpacing = 16;
const NSTimeInterval ASMSpotiRCrossfade = 0.35;

// A layout spring settles in about this long without overshooting; a press gives a little back.
static const NSTimeInterval kLayoutDuration = 0.45, kPressDuration = 0.32;
static const CGFloat kPressDamping = 0.62;

UIColor *ASMSpotiRPrimary(void) {
    return UIColor.whiteColor;
}

UIColor *ASMSpotiRSecondary(void) {
    return [UIColor colorWithWhite:1 alpha:ASMSpotiRIncreaseContrast() ? 0.80 : 0.65];
}

UIColor *ASMSpotiRTertiary(void) {
    return [UIColor colorWithWhite:1 alpha:ASMSpotiRIncreaseContrast() ? 0.60 : 0.40];
}

// Read per call: the accent is stored as it is picked, and the colour row reads it the same way.
UIColor *ASMSpotiRAccent(void) {
    return ASMSpotiRAccentColor() ?: [UIColor colorWithRed:0x1E / 255.0 green:0xD7 / 255.0 blue:0x60 / 255.0 alpha:1];
}

UIColor *ASMSpotiRNeutralField(void) {
    return [UIColor colorWithRed:0x12 / 255.0 green:0x12 / 255.0 blue:0x12 / 255.0 alpha:1];
}

UIColor *ASMSpotiRSolidGlassFill(void) {
    return [UIColor colorWithWhite:1 alpha:0.16];
}

UIColor *ASMSpotiRHairline(void) {
    return [UIColor colorWithWhite:1 alpha:ASMSpotiRIncreaseContrast() ? 0.20 : 0.12];
}

UIColor *ASMSpotiRElevated(UIColor *field) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![field getRed:&r green:&g blue:&b alpha:&a]) return [UIColor colorWithWhite:1 alpha:0.08];
    // 12% towards white keeps a card on a black field clear of the greys ASMSpotiRAmoled.x turns black.
    CGFloat lift = 0.12;
    return [UIColor colorWithRed:r + (1 - r) * lift green:g + (1 - g) * lift blue:b + (1 - b) * lift alpha:1];
}

UIFont *ASMSpotiRFont(UIFontTextStyle style, UIFontWeight weight, UIContentSizeCategory largest) {
    UIContentSizeCategory current = UIApplication.sharedApplication.preferredContentSizeCategory;
    if (largest && UIContentSizeCategoryCompareToCategory(current, largest) == NSOrderedDescending) current = largest;
    UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:current];
    CGFloat size = [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits].pointSize;
    return [UIFont systemFontOfSize:size weight:weight];
}

UIFont *ASMSpotiRMonospacedDigitsFont(UIFont *font) {
    if (!font) return nil;
    NSArray *features = @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType), UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}];
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute: features}];
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

BOOL ASMSpotiRReduceMotion(void) {
    return UIAccessibilityIsReduceMotionEnabled();
}

BOOL ASMSpotiRReduceTransparency(void) {
    return UIAccessibilityIsReduceTransparencyEnabled();
}

BOOL ASMSpotiRIncreaseContrast(void) {
    return UIAccessibilityDarkerSystemColorsEnabled();
}

void ASMSpotiRAnimate(ASMSpotiRMotion motion, void (^animations)(void), void (^completion)(BOOL finished)) {
    if (!animations) return;
    if (motion != ASMSpotiRMotionFade && ASMSpotiRReduceMotion()) {
        [UIView performWithoutAnimation:animations];
        if (completion) completion(YES);
        return;
    }
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState;
    switch (motion) {
        case ASMSpotiRMotionLayout:
            [UIView animateWithDuration:kLayoutDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:options animations:animations completion:completion];
            break;
        case ASMSpotiRMotionPress:
            [UIView animateWithDuration:kPressDuration delay:0 usingSpringWithDamping:kPressDamping initialSpringVelocity:0 options:options animations:animations completion:completion];
            break;
        case ASMSpotiRMotionFade:
            [UIView animateWithDuration:ASMSpotiRCrossfade delay:0 options:options | UIViewAnimationOptionCurveEaseInOut animations:animations completion:completion];
            break;
    }
}
