#import <Foundation/Foundation.h>
#import <os/log.h>

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>.
#if ASMVitrine_DRIVER
// A build with the phone driver (FLEX builds, ASMVitrine_DRIVER in tweak/Makefile) also keeps the last lines in
// memory, for the driver's log and wait commands (Diagnostics/Driver.m).
#define ASMVitrineLog(fmt, ...) do { \
    NSString *asm_vitrine_log_line_ = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", asm_vitrine_log_line_.UTF8String); \
    ASMVitrineLogRemember(asm_vitrine_log_line_); \
} while (0)
void ASMVitrineLogRemember(NSString *line);
// The remembered lines numbered after `after`, oldest first, each {seq, t (seconds since 1970), text}.
NSArray<NSDictionary *> *ASMVitrineLogRecent(uint64_t after);
uint64_t ASMVitrineLogLastSeq(void);
#else
static inline void ASMVitrineLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
static inline void ASMVitrineLog(NSString *format, ...) {
    va_list args; va_start(args,format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[asm.vitrine] %{public}s", message.UTF8String);
}
#endif

// Long dumps, split into numbered parts under the unified log's size cap.
void ASMVitrineLogLong(NSString *tag, NSString *text);
// Logs every class of the list that this Spotify does not have; a feature calls it from its %ctor.
void ASMVitrineRequireClasses(NSArray<NSString *> *names);
