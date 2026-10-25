#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <os/proc.h>
#endif
#import "Core/ASMVitrineLog.h"
#import "ASMVitrineSingLoader.h"
#import "ASMVitrineSingSeparator.h"

// The CPU copy loaded in 0.9-5 s on an M4. The Neural Engine's first load compiles the model, which Core ML then
// keeps: 24-63 s on an M4 and 32-46 s on an iPhone 15 Pro, then 0.4-0.7 s; it has ten minutes.
double ASMVitrineSingLoaderCPUDeadline = 120, ASMVitrineSingLoaderNeuralDeadline = 600, ASMVitrineSingLoaderKeepSeconds = 60;
// A CPU copy loads beside an abandoned load still out (or again after a memory warning) only with this much left: a
// second copy took 1.07-1.15 GB more of the process's footprint on an M4.
static const unsigned long long kCopyRoom = 1600ull * 1000 * 1000;
// The first CPU copy loads only with this much left, in place of a floor on the iPhone's memory. On an iPhone 15 Pro both
// copies warm added 0.1 GB of footprint (0.20 to 0.30 GB); the weights are mapped from disk and counted only as resident.
// 1 GB leaves the Neural Engine copy its 0.5 GB after the CPU's.
static const unsigned long long kFirstRoom = 1000ull * 1000 * 1000;
// The Neural Engine copy loads beside the CPU's only with this much left. On an iPhone 15 Pro it added 0.06-0.1 GB of
// footprint (resident 1.06 to 1.13 GB); 0.5 GB is that five times over, for its first compile, which was not measured
// apart, and for Spotify's own memory to grow without iOS closing it for a copy Sing can do without.
static const unsigned long long kNeuralRoom = 500ull * 1000 * 1000;
// The light model's (separator-light.mlmodelc, 31 MB) rooms. Measured in harness/sing on an M4 with both models, the
// copies' footprint barely differs (a warm CPU copy 0.13 GB light, 0.12 GB full) and resident memory follows the
// model's size: two CPU copies warm 0.29 GB light against 0.72 GB full, a ratio of 0.40, which scales the first and
// second copies' rooms: 0.4 GB and 0.65 GB. Its Neural Engine copy added 0.03-0.05 GB of footprint against the full
// one's 0.08 GB; 0.25 GB is five times that, as the full one's is. An earlier export took 0.3 GB of footprint on an
// iPhone 15 Pro with the CPU copy warm, so 0.4 GB still covers it, and leaves the Neural Engine copy its room after.
static const unsigned long long kLightFirstRoom = 400ull * 1000 * 1000, kLightCopyRoom = 650ull * 1000 * 1000,
                                kLightNeuralRoom = 250ull * 1000 * 1000;
static const int kStillEvery = 30;

// The rooms of the model at `url`: the light model's by its folder's name, which its dev copy shares.
static BOOL isLight(NSURL *url) {
    return [url.lastPathComponent isEqualToString:@"separator-light.mlmodelc"];
}

static unsigned long long firstRoom(NSURL *url) {
    return isLight(url) ? kLightFirstRoom : kFirstRoom;
}

static unsigned long long copyRoom(NSURL *url) {
    return isLight(url) ? kLightCopyRoom : kCopyRoom;
}

static unsigned long long neuralRoom(NSURL *url) {
    return isLight(url) ? kLightNeuralRoom : kNeuralRoom;
}

// One load of one copy.
@interface ASMVitrineSingLoad : NSObject
@property (nonatomic) unsigned number;
@property (nonatomic, copy) NSString *name;   // the copy's, for the log
@property (nonatomic, copy) NSURL *url;
@property (nonatomic) CFAbsoluteTime began;
@property (nonatomic) BOOL finished, abandoned;
@end

@implementation ASMVitrineSingLoad
@end

static void (^asm_vitrine_changed)(void);
static ASMVitrineSingLoaderState asm_vitrine_state;
static NSString *asm_vitrine_error;
static ASMVitrineSingSeparator *asm_vitrine_separator;
static ASMVitrineSingLoad *asm_vitrine_cpuLoad, *asm_vitrine_fastLoad;   // the loads that count; abandoned ones are let go
static unsigned asm_vitrine_outstanding;                 // loads not come back yet, abandoned ones with them
static unsigned asm_vitrine_attempts;
static NSURL *asm_vitrine_url;
static BOOL asm_vitrine_neural;                          // a Neural Engine copy is asked for
static ASMVitrineSingFastState asm_vitrine_fastState;
static BOOL asm_vitrine_foreground;
static NSUInteger asm_vitrine_keepToken;                 // counts the mic's releases and wants, so a stale minute drops nothing
static BOOL asm_vitrine_wanted;                          // the mic is on: the Neural Engine copy is worth loading

