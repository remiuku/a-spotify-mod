// Privacy: telemetry blocking (Privacy.x), an NSURLProtocol that answers the analytics endpoints
// itself and counts what it stopped. On unless switched off.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyBlockTelemetry @"asm.interface.spotipw.blockTelemetry"

// The destinations it knows in the order it lists them, and how many requests to one of them it
// has answered instead of letting out (nil label for all of them).
NSArray<NSString *> *ASMSpotiBlockedLabels(void);
NSUInteger ASMSpotiBlockedCount(NSString *label);
void ASMSpotiResetBlocked(void);

@class ASMSpotiModSection;
// The telemetry switch and what it has stopped, on the Premium, ads & privacy page.
ASMSpotiModSection *ASMSpotiPrivacySection(void);
ASMSpotiModSection *ASMSpotiPrivacyCountersSection(void);
