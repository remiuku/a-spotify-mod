// Radio/autoplay publishes shuffle and repeat restrictions even with Spoof Premium.
// Allow only those restrictions for the UI/MediaRemote, and opt the corresponding command
// into the core's override. Merely clearing the displayed restrictions does not make
// the core accept the command. The command APIs were inspected in 9.1.78/9.1.88;
// the full path was tested on 9.1.88. See harness/radio-modes/.
#import "Core/ASMVitrinePrefs.h"
#import "Core/ASMVitrineLog.h"
#import "AdBlock.h"
#import "RadioModes.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <string.h>

// The player creates and fills the ESP request synchronously, then sends it later.
// Carry the decision only while filling that request, never to an unrelated command
// or to the async response. Nested calls restore their caller's decision.
static _Thread_local NSInteger asm_vitrine_radioCommand = -1;
static _Thread_local BOOL asm_vitrine_preserveReasons;
typedef id (*ASMVitrineRadioCopyIMP)(id, SEL, NSZone *) __attribute__((ns_returns_retained));
static ASMVitrineRadioCopyIMP asm_vitrine_copyRestrictions;
static id ASMVitrineRadioCopyRestrictions(id value, SEL selector, NSZone *zone) __attribute__((ns_returns_retained));
static id ASMVitrineRadioCopyRestrictions(id value, SEL selector, NSZone *zone) {
    BOOL previous = asm_vitrine_preserveReasons;
    asm_vitrine_preserveReasons = YES;
    @try { return asm_vitrine_copyRestrictions(value, selector, zone); }
    @finally { asm_vitrine_preserveReasons = previous; }
}
static dispatch_once_t asm_vitrine_radioReasonsReported[3];
static id (*asm_vitrine_rawReasons[3])(id, SEL);
static SEL asm_vitrine_reasonSelectors[3];

