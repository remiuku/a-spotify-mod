// JamesDSP's settings: what each key holds until set, its bounds, and the lists the page's choices pick
// from. The values, ranges and lists are RootlessJamesDSP's (its preferences and arrays.xml), so a setup
// described for it reads the same here.
#import "Core/ASMSpotiCore.h"
#import "JamesDSP.h"
#import "JamesDSPEngine.h"

const double ASMSpotiDSPEqualizerFrequencies[15] = {25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000};
const double ASMSpotiDSPEqualizerGainLimit = 12;
const double ASMSpotiDSPCompanderFrequencies[7] = {95, 200, 400, 800, 1600, 3400, 7500};
const double ASMSpotiDSPCompanderGainLimit = 1.2;

#pragma mark - the keys

typedef struct {
    NSString *__unsafe_unretained key;
    ASMSpotiDSPRange range;
} ASMSpotiDSPNumberKey;

static const ASMSpotiDSPNumberKey kNumbers[] = {
    {ASMSpotiKeyDSPPostGain,               {-15, 15, 0, 0.5}},
    {ASMSpotiKeyDSPLimiterThreshold,       {-60, -0.1, -0.1, 0.1}},
    {ASMSpotiKeyDSPLimiterRelease,         {1.5, 500, 60, 0.5}},
    {ASMSpotiKeyDSPCompanderTime,          {0.06, 0.3, 0.22, 0.01}},
    {ASMSpotiKeyDSPCompanderGranularity,   {0, 4, 2, 1}},
    {ASMSpotiKeyDSPCompanderTransform,     {0, 3, 0, 1}},
    {ASMSpotiKeyDSPBassGain,               {3, 15, 5, 0.5}},
    {ASMSpotiKeyDSPEqualizerFilter,        {0, 5, 0, 1}},
    {ASMSpotiKeyDSPEqualizerInterpolation, {0, 1, 0, 1}},
    {ASMSpotiKeyDSPConvolverMode,          {0, 2, 0, 1}},
    {ASMSpotiKeyDSPReverbPreset,           {0, 12, 9, 1}},    // Plate high, RootlessJamesDSP's
    {ASMSpotiKeyDSPStereoWideLevel,        {30, 75, 60, 1}},
    {ASMSpotiKeyDSPCrossfeedMode,          {0, 5, 5, 1}},     // Realistic surround, RootlessJamesDSP's
    {ASMSpotiKeyDSPTubeDrive,              {-3, 12, 2, 0.5}},
};

static NSDictionary<NSString *, NSString *> *stringDefaults(void) {
    static NSDictionary<NSString *, NSString *> *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        defaults = @{
            ASMSpotiKeyDSPCompanderGains: @"0;0;0;0;0;0;0",
            ASMSpotiKeyDSPEqualizerGains: @"0;0;0;0;0;0;0;0;0;0;0;0;0;0;0",
            ASMSpotiKeyDSPGraphicEqNodes: @"GraphicEQ: 0.0 0.0;",
            ASMSpotiKeyDSPConvolverFile: @"",
            ASMSpotiKeyDSPConvolverWaveEdit: @"-80;-100;0;0;0;0",
            ASMSpotiKeyDSPDDCFile: @"",
            ASMSpotiKeyDSPLiveprogFile: @"",
        };
    });
    return defaults;
}

// The switches of the effects, each the prefix of its own keys' names.
static NSArray<NSString *> *effectSwitches(void) {
    return @[ASMSpotiKeyDSPCompander, ASMSpotiKeyDSPBass, ASMSpotiKeyDSPEqualizer, ASMSpotiKeyDSPGraphicEq, ASMSpotiKeyDSPConvolver, ASMSpotiKeyDSPDDC,
             ASMSpotiKeyDSPLiveprog, ASMSpotiKeyDSPReverb, ASMSpotiKeyDSPStereoWide, ASMSpotiKeyDSPCrossfeed, ASMSpotiKeyDSPTube];
}

NSString *ASMSpotiDSPEffectOf(NSString *key) {
    for (NSString *effect in effectSwitches()) {
        if ([key isEqualToString:effect] || [key hasPrefix:[effect stringByAppendingString:@"."]]) return effect;
    }
    return ASMSpotiKeyDSP;
}

ASMSpotiDSPRange ASMSpotiDSPRangeFor(NSString *key) {
    for (size_t i = 0; i < sizeof kNumbers / sizeof *kNumbers; i++) {
        if ([kNumbers[i].key isEqualToString:key]) return kNumbers[i].range;
    }
    return (ASMSpotiDSPRange){0, 1, 0, 0};
}

