// The audio effects' settings: what each key holds until set, its bounds, and the lists the page's choices
// pick from, in the order the engine numbers them (ASMVitrineDSPEffects.h).
#import "Core/ASMVitrineCore.h"
#import "AudioEffects.h"
#import "AudioEffectsApply.h"

const double ASMVitrineDSPEqualizerFrequencies[15] = {25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000};
const double ASMVitrineDSPEqualizerGainLimit = 12;
const double ASMVitrineDSPCompanderFrequencies[7] = {95, 200, 400, 800, 1600, 3400, 7500};
const double ASMVitrineDSPCompanderGainLimit = 1;

#pragma mark - the keys

typedef struct {
    NSString *__unsafe_unretained key;
    ASMVitrineDSPRange range;
} ASMVitrineDSPNumberKey;

static const ASMVitrineDSPNumberKey kNumbers[] = {
    {ASMVitrineKeyDSPPostGain,          {-12, 12, 0, 0.5}},
    {ASMVitrineKeyDSPLimiterThreshold,  {-24, 0, -0.3, 0.1}},
    {ASMVitrineKeyDSPLimiterRelease,    {10, 500, 100, 5}},
    {ASMVitrineKeyDSPCompanderTime,     {0.05, 0.5, 0.2, 0.01}},
    {ASMVitrineKeyDSPBassGain,          {1, 15, 6, 0.5}},
    {ASMVitrineKeyDSPConvolverMode,     {0, 2, 0, 1}},
    {ASMVitrineKeyDSPReverbPreset,      {0, 8, 5, 1}},     // Plate
    {ASMVitrineKeyDSPReverbAmount,      {0, 100, 50, 1}},  // the room's own mix
    {ASMVitrineKeyDSPStereoWideLevel,   {0, 100, 60, 1}},
    {ASMVitrineKeyDSPCrossfeedMode,     {0, 2, 2, 1}},     // libbs2b's own default
    {ASMVitrineKeyDSPTubeDrive,         {0, 18, 4, 0.5}},
};

static NSDictionary<NSString *, NSString *> *stringDefaults(void) {
    static NSDictionary<NSString *, NSString *> *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        defaults = @{
            ASMVitrineKeyDSPCompanderGains: @"0;0;0;0;0;0;0",
            ASMVitrineKeyDSPEqualizerGains: @"0;0;0;0;0;0;0;0;0;0;0;0;0;0;0",
            ASMVitrineKeyDSPGraphicEqNodes: @"GraphicEQ: 0.0 0.0;",
            ASMVitrineKeyDSPGraphicEqHeadphone: @"",
            ASMVitrineKeyDSPConvolverFile: @"",
            ASMVitrineKeyDSPDDCFile: @"",
            ASMVitrineKeyDSPLiveprogFile: @"",
        };
    });
    return defaults;
}

// The switches of the effects, each the prefix of its own keys' names.
static NSArray<NSString *> *effectSwitches(void) {
    return @[ASMVitrineKeyDSPCompander, ASMVitrineKeyDSPBass, ASMVitrineKeyDSPEqualizer, ASMVitrineKeyDSPGraphicEq, ASMVitrineKeyDSPConvolver, ASMVitrineKeyDSPDDC,
             ASMVitrineKeyDSPLiveprog, ASMVitrineKeyDSPReverb, ASMVitrineKeyDSPStereoWide, ASMVitrineKeyDSPCrossfeed, ASMVitrineKeyDSPTube];
}

NSString *ASMVitrineDSPEffectOf(NSString *key) {
    for (NSString *effect in effectSwitches()) {
        if ([key isEqualToString:effect] || [key hasPrefix:[effect stringByAppendingString:@"."]]) return effect;
    }
    return ASMVitrineKeyDSP;
}

ASMVitrineDSPRange ASMVitrineDSPRangeFor(NSString *key) {
    for (size_t i = 0; i < sizeof kNumbers / sizeof *kNumbers; i++) {
        if ([kNumbers[i].key isEqualToString:key]) return kNumbers[i].range;
    }
    return (ASMVitrineDSPRange){0, 1, 0, 0};
}

#pragma mark - reading and writing

static NSUserDefaults *store(void) {
    return NSUserDefaults.standardUserDefaults;
}

BOOL ASMVitrineDSPSwitch(NSString *key) {
    return ASMVitrineHidden(key);
}

void ASMVitrineDSPSetSwitch(NSString *key, BOOL on) {
    ASMVitrineSetEnabled(key, on);
    ASMVitrineDSPApply(ASMVitrineDSPEffectOf(key));
}

double ASMVitrineDSPNumber(NSString *key) {
    ASMVitrineDSPRange range = ASMVitrineDSPRangeFor(key);
    id value = [store() objectForKey:key];
    if (![value isKindOfClass:NSNumber.class]) return range.fallback;
    return MAX(range.min, MIN(range.max, [value doubleValue]));
}

