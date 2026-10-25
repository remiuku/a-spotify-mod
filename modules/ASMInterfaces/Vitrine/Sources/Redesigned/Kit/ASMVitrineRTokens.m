#import <CoreText/SFNTLayoutTypes.h>
#import "Core/ASMVitrineCore.h"
#import "ASMVitrineRTokens.h"
#import "ASMVitrineRAccent.h"

const CGFloat ASMVitrineRSideMargin = 16;
const CGFloat ASMVitrineRGrid = 8;
const CGFloat ASMVitrineRRadiusArtwork = 12;
const CGFloat ASMVitrineRRadiusCard = 16;
const CGFloat ASMVitrineRRadiusCover = 8;
const CGFloat ASMVitrineRRadiusThumb = 6;
const CGFloat ASMVitrineRGlassCircleSize = 44;
const CGFloat ASMVitrineRActionHeight = 48;
const CGFloat ASMVitrineRActionSpacing = 12;
const CGFloat ASMVitrineRGlassSpacing = 16;
const NSTimeInterval ASMVitrineRCrossfade = 0.35;

// A layout spring settles in about this long without overshooting; a press gives a little back.
static const NSTimeInterval kLayoutDuration = 0.45, kPressDuration = 0.32;
// The tab bar's minimize runs on every scroll, so it is quicker than the 0.3 to 0.4 s Apple gives a
// repositioning spring.
static const NSTimeInterval kBarDuration = 0.26;
static const CGFloat kPressDamping = 0.62;
// A response lands within the press feedback's budget, on a curve that is most of the way there at once.
static const NSTimeInterval kRespondDuration = 0.2;
// An exit is quicker still; Native/Player/PlayerGestures.x keeps its own copy of the value.
static const NSTimeInterval kExitDuration = 0.15;

UIColor *ASMVitrineRPrimary(void) {
    return UIColor.whiteColor;
}

UIColor *ASMVitrineRSecondary(void) {
    return [UIColor colorWithWhite:1 alpha:ASMVitrineRIncreaseContrast() ? 0.80 : 0.65];
}

UIColor *ASMVitrineRTertiary(void) {
    return [UIColor colorWithWhite:1 alpha:ASMVitrineRIncreaseContrast() ? 0.60 : 0.40];
}

// Read per call: the accent is stored as it is picked, and the color row reads it the same way.
UIColor *ASMVitrineRAccent(void) {
    return ASMVitrineRAccentColor() ?: [UIColor colorWithRed:0x1E / 255.0 green:0xD7 / 255.0 blue:0x60 / 255.0 alpha:1];
}

UIColor *ASMVitrineRNeutralField(void) {
    return [UIColor colorWithRed:0x12 / 255.0 green:0x12 / 255.0 blue:0x12 / 255.0 alpha:1];
}

UIColor *ASMVitrineRSolidGlassFill(void) {
    return [UIColor colorWithWhite:1 alpha:0.16];
}

UIColor *ASMVitrineRHairline(void) {
    return [UIColor colorWithWhite:1 alpha:ASMVitrineRIncreaseContrast() ? 0.20 : 0.12];
}

UIColor *ASMVitrineRElevated(UIColor *field) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![field getRed:&r green:&g blue:&b alpha:&a]) return [UIColor colorWithWhite:1 alpha:0.08];
    // 12% toward white keeps a card on a black field clear of the grays ASMVitrineRAmoled.x turns black.
    CGFloat lift = 0.12;
    return [UIColor colorWithRed:r + (1 - r) * lift green:g + (1 - g) * lift blue:b + (1 - b) * lift alpha:1];
}

UIFont *ASMVitrineRFont(UIFontTextStyle style, UIFontWeight weight, UIContentSizeCategory largest) {
    UIContentSizeCategory current = UIApplication.sharedApplication.preferredContentSizeCategory;
    if (largest && UIContentSizeCategoryCompareToCategory(current, largest) == NSOrderedDescending) current = largest;
    UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:current];
    CGFloat size = [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits].pointSize;
    return [UIFont systemFontOfSize:size weight:weight];
}

UIFont *ASMVitrineRMonospacedDigitsFont(UIFont *font) {
    if (!font) return nil;
    NSArray *features = @[@{UIFontFeatureTypeIdentifierKey: @(kNumberSpacingType), UIFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)}];
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorByAddingAttributes:@{UIFontDescriptorFeatureSettingsAttribute: features}];
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

BOOL ASMVitrineRReduceMotion(void) {
    return UIAccessibilityIsReduceMotionEnabled();
}

BOOL ASMVitrineRReduceTransparency(void) {
    return UIAccessibilityIsReduceTransparencyEnabled();
}

BOOL ASMVitrineRIncreaseContrast(void) {
    return UIAccessibilityDarkerSystemColorsEnabled();
}

void ASMVitrineRAnimate(ASMVitrineRMotion motion, void (^animations)(void), void (^completion)(BOOL finished)) {
    if (!animations) return;
    if ((motion == ASMVitrineRMotionLayout || motion == ASMVitrineRMotionPress || motion == ASMVitrineRMotionBar) && ASMVitrineRReduceMotion()) {
        [UIView performWithoutAnimation:animations];
        if (completion) completion(YES);
        return;
    }
    UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState;
    switch (motion) {
        case ASMVitrineRMotionLayout:
            [UIView animateWithDuration:kLayoutDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:options animations:animations completion:completion];
            break;
        case ASMVitrineRMotionBar:
            [UIView animateWithDuration:kBarDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:options animations:animations completion:completion];
            break;
        case ASMVitrineRMotionPress:
            [UIView animateWithDuration:kPressDuration delay:0 usingSpringWithDamping:kPressDamping initialSpringVelocity:0 options:options animations:animations completion:completion];
            break;
        case ASMVitrineRMotionFade:
            [UIView animateWithDuration:ASMVitrineRCrossfade delay:0 options:options | UIViewAnimationOptionCurveEaseInOut animations:animations completion:completion];
            break;
        case ASMVitrineRMotionRespond: {
            // UIView's own curves are too soft for this; a property animator takes any curve, and like the
            // others it starts from what is on screen, so it can take over a fade halfway out.
            UICubicTimingParameters *curve = [[UICubicTimingParameters alloc] initWithControlPoint1:CGPointMake(0.23, 1)
                                                                                     controlPoint2:CGPointMake(0.32, 1)];
            UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:kRespondDuration timingParameters:curve];
            [animator addAnimations:animations];
            if (completion) [animator addCompletion:^(UIViewAnimatingPosition position) { completion(position == UIViewAnimatingPositionEnd); }];
            [animator startAnimation];
            break;
        }
        case ASMVitrineRMotionExit:
            [UIView animateWithDuration:kExitDuration delay:0 options:options | UIViewAnimationOptionCurveEaseOut animations:animations completion:completion];
            break;
    }
}

void ASMVitrineRAnimateLayout(UIView *host, void (^animations)(void), void (^completion)(BOOL finished)) {
    if (!animations) return;
    if (!ASMVitrineRReduceMotion() || !host.window) {
        ASMVitrineRAnimate(ASMVitrineRMotionLayout, animations, completion);
        return;
    }
    // Snapshot the host, so the layout changes in place while the old picture dissolves.
    [UIView transitionWithView:host duration:0.2
        options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:animations completion:completion];
}
