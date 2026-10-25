#import <Foundation/Foundation.h>
#import <os/log.h>

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>.
static inline void ASMSpotiLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static inline void ASMSpotiLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[asm.spotipw] %{public}s", message.UTF8String);
}

// Long dumps, split into numbered parts under the unified log's size cap.
void ASMSpotiLogLong(NSString *tag, NSString *text);
// Logs every class of the list that this Spotify does not have; a feature calls it from its %ctor.
void ASMSpotiRequireClasses(NSArray<NSString *> *names);