void ASMVitrineDSPSetNumber(NSString *key, double value) {
    ASMVitrineDSPRange range = ASMVitrineDSPRangeFor(key);
    [store() setDouble:MAX(range.min, MIN(range.max, value)) forKey:key];
    ASMVitrineDSPApply(ASMVitrineDSPEffectOf(key));
}

NSString *ASMVitrineDSPString(NSString *key) {
    id value = [store() objectForKey:key];
    return [value isKindOfClass:NSString.class] ? value : (stringDefaults()[key] ?: @"");
}

void ASMVitrineDSPSetString(NSString *key, NSString *value) {
    [store() setObject:value ?: @"" forKey:key];
    ASMVitrineDSPApply(ASMVitrineDSPEffectOf(key));
}

static NSUInteger gainCount(NSString *key) {
    return [key isEqualToString:ASMVitrineKeyDSPCompanderGains] ? 7 : 15;
}

static double gainLimit(NSString *key) {
    return [key isEqualToString:ASMVitrineKeyDSPCompanderGains] ? ASMVitrineDSPCompanderGainLimit : ASMVitrineDSPEqualizerGainLimit;
}

NSArray<NSNumber *> *ASMVitrineDSPGains(NSString *key) {
    NSArray<NSString *> *parts = [ASMVitrineDSPString(key) componentsSeparatedByString:@";"];
    NSUInteger count = gainCount(key);
    double limit = gainLimit(key);
    NSMutableArray<NSNumber *> *gains = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        double gain = i < parts.count ? parts[i].doubleValue : 0;
        [gains addObject:@(MAX(-limit, MIN(limit, gain)))];
    }
    return gains;
}

void ASMVitrineDSPSetGains(NSString *key, NSArray<NSNumber *> *gains) {
    NSUInteger count = gainCount(key);
    double limit = gainLimit(key);
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        double gain = i < gains.count ? gains[i].doubleValue : 0;
        [parts addObject:[NSString stringWithFormat:@"%.2f", MAX(-limit, MIN(limit, gain))]];
    }
    ASMVitrineDSPSetString(key, [parts componentsJoinedByString:@";"]);
}

void ASMVitrineDSPResetAll(void) {
    for (size_t i = 0; i < sizeof kNumbers / sizeof *kNumbers; i++) [store() removeObjectForKey:kNumbers[i].key];
    for (NSString *key in stringDefaults()) [store() removeObjectForKey:key];
    for (NSString *effect in effectSwitches()) [store() removeObjectForKey:effect];
    ASMVitrineDSPApply(ASMVitrineKeyDSP);
    for (NSString *effect in effectSwitches()) ASMVitrineDSPApply(effect);
}

#pragma mark - lists

NSArray<NSString *> *ASMVitrineDSPConvolverModeNames(void) {
    return @[@"Original", @"Trimmed", @"Minimum phase"];
}

NSArray<NSString *> *ASMVitrineDSPCrossfeedModeNames(void) {
    return @[@"Jan Meier (650 Hz, 9.5 dB)", @"Chu Moy (700 Hz, 6 dB)", @"Default (700 Hz, 4.5 dB)"];
}

NSArray<NSString *> *ASMVitrineDSPReverbPresetNames(void) {
    return @[@"Ambience", @"Small room", @"Medium room", @"Large room", @"Chamber", @"Plate", @"Small hall", @"Large hall", @"Cathedral"];
}

NSArray<NSString *> *ASMVitrineDSPEqualizerPresetNames(void) {
    return @[@"Flat", @"Bass", @"Loudness", @"Treble", @"Vocal", @"Warm", @"Bright", @"Rock", @"Electronic", @"Acoustic",
             @"Classical", @"Podcast"];
}

NSArray<NSNumber *> *ASMVitrineDSPEqualizerPreset(NSInteger index) {
    static const double presets[][15] = {
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {6, 6, 5, 4, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0},
        {5, 5, 4, 2, 1, 0, 0, 0, 0, 0, 1, 2, 3, 4, 4},
        {0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 5},
        {-2, -2, -2, -1, -1, 0, 1, 2, 3, 3, 2, 1, 0, -1, -1},
        {2, 2, 2, 2, 1, 1, 0, 0, 0, -1, -1, -2, -2, -2, -2},
        {-1, -1, -1, 0, 0, 0, 0, 0, 1, 2, 3, 3, 3, 3, 3},
        {4, 4, 3, 1, -1, -2, -2, -1, 0, 1, 2, 3, 3, 3, 2},
        {5, 5, 4, 2, 0, -1, -2, -1, 0, 1, 1, 2, 3, 4, 4},
        {2, 2, 2, 1, 1, 0, 0, 1, 1, 2, 2, 2, 2, 1, 1},
        {3, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 3},
        {-6, -6, -4, -2, -1, 0, 1, 2, 2, 2, 1, 0, -1, -2, -3},
    };
    if (index < 0 || index >= (NSInteger)(sizeof presets / sizeof *presets)) return nil;
    NSMutableArray<NSNumber *> *gains = [NSMutableArray arrayWithCapacity:15];
    for (int i = 0; i < 15; i++) [gains addObject:@(presets[index][i])];
    return gains;
}
