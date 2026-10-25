#import "Settings/ASMVitrineModPage.h"
#import "Privacy.h"

ASMVitrineModSection *ASMVitrinePrivacySection(void) {
    return ASMVitrineSection(@"Privacy", @[
        ASMVitrineWithSymbol(ASMVitrineSwitchRow(@"Block telemetry", @"Spotify's own events still go out, since Recents is built from them", ASMVitrineKeyBlockTelemetry), @"antenna.radiowaves.left.and.right.slash"),
        ASMVitrineWithSymbol(ASMVitrineSwitchRow(@"Clean shared links", @"Takes the tracking (si, utm) off the links you copy or share", ASMVitrineKeyCleanLinks), @"link"),
    ]);
}

ASMVitrineModSection *ASMVitrinePrivacyCountersSection(void) {
    NSMutableArray<ASMVitrineModRow *> *counts = [NSMutableArray array];
    for (NSString *label in ASMVitrineBlockedLabels()) {
        [counts addObject:ASMVitrineStatRow(label, ^NSString *{
            return @(ASMVitrineBlockedCount(label)).stringValue;
        })];
    }
    [counts addObject:ASMVitrineStatRow(@"Total", ^NSString *{
        return @(ASMVitrineBlockedCount(nil)).stringValue;
    })];
    [counts addObject:ASMVitrineActionRow(@"Reset the telemetry counters", nil, ^{ ASMVitrineResetBlocked(); })];
    return ASMVitrineSection(@"Telemetry blocked so far", counts);
}
