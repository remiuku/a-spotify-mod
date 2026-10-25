#import "ASMVitrineLog.h"
#import <os/lock.h>

#if ASMVitrine_DRIVER
// The last lines, for the phone driver. They come from any thread, so a lock, never the main queue.
static const NSUInteger kRemembered = 2000;
static os_unfair_lock asm_vitrine_logLock = OS_UNFAIR_LOCK_INIT;
static NSMutableArray<NSDictionary *> *asm_vitrine_logLines;
static uint64_t asm_vitrine_logSeq;

void ASMVitrineLogRemember(NSString *line) {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    os_unfair_lock_lock(&asm_vitrine_logLock);
    if (!asm_vitrine_logLines) asm_vitrine_logLines = [NSMutableArray array];
    [asm_vitrine_logLines addObject:@{@"seq" : @(++asm_vitrine_logSeq), @"t" : @(now), @"text" : line ?: @""}];
    if (asm_vitrine_logLines.count > kRemembered) [asm_vitrine_logLines removeObjectAtIndex:0];
    os_unfair_lock_unlock(&asm_vitrine_logLock);
}

NSArray<NSDictionary *> *ASMVitrineLogRecent(uint64_t after) {
    os_unfair_lock_lock(&asm_vitrine_logLock);
    NSIndexSet *newer = [asm_vitrine_logLines indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger i, BOOL *stop) {
        return [entry[@"seq"] unsignedLongLongValue] > after;
    }];
    NSArray<NSDictionary *> *lines = [asm_vitrine_logLines objectsAtIndexes:newer] ?: @[];
    os_unfair_lock_unlock(&asm_vitrine_logLock);
    return lines;
}

uint64_t ASMVitrineLogLastSeq(void) {
    os_unfair_lock_lock(&asm_vitrine_logLock);
    uint64_t seq = asm_vitrine_logSeq;
    os_unfair_lock_unlock(&asm_vitrine_logLock);
    return seq;
}
#endif

// The unified log cuts a message at about 1 KB, so long dumps go out as numbered parts.
void ASMVitrineLogLong(NSString *tag, NSString *text) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (current.length && [current lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + [line lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 900) {
            [parts addObject:[current copy]];
            [current setString:@""];
        }
        [current appendFormat:@"%@\n", line];
    }
    if (current.length) [parts addObject:current];
    [parts enumerateObjectsUsingBlock:^(NSString *part, NSUInteger i, BOOL *stop) {
        ASMVitrineLog(@"%@ %lu/%lu\n%@", tag, (unsigned long)i + 1, (unsigned long)parts.count, part);
    }];
}

void ASMVitrineRequireClasses(NSArray<NSString *> *names) {
    for (NSString *name in names) {
        if (!NSClassFromString(name)) ASMVitrineLog(@"class %@ not found, its hooks are inactive", name);
    }
}
