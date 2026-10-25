#import "Settings/ASMSpotiModPage.h"
#import "Privacy.h"

ASMSpotiModSection *ASMSpotiPrivacySection(void) {
    return ASMSpotiSection(@"Privacy", @[
        ASMSpotiWithSymbol(ASMSpotiSwitchRow(@"Block telemetry", @"Spotify's own events still go out, since Recents is built from them", ASMSpotiKeyBlockTelemetry), @"antenna.radiowaves.left.and.right.slash"),
    ]);
}

ASMSpotiModSection *ASMSpotiPrivacyCountersSection(void) {
    NSMutableArray<ASMSpotiModRow *> *counts = [NSMutableArray array];
    for (NSString *label in ASMSpotiBlockedLabels()) {
        [counts addObject:ASMSpotiStatRow(label, ^NSString *{
            return @(ASMSpotiBlockedCount(label)).stringValue;
        })];
    }
    [counts addObject:ASMSpotiStatRow(@"Total", ^NSString *{
        return @(ASMSpotiBlockedCount(nil)).stringValue;
    })];
    [counts addObject:ASMSpotiActionRow(@"Reset the telemetry counters", nil, ^{ ASMSpotiResetBlocked(); })];
    return ASMSpotiSection(@"Telemetry blocked so far", counts);
}
