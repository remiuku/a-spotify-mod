// The Live Activity page (App/ModSettings.x links it from the root, under either look).
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "LiveActivity.h"

static NSArray<NSString *> *viewNames(void) {
    return @[@"Lyrics", @"Queue", @"Control menu"];
}

UIViewController *ASMSpotiLiveActivitySettingsPage(void) {
    ASMSpotiModRow *on = ASMSpotiOptionRow(@"Live Activity", nil, ASMSpotiKeyLiveActivity);
    on.changed = ^(BOOL value) { ASMSpotiSetLiveActivityEnabled(value); };
    ASMSpotiModRow *view = ASMSpotiChoiceRow(@"Shows", nil, ASMSpotiKeyLiveActivityView, viewNames(), ASMSpotiLiveActivityLyrics);
    return [[ASMSpotiModPage alloc] initWithTitle:@"Live Activity" intro:nil sections:@[
        ASMSpotiSection(nil, @[on, view]),
    ] footer:nil];
}

NSString *ASMSpotiLiveActivitySummary(void) {
    if (!ASMSpotiFlag(ASMSpotiKeyLiveActivity, NO)) return @"Off";
    NSInteger index = ASMSpotiInt(ASMSpotiKeyLiveActivityView, ASMSpotiLiveActivityLyrics);
    NSArray<NSString *> *names = viewNames();
    return index >= 0 && index < (NSInteger)names.count ? names[index] : names.firstObject;
}