#pragma mark - reading and writing

static NSUserDefaults *store(void) {
    return NSUserDefaults.standardUserDefaults;
}

BOOL ASMSpotiDSPSwitch(NSString *key) {
    return ASMSpotiHidden(key);
}

void ASMSpotiDSPSetSwitch(NSString *key, BOOL on) {
    ASMSpotiSetEnabled(key, on);
    ASMSpotiDSPApply(ASMSpotiDSPEffectOf(key));
}

double ASMSpotiDSPNumber(NSString *key) {
    ASMSpotiDSPRange range = ASMSpotiDSPRangeFor(key);
    id value = [store() objectForKey:key];
    if (![value isKindOfClass:NSNumber.class]) return range.fallback;
    return MAX(range.min, MIN(range.max, [value doubleValue]));
}

void ASMSpotiDSPSetNumber(NSString *key, double value) {
    ASMSpotiDSPRange range = ASMSpotiDSPRangeFor(key);
    [store() setDouble:MAX(range.min, MIN(range.max, value)) forKey:key];
    ASMSpotiDSPApply(ASMSpotiDSPEffectOf(key));
}

NSString *ASMSpotiDSPString(NSString *key) {
    id value = [store() objectForKey:key];
    return [value isKindOfClass:NSString.class] ? value : (stringDefaults()[key] ?: @"");
}

void ASMSpotiDSPSetString(NSString *key, NSString *value) {
    [store() setObject:value ?: @"" forKey:key];
    ASMSpotiDSPApply(ASMSpotiDSPEffectOf(key));
}

static NSUInteger gainCount(NSString *key) {
    return [key isEqualToString:ASMSpotiKeyDSPCompanderGains] ? 7 : 15;
}

static double gainLimit(NSString *key) {
    return [key isEqualToString:ASMSpotiKeyDSPCompanderGains] ? ASMSpotiDSPCompanderGainLimit : ASMSpotiDSPEqualizerGainLimit;
}

NSArray<NSNumber *> *ASMSpotiDSPGains(NSString *key) {
    NSArray<NSString *> *parts = [ASMSpotiDSPString(key) componentsSeparatedByString:@";"];
    NSUInteger count = gainCount(key);
    double limit = gainLimit(key);
    NSMutableArray<NSNumber *> *gains = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        double gain = i < parts.count ? parts[i].doubleValue : 0;
        [gains addObject:@(MAX(-limit, MIN(limit, gain)))];
    }
    return gains;
}

void ASMSpotiDSPSetGains(NSString *key, NSArray<NSNumber *> *gains) {
    NSUInteger count = gainCount(key);
    double limit = gainLimit(key);
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        double gain = i < gains.count ? gains[i].doubleValue : 0;
        [parts addObject:[NSString stringWithFormat:@"%.2f", MAX(-limit, MIN(limit, gain))]];
    }
    ASMSpotiDSPSetString(key, [parts componentsJoinedByString:@";"]);
}

void ASMSpotiDSPResetAll(void) {
    for (size_t i = 0; i < sizeof kNumbers / sizeof *kNumbers; i++) [store() removeObjectForKey:kNumbers[i].key];
    for (NSString *key in stringDefaults()) [store() removeObjectForKey:key];
    for (NSString *effect in effectSwitches()) [store() removeObjectForKey:effect];
    ASMSpotiDSPApply(ASMSpotiKeyDSP);
    for (NSString *effect in effectSwitches()) ASMSpotiDSPApply(effect);
}

#pragma mark - lists

NSArray<NSString *> *ASMSpotiDSPEqualizerFilterNames(void) {
    return @[@"FIR minimum phase", @"IIR 4th order", @"IIR 6th order", @"IIR 8th order", @"IIR 10th order", @"IIR 12th order"];
}

NSArray<NSString *> *ASMSpotiDSPEqualizerInterpolationNames(void) {
    return @[@"Cubic Hermite", @"Modified Akima"];
}

NSArray<NSString *> *ASMSpotiDSPCompanderTransformNames(void) {
    return @[@"Uniform (short-time Fourier)", @"Multiresolution (continuous wavelet)",
             @"Pseudo multiresolution (undersampling)", @"Pseudo multiresolution (time domain)"];
}

NSArray<NSString *> *ASMSpotiDSPConvolverModeNames(void) {
    return @[@"Original", @"Shrink", @"Minimum phase and shrink"];
}