// Run after the caller returns, so a listener that wants or purges again does not run inside it.
static void changed(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (asm_vitrine_changed) asm_vitrine_changed();
    });
}

// The memory the process has left before iOS closes it; 0 where the OS does not say (the Mac).
static unsigned long long memoryLeft(void) {
#if TARGET_OS_IPHONE
    return os_proc_available_memory();
#else
    return 0;
#endif
}

static NSString *memoryText(void) {
    unsigned long long left = memoryLeft();
    return left ? [NSString stringWithFormat:@"%.2f GB left to the process", left / 1e9] : @"memory left unknown";
}

// Whether `room` is left for a copy beside what is already in memory or still loading.
static BOOL roomFor(unsigned long long room) {
    unsigned long long left = memoryLeft();
    return !left || left >= room;
}

static void still(ASMVitrineSingLoad *load, int seconds) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kStillEvery * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (load.finished || load.abandoned) return;
        ASMVitrineLog(@"sing: still loading the %@ copy (load %u), %d s", load.name, load.number, seconds + kStillEvery);
        still(load, seconds + kStillEvery);
    });
}

// Loads and warms a copy on a queue of its own; `done` runs on the main thread unless the load was abandoned
// first, and `late` when its deadline passes before it comes back.
static ASMVitrineSingLoad *startLoad(NSURL *url, BOOL neural, double deadline, void (^done)(MLModel *model, NSError *error), void (^late)(void)) {
    ASMVitrineSingLoad *load = [ASMVitrineSingLoad new];
    load.number = ++asm_vitrine_attempts;
    load.name = neural ? @"Neural Engine" : @"CPU";
    load.url = url;
    load.began = CFAbsoluteTimeGetCurrent();
    asm_vitrine_outstanding++;
    ASMVitrineLog(@"sing: load %u, the %@ copy of %@, starts (Spotify %@, thermal state %s, %@, %@, %u loads out)", load.number, load.name,
          url.lastPathComponent, asm_vitrine_foreground ? @"active" : @"not active", ASMVitrineSingThermalName(), memoryText(), ASMVitrineSingMemoryText(), asm_vitrine_outstanding);
    NSString *name = [NSString stringWithFormat:@"asm.interface.vitrine.sing.load.%u", load.number];
    dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    dispatch_async(queue, ^{
        MLModelConfiguration *configuration = [MLModelConfiguration new];
        configuration.computeUnits = neural ? MLComputeUnitsCPUAndNeuralEngine : MLComputeUnitsCPUOnly;
        NSError *error;
        MLModel *model = [MLModel modelWithContentsOfURL:url configuration:configuration error:&error];
        double loaded = CFAbsoluteTimeGetCurrent() - load.began;
        NSString *loadedMemory = ASMVitrineSingMemoryText();
        double warm = model ? [ASMVitrineSingSeparator warmUp:model error:&error] : -1;
        NSString *warmMemory = ASMVitrineSingMemoryText();
        dispatch_async(dispatch_get_main_queue(), ^{
            asm_vitrine_outstanding--;
            load.finished = YES;
            NSString *outcome = !model ? [NSString stringWithFormat:@"did not load after %.1f s: %@", loaded, error.localizedDescription]
                              : warm < 0 ? [NSString stringWithFormat:@"loaded in %.1f s, and its warm-up failed: %@", loaded, error.localizedDescription]
                                         : [NSString stringWithFormat:@"loaded in %.1f s, and its warm-up window of silence took %.1f s", loaded, warm];
            ASMVitrineLog(@"sing: load %u, the %@ copy, %@ (memory loaded: %@; warm: %@)%@", load.number, load.name, outcome, loadedMemory, warmMemory,
                  load.abandoned ? @"; it was abandoned before, so it is let go" : @"");
            if (load.abandoned) return;
            done(warm >= 0 ? model : nil, error);
        });
    });
    still(load, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(deadline * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (load.finished || load.abandoned) return;
        load.abandoned = YES;
        ASMVitrineLog(@"sing: load %u, the %@ copy, has not come back in %.0f s: abandoned", load.number, load.name, deadline);
        late();
    });
    return load;
}

static ASMVitrineSingLoad *asm_vitrine_prepareLoad;   // ASMVitrineSingLoaderPrepareNeural's, until it comes back or is taken over

static void fastLoaded(MLModel *model) {
    asm_vitrine_fastLoad = nil;
    asm_vitrine_fastState = model ? ASMVitrineSingFastReady : ASMVitrineSingFastFailed;
    if (model) [asm_vitrine_separator setFastModel:model named:@"Neural Engine"];
    changed();
}

static void fastLate(void) {
    asm_vitrine_fastLoad = nil;
    asm_vitrine_fastState = ASMVitrineSingFastTimedOut;
    changed();
}