static id object(id receiver, SEL selector) {
    return ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static char asm_vitrine_radioEvidenceKey;
// Some optimistic state updates have empty restrictions until the next core update.
// Keep positive radio evidence only for the same playback and context. An explicit
// non-radio reason replaces it immediately; a different playback starts afresh.
static NSArray *commandReasons(id player, id state) {
    id playback = object(state, sel_registerName("playbackId"));
    id context = object(state, sel_registerName("contextURI"));
    id limits = object(state, sel_registerName("restrictions"));
    if (!playback || !context || ![limits isKindOfClass:objc_getClass("SPTPlayerRestrictions")]) {
        @synchronized (player) {
            objc_setAssociatedObject(player, &asm_vitrine_radioEvidenceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return nil;
    }
    NSArray *identity = @[playback, context];
    @synchronized (player) {
        NSDictionary *prior = objc_getAssociatedObject(player, &asm_vitrine_radioEvidenceKey);
        NSArray *old = [prior[@"identity"] isEqual:identity] ? prior[@"reasons"] : nil;
        NSMutableArray *result = [NSMutableArray new];
        for (NSUInteger i = 0; i < 3; i++) {
            id reasons = asm_vitrine_rawReasons[i](limits, asm_vitrine_reasonSelectors[i]);
            if ([reasons isKindOfClass:NSSet.class] && ![reasons count] && old && ASMVitrineRadioModeReasonsOnly(old[i]))
                reasons = old[i];
            [result addObject:reasons ?: NSNull.null];
        }
        NSArray *snapshot = [result copy];
        objc_setAssociatedObject(player, &asm_vitrine_radioEvidenceKey, @{@"identity":identity, @"reasons":snapshot}, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return snapshot;
    }
}

static BOOL signature(Method method, const char *result, const char *argument) {
    if (!method || method_getNumberOfArguments(method) != (argument ? 3 : 2)) return NO;
    char type[16];
    method_getReturnType(method, type, sizeof(type));
    if (strcmp(type, result)) return NO;
    if (argument) {
        method_getArgumentType(method, 2, type, sizeof(type));
        if (strcmp(type, argument)) return NO;
    }
    return YES;
}

static void allowRadioRequest(id request, Class options) {
    id commandOptions = [object(request, sel_registerName("options")) copy] ?: [options new];
    ((void (*)(id, SEL, BOOL))objc_msgSend)(commandOptions, sel_registerName("setOverrideRestrictions:"), YES);
    ((void (*)(id, SEL, id))objc_msgSend)(request, sel_registerName("setOptions:"), commandOptions);
}

__attribute__((constructor)) static void ASMVitrineRadioModesInstall(void) {
    if (!ASMVitrineHidden(ASMVitrineKeyFakePremium)) return;
    Class restrictions = objc_getClass("SPTPlayerRestrictions");
    Class player = objc_getClass("SPTEsperantoPlayer");
    Class options = objc_getClass("ESPCommandOptions");
    const char *reasonNames[] = {"disallowTogglingShuffleReasons", "disallowTogglingRepeatContextReasons", "disallowTogglingRepeatTrackReasons"};
    const char *commandNames[] = {"setShufflingContext:", "setRepeatingContext:", "setRepeatingTrack:"};
    const char *requestNames[] = {"ESPSetShufflingContextRequest", "ESPSetRepeatingContextRequest", "ESPSetRepeatingTrackRequest"};
    Method reasons[3], commands[3], setters[3];
    Class requests[3];
    SEL getOptions = sel_registerName("options"), setOptions = sel_registerName("setOptions:");
    SEL setOverride = sel_registerName("setOverrideRestrictions:");
    SEL stateSelector = sel_registerName("state"), restrictionsSelector = sel_registerName("restrictions");
    SEL combinedSelector = sel_registerName("setOptions:loggingParams:");
    Method combined = class_getInstanceMethod(player, combinedSelector);
    Class combinedRequest = objc_getClass("ESPSetOptionsRequest");
    Method combinedGetters[3];
    Class overrides = objc_getClass("SPTPlayerOptionOverrides");
    const char *optionNames[] = {"shufflingContext", "repeatingContext", "repeatingTrack", "playbackSpeed", "modes"};
    BOOL compatible = signature(class_getInstanceMethod(options, setOverride), @encode(void), @encode(BOOL)) &&
        signature(class_getInstanceMethod(player, stateSelector), @encode(id), NULL) &&
        signature(class_getInstanceMethod(objc_getClass("SPTPlayerState"), restrictionsSelector), @encode(id), NULL);
    for (NSString *name in @[@"playbackId", @"contextURI"])
        compatible &= signature(class_getInstanceMethod(objc_getClass("SPTPlayerState"), NSSelectorFromString(name)), @encode(id), NULL);
    char encoding[16];
    compatible &= combined && method_getNumberOfArguments(combined) == 4;
    if (combined) {
        method_getReturnType(combined, encoding, sizeof(encoding)); compatible &= !strcmp(encoding, @encode(id));
        for (unsigned i = 2; i < 4; i++) {
            method_getArgumentType(combined, i, encoding, sizeof(encoding)); compatible &= !strcmp(encoding, @encode(id));
        }
    }
    compatible &= signature(class_getInstanceMethod(combinedRequest, getOptions), @encode(id), NULL) &&
        signature(class_getInstanceMethod(combinedRequest, setOptions), @encode(void), @encode(id));
    for (NSUInteger i = 0; i < 5; i++)
        compatible &= signature(class_getInstanceMethod(overrides, sel_registerName(optionNames[i])), @encode(id), NULL);
    for (NSUInteger i = 0; i < 3; i++) {
        combinedGetters[i] = class_getInstanceMethod(combinedRequest, sel_registerName(optionNames[i]));
        compatible &= signature(combinedGetters[i], @encode(id), NULL);
        reasons[i] = class_getInstanceMethod(restrictions, sel_registerName(reasonNames[i]));
        commands[i] = class_getInstanceMethod(player, sel_registerName(commandNames[i]));
        requests[i] = objc_getClass(requestNames[i]);
        setters[i] = class_getInstanceMethod(requests[i], sel_registerName(commandNames[i]));
        compatible &= signature(reasons[i], @encode(id), NULL) &&
            signature(commands[i], @encode(id), @encode(BOOL)) &&
            signature(setters[i], @encode(void), @encode(BOOL)) &&
            signature(class_getInstanceMethod(requests[i], getOptions), @encode(id), NULL) &&
            signature(class_getInstanceMethod(requests[i], setOptions), @encode(void), @encode(id));
    }
    SEL copySelector = @selector(copyWithZone:), serializeSelector = sel_registerName("serializedDictionary");
    Method copyMethod = class_getInstanceMethod(restrictions, copySelector);
    Method serializeMethod = class_getInstanceMethod(restrictions, serializeSelector);
    compatible &= signature(copyMethod, @encode(id), @encode(NSZone *)) &&
        signature(serializeMethod, @encode(id), NULL);
    // Install all three parts together, or leave Spotify alone.
    if (!compatible) { ASMVitrineLog(@"radio modes: unsupported player API; hooks inactive"); return; }
    // Filtering getters must not erase the raw reasons in Spotify's next state copy.
    asm_vitrine_copyRestrictions = (ASMVitrineRadioCopyIMP)method_getImplementation(copyMethod);
    class_replaceMethod(restrictions, copySelector, (IMP)ASMVitrineRadioCopyRestrictions, method_getTypeEncoding(copyMethod));
    id (*serialize)(id, SEL) = (void *)method_getImplementation(serializeMethod);
    IMP serializeHook = imp_implementationWithBlock(^id(id value) {
        BOOL previous = asm_vitrine_preserveReasons;
        asm_vitrine_preserveReasons = YES;
        @try { return serialize(value, serializeSelector); }
        @finally { asm_vitrine_preserveReasons = previous; }
    });
    class_replaceMethod(restrictions, serializeSelector, serializeHook, method_getTypeEncoding(serializeMethod));
    for (NSUInteger i = 0; i < 3; i++) {
        NSInteger mode = (NSInteger)i;
        SEL reasonSelector = sel_registerName(reasonNames[i]);
        SEL commandSelector = sel_registerName(commandNames[i]);
        id (*readReasons)(id, SEL) = (void *)method_getImplementation(reasons[i]);
        asm_vitrine_rawReasons[i] = readReasons;
        asm_vitrine_reasonSelectors[i] = reasonSelector;
        id (*sendCommand)(id, SEL, BOOL) = (void *)method_getImplementation(commands[i]);
        void (*fillRequest)(id, SEL, BOOL) = (void *)method_getImplementation(setters[i]);
        IMP reasonHook = imp_implementationWithBlock(^id(id value) {
            id original = readReasons(value, reasonSelector);
            if (asm_vitrine_preserveReasons || !ASMVitrineRadioModeReasonsOnly(original)) return original;
            dispatch_once(&asm_vitrine_radioReasonsReported[mode], ^{
                ASMVitrineLog(@"radio modes: %@ allows %@", NSStringFromSelector(reasonSelector), original);
            });
            return [NSSet set];
        });
        IMP commandHook = imp_implementationWithBlock(^id(id value, BOOL on) {
            NSArray *evidence = commandReasons(value, object(value, stateSelector));
            NSInteger previous = asm_vitrine_radioCommand;
            // Reason sets remain intact, including when Spotify copies its state.
            asm_vitrine_radioCommand = evidence && ASMVitrineRadioModeReasonsOnly(evidence[mode]) ? mode : -1;
            @try { return sendCommand(value, commandSelector, on); }
            @finally { asm_vitrine_radioCommand = previous; }
        });
        IMP requestHook = imp_implementationWithBlock(^(id value, BOOL on) {
            fillRequest(value, commandSelector, on);
            if (asm_vitrine_radioCommand != mode) return;
            allowRadioRequest(value, options);
            ASMVitrineLog(@"radio modes: %@ overrides radio/autoplay restrictions", NSStringFromSelector(commandSelector));
        });
        class_replaceMethod(restrictions, reasonSelector, reasonHook, method_getTypeEncoding(reasons[i]));
        class_replaceMethod(player, commandSelector, commandHook, method_getTypeEncoding(commands[i]));
        class_replaceMethod(requests[i], commandSelector, requestHook, method_getTypeEncoding(setters[i]));
    }
    Method stateMethod = class_getInstanceMethod(player, stateSelector);
    id (*readState)(id, SEL) = (void *)method_getImplementation(stateMethod);
    IMP stateHook = imp_implementationWithBlock(^id(id value) {
        id state = readState(value, stateSelector);
        commandReasons(value, state);
        return state;
    });
    class_replaceMethod(player, stateSelector, stateHook, method_getTypeEncoding(stateMethod));
    // The on-screen repeat button uses the combined options API (not setRepeatingTrack:).
    // It may change both repeat bits in one request. Reject an override for speed/modes,
    // for any non-radio restriction on a requested bit, or when no bit needs our help.
    id (*sendCombined)(id, SEL, id, id) = (void *)method_getImplementation(combined);
    IMP combinedHook = imp_implementationWithBlock(^id(id value, id changes, id logging) {
        NSInteger previous = asm_vitrine_radioCommand;
        asm_vitrine_radioCommand = -1;
        if ([changes isKindOfClass:overrides] && !object(changes, sel_registerName("playbackSpeed")) &&
            ![object(changes, sel_registerName("modes")) count]) {
            NSArray *evidence = commandReasons(value, object(value, stateSelector));
            BOOL allowed = evidence != nil, needed = NO;
            NSArray *names = @[@"shufflingContext", @"repeatingContext", @"repeatingTrack"];
            for (NSUInteger i = 0; allowed && i < 3; i++) {
                if (!object(changes, NSSelectorFromString(names[i]))) continue;
                id reasons = evidence[i];
                if (ASMVitrineRadioModeReasonsOnly(reasons)) needed = YES;
                else if (![reasons isKindOfClass:NSSet.class] || [reasons count]) allowed = NO;
            }
            if (allowed && needed) asm_vitrine_radioCommand = 3;
        }
        @try { return sendCombined(value, combinedSelector, changes, logging); }
        @finally { asm_vitrine_radioCommand = previous; }
    });
    class_replaceMethod(player, combinedSelector, combinedHook, method_getTypeEncoding(combined));
    // Spotify obtains each optional-boolean child and fills its value, without
    // calling the request's boolean setters or setOptions:. Attach command options
    // at those synchronous child accesses, before the request is dispatched.
    for (NSUInteger i = 0; i < 3; i++) {
        SEL selector = sel_registerName(optionNames[i]);
        id (*read)(id, SEL) = (void *)method_getImplementation(combinedGetters[i]);
        IMP hook = imp_implementationWithBlock(^id(id request) {
            if (asm_vitrine_radioCommand == 3) allowRadioRequest(request, options);
            return read(request, selector);
        });
        class_replaceMethod(combinedRequest, selector, hook, method_getTypeEncoding(combinedGetters[i]));
    }
    ASMVitrineLog(@"radio modes: shuffle and repeat enabled for radio/autoplay");
}