NSArray<NSString *> *ASMSpotiDSPCrossfeedModeNames(void) {
    return @[@"BS2B weak", @"BS2B strong", @"Out of head", @"Surround 1", @"Surround 2", @"Realistic surround"];
}

NSArray<NSString *> *ASMSpotiDSPReverbPresetNames(void) {
    return @[@"Default", @"Small hall 1", @"Small hall 2", @"Medium hall", @"Large hall", @"Small room 1", @"Small room 2",
             @"Medium room", @"Large room", @"Plate high", @"Plate low", @"Long reverb 1", @"Long reverb 2"];
}

NSArray<NSString *> *ASMSpotiDSPEqualizerPresetNames(void) {
    return @[@"Acoustic", @"Bass", @"Beats", @"Classic", @"Clear", @"Deep", @"Dubstep", @"Electronic", @"Flat",
             @"Hardstyle", @"Hip-Hop", @"Jazz", @"Metal", @"Movie", @"Pop", @"R&B", @"Rock", @"Vocal Booster"];
}

NSArray<NSNumber *> *ASMSpotiDSPEqualizerPreset(NSInteger index) {
    static const double presets[][15] = {
        {5.00, 4.50, 4.00, 3.50, 1.50, 1.00, 1.50, 1.50, 2.00, 3.00, 3.50, 4.00, 3.70, 3.00, 3.00},
        {10.00, 8.80, 8.50, 6.50, 2.50, 1.50, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {-5.5, -5.0, -4.5, -4.2, -3.5, -3.0, -1.9, 0, 0, 0, 0, 0, 0, 0, 0},
        {-0.3, 0.3, -3.5, -9.0, -1.0, 0.0, 1.8, 2.1, 0.0, 0.0, 0.0, 4.4, 9.0, 9.0, 9.0},
        {3.5, 5.5, 6.5, 9.5, 8.0, 6.5, 3.5, 2.5, 1.3, 5.0, 7.0, 9.0, 10.0, 11.0, 9.0},
        {12.0, 8.0, 0.0, -6.7, -12.0, -9.0, -3.5, -3.5, -6.1, 0.0, -3.0, -5.0, 0.0, 1.2, 3.0},
        {12.0, 10.0, 0.5, -1.0, -3.0, -5.0, -5.0, -4.8, -4.5, -2.5, -1.0, 0.0, -2.5, -2.5, 0.0},
        {4.0, 4.0, 3.5, 1.0, 0.0, -0.5, -2.0, 0.0, 2.0, 0.0, 0.0, 1.0, 3.0, 4.0, 4.5},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {6.1, 7.0, 12.0, 6.1, -5.0, -12.0, -2.5, 3.0, 6.5, 0.0, -2.2, -4.5, -6.1, -9.2, -10.0},
        {4.5, 4.3, 4.0, 2.5, 1.5, 3.0, -1.0, -1.5, -1.5, 1.5, 0.0, -1.0, 0.0, 1.5, 3.0},
        {0.0, 0.0, 0.0, 2.0, 4.0, 5.9, -5.9, -4.5, -2.5, 2.5, 1.0, -0.8, -0.8, -0.8, -0.8},
        {10.5, 10.5, 7.5, 0.0, 2.0, 5.5, 0.0, 0.0, 0.0, 6.1, 0.0, 0.0, 6.1, 10.0, 12.0},
        {3.0, 3.0, 6.1, 8.5, 9.0, 7.0, 6.1, 6.1, 5.0, 8.0, 3.5, 3.5, 8.0, 10.0, 8.0},
        {0.0, 0.0, 0.0, 0.0, 0.0, 1.3, 2.0, 2.5, 5.0, -1.5, -2.0, -3.0, -3.0, -3.0, -3.0},
        {3.0, 3.0, 7.0, 6.1, 4.5, 1.5, -1.5, -2.0, -1.5, 2.0, 2.5, 3.0, 3.5, 3.8, 4.0},
        {0.0, 0.0, 0.0, 3.0, 3.0, -10.0, -4.0, -1.0, 0.8, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0},
        {-1.5, -2.0, -3.0, -3.0, -0.5, 1.5, 3.5, 3.5, 3.5, 3.0, 2.0, 1.5, 0.0, 0.0, -1.5},
    };
    if (index < 0 || index >= (NSInteger)(sizeof presets / sizeof *presets)) return nil;
    NSMutableArray<NSNumber *> *gains = [NSMutableArray arrayWithCapacity:15];
    for (int i = 0; i < 15; i++) [gains addObject:@(presets[index][i])];
    return gains;
}