static void startFast(void) {
    if (!asm_vitrine_wanted || asm_vitrine_state != ASMVitrineSingLoaderReady || !asm_vitrine_foreground || !asm_vitrine_neural || asm_vitrine_fastState != ASMVitrineSingFastNone) return;
    // The compile running ahead of the mic is this copy's: a second load would compile it again beside it.
    if (asm_vitrine_prepareLoad && [asm_vitrine_prepareLoad.url isEqual:asm_vitrine_url] && !asm_vitrine_prepareLoad.finished && !asm_vitrine_prepareLoad.abandoned) {
        asm_vitrine_fastState = ASMVitrineSingFastLoading;
        asm_vitrine_fastLoad = asm_vitrine_prepareLoad;
        ASMVitrineLog(@"sing: the Neural Engine copy is the one already compiling (load %u)", asm_vitrine_fastLoad.number);
        changed();
        return;
    }
    if (!roomFor(neuralRoom(asm_vitrine_url))) {
        asm_vitrine_fastState = ASMVitrineSingFastSkipped;
        ASMVitrineLog(@"sing: no Neural Engine copy: %@, it wants %.2f GB, so Sing stays on the CPU", memoryText(), neuralRoom(asm_vitrine_url) / 1e9);
        changed();
        return;
    }
    asm_vitrine_fastState = ASMVitrineSingFastLoading;
    asm_vitrine_fastLoad = startLoad(asm_vitrine_url, YES, ASMVitrineSingLoaderNeuralDeadline, ^(MLModel *model, NSError *error) {
        fastLoaded(model);
    }, ^{
        fastLate();
    });
    changed();
}

BOOL ASMVitrineSingLoaderPrepareNeural(NSURL *url, void (^done)(BOOL loaded)) {
    if (!url || asm_vitrine_outstanding || asm_vitrine_state != ASMVitrineSingLoaderIdle || !asm_vitrine_foreground || !roomFor(neuralRoom(url))) return NO;
    __block ASMVitrineSingLoad *load = startLoad(url, YES, ASMVitrineSingLoaderNeuralDeadline, ^(MLModel *model, NSError *error) {
        BOOL taken = asm_vitrine_fastLoad == load;
        asm_vitrine_prepareLoad = nil;
        if (taken) fastLoaded(model);
        else if (done) done(model != nil);
    }, ^{
        BOOL taken = asm_vitrine_fastLoad == load;
        asm_vitrine_prepareLoad = nil;
        if (taken) fastLate();
        else if (done) done(NO);
    });
    asm_vitrine_prepareLoad = load;
    return YES;
}

static void startCPU(void) {
    if (!roomFor(asm_vitrine_outstanding ? copyRoom(asm_vitrine_url) : firstRoom(asm_vitrine_url))) {
        asm_vitrine_state = ASMVitrineSingLoaderFailed;
        asm_vitrine_error = asm_vitrine_outstanding
            ? [NSString stringWithFormat:@"A load abandoned earlier still holds memory, and %@. Close Spotify and open it again to load the voice model.", memoryText()]
            : [NSString stringWithFormat:@"iOS leaves Spotify too little memory for the voice model: %@, and it needs %.1f GB. Closing Spotify and opening it again can free some.", memoryText(), firstRoom(asm_vitrine_url) / 1e9];
        ASMVitrineLog(@"sing: no new load: %@", asm_vitrine_error);
        changed();
        return;
    }
    asm_vitrine_state = ASMVitrineSingLoaderLoading;
    asm_vitrine_error = nil;
    asm_vitrine_cpuLoad = startLoad(asm_vitrine_url, NO, ASMVitrineSingLoaderCPUDeadline, ^(MLModel *model, NSError *error) {
        asm_vitrine_cpuLoad = nil;
        asm_vitrine_separator = model ? [[ASMVitrineSingSeparator alloc] initWithModel:model] : nil;
        if (asm_vitrine_separator) {
            asm_vitrine_state = ASMVitrineSingLoaderReady;
        } else {
            asm_vitrine_state = ASMVitrineSingLoaderFailed;
            asm_vitrine_error = model ? @"Karaoke could not set aside memory for the voice model."
                             : [NSString stringWithFormat:@"The voice model did not load: %@", error.localizedDescription ?: @"Core ML gave no reason."];
        }
        changed();
        startFast();
    }, ^{
        asm_vitrine_cpuLoad = nil;
        asm_vitrine_state = ASMVitrineSingLoaderFailed;
        asm_vitrine_error = [NSString stringWithFormat:@"The voice model did not load in %.0f s, so that load was given up.", ASMVitrineSingLoaderCPUDeadline];
        changed();
    });
    changed();
}

static void abandon(ASMVitrineSingLoad *load) {
    if (load && !load.finished) load.abandoned = YES;
}

void ASMVitrineSingLoaderSetChanged(void (^block)(void)) {
    asm_vitrine_changed = block;
}

