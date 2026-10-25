// What the Gradient page offers and what the hooks read back, one entry per setting: the names, the
// key it is stored under and the index it falls back to. HomeGradient.x carries the numbers behind
// the names, in the same order as the names themselves.
#import "Core/ASMVitrineCore.h"
#import "Home.h"

static NSDictionary *choiceDef(ASMVitrineHomeChoice choice) {
    static NSDictionary<NSNumber *, NSDictionary *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            // Eight rotations of the green the wash was born as, at the same depth and saturation
            // around the wheel, so each of them sits behind white text the way the green does.
            @(ASMVitrineHomeChoiceTint): @{
                @"key": @"asm.interface.vitrine.homeGradientTint",
                @"default": @0,
                @"names": @[@"Spotify green", @"Teal", @"Blue", @"Indigo", @"Purple", @"Pink",
                            @"Red", @"Amber"],
            },
            @(ASMVitrineHomeChoiceStrength): @{
                @"key": @"asm.interface.vitrine.homeGradientStrength",
                @"default": @1,
                @"names": @[@"Subtle", @"Medium", @"Bold"],
            },
            @(ASMVitrineHomeChoiceHeight): @{
                @"key": @"asm.interface.vitrine.homeGradientHeight",
                @"default": @1,
                @"names": @[@"Short", @"Medium", @"Tall", @"The whole screen"],
            },
        };
    });
    return table[@(choice)] ?: table[@(ASMVitrineHomeChoiceTint)];
}

NSArray<NSString *> *ASMVitrineHomeChoiceNames(ASMVitrineHomeChoice choice) {
    return choiceDef(choice)[@"names"];
}

NSString *ASMVitrineHomeChoiceKey(ASMVitrineHomeChoice choice) {
    return choiceDef(choice)[@"key"];
}

NSInteger ASMVitrineHomeChoiceDefault(ASMVitrineHomeChoice choice) {
    return [choiceDef(choice)[@"default"] integerValue];
}

NSInteger ASMVitrineHomeChoiceValue(ASMVitrineHomeChoice choice) {
    NSDictionary *def = choiceDef(choice);
    NSInteger fallback = [def[@"default"] integerValue];
    NSInteger index = ASMVitrineInt(def[@"key"], fallback);
    return index >= 0 && index < (NSInteger)[def[@"names"] count] ? index : fallback;
}