void ASMVitrineSingLoaderDropFast(NSString *why) {
    BOOL had = asm_vitrine_fastState == ASMVitrineSingFastLoading || asm_vitrine_fastState == ASMVitrineSingFastReady;
    abandon(asm_vitrine_fastLoad);
    asm_vitrine_fastLoad = nil;
    [asm_vitrine_separator setFastModel:nil named:nil];
    asm_vitrine_fastState = ASMVitrineSingFastNone;
    if (!had) return;
    if (why) ASMVitrineLog(@"sing: the Neural Engine copy is dropped: %@", why);
    changed();
}

void ASMVitrineSingLoaderWant(NSURL *url, BOOL neural) {
    // Another model (its update in): the copies of the one before go, a failure with them, and this one loads.
    if (asm_vitrine_url && url && ![url isEqual:asm_vitrine_url]) {
        ASMVitrineSingLoaderPurge([NSString stringWithFormat:@"the model is now %@", url.lastPathComponent]);
        asm_vitrine_state = ASMVitrineSingLoaderIdle;
        asm_vitrine_error = nil;
    }
    asm_vitrine_keepToken++;
    asm_vitrine_wanted = YES;
    asm_vitrine_url = url;
    asm_vitrine_neural = neural;
    if (!neural) ASMVitrineSingLoaderDropFast(@"Karaoke runs on the CPU alone now");
    if (asm_vitrine_state == ASMVitrineSingLoaderIdle) startCPU();
    else startFast();
}

void ASMVitrineSingLoaderPurge(NSString *why) {
    asm_vitrine_keepToken++;
    asm_vitrine_wanted = NO;
    BOOL had = asm_vitrine_separator || asm_vitrine_cpuLoad || asm_vitrine_fastLoad;
    abandon(asm_vitrine_cpuLoad);
    asm_vitrine_cpuLoad = nil;
    ASMVitrineSingLoaderDropFast(nil);
    asm_vitrine_separator = nil;
    if (!had) return;
    asm_vitrine_state = ASMVitrineSingLoaderIdle;
    ASMVitrineLog(@"sing: the voice model is dropped: %@", why);
    changed();
}

void ASMVitrineSingLoaderRelease(void) {
    NSUInteger token = ++asm_vitrine_keepToken;
    asm_vitrine_wanted = NO;
    if (asm_vitrine_state == ASMVitrineSingLoaderFailed) {
        asm_vitrine_state = ASMVitrineSingLoaderIdle;
        asm_vitrine_error = nil;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ASMVitrineSingLoaderKeepSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (token == asm_vitrine_keepToken) ASMVitrineSingLoaderPurge([NSString stringWithFormat:@"the mic has been off for %.0f s", ASMVitrineSingLoaderKeepSeconds]);
    });
}

void ASMVitrineSingLoaderSetForeground(BOOL foreground) {
    asm_vitrine_foreground = foreground;
    if (foreground) startFast();
}

BOOL ASMVitrineSingLoaderHasRoom(void) {
    return roomFor(copyRoom(asm_vitrine_url));
}

NSURL *ASMVitrineSingLoaderURL(void) {
    return asm_vitrine_url;
}

ASMVitrineSingLoaderState ASMVitrineSingLoaderCurrentState(void) {
    return asm_vitrine_state;
}

ASMVitrineSingSeparator *ASMVitrineSingLoaderSeparator(void) {
    return asm_vitrine_state == ASMVitrineSingLoaderReady ? asm_vitrine_separator : nil;
}

NSString *ASMVitrineSingLoaderError(void) {
    return asm_vitrine_state == ASMVitrineSingLoaderFailed ? asm_vitrine_error : nil;
}

NSTimeInterval ASMVitrineSingLoaderSeconds(void) {
    return asm_vitrine_cpuLoad ? CFAbsoluteTimeGetCurrent() - asm_vitrine_cpuLoad.began : 0;
}

ASMVitrineSingFastState ASMVitrineSingLoaderFastState(void) {
    return asm_vitrine_fastState;
}

NSTimeInterval ASMVitrineSingLoaderFastSeconds(void) {
    return asm_vitrine_fastLoad ? CFAbsoluteTimeGetCurrent() - asm_vitrine_fastLoad.began : 0;
}

unsigned ASMVitrineSingLoaderAttempts(void) {
    return asm_vitrine_attempts;
}

unsigned ASMVitrineSingLoaderOutstanding(void) {
    return asm_vitrine_outstanding;
}

NSTimeInterval ASMVitrineSingLoaderPreparingSeconds(void) {
    ASMVitrineSingLoad *load = asm_vitrine_prepareLoad;
    if (!load || load.finished || load.abandoned || asm_vitrine_fastLoad == load) return -1;
    return CFAbsoluteTimeGetCurrent() - load.began;
}
