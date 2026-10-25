// The AirPods gestures page: the switch, a pull-down of what each gesture does, then fitting them to the
// user: the teaching sheet, the sensitivity, Try it, which listens a few seconds and names what it picked up
// in its own row without doing anything to the song, and Forget.
#import "Core/ASMVitrineCore.h"
#import "Settings/ASMVitrineModPage.h"
#import "Settings/ASMVitrinePageStyle.h"
#import "HeadGestures.h"

// Long enough to get the AirPods' attention and make a slow double nod.
static const double kTrySeconds = 6;

// ASMVitrineHeadAction's names, in its order.
static NSArray<NSString *> *actionNames(void) {
    return @[@"Nothing", @"Back 15 seconds", @"Forward 15 seconds", @"Play or pause", @"Next track", @"Previous track",
             @"Shuffle", @"Repeat", @"Like"];
}

static void say(NSString *title, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

static BOOL headTracking(void) {
    if (ASMVitrineHeadGesturesAvailable()) return YES;
    say(@"No head tracking", @"This iPhone cannot read the motion of headphones.");
    return NO;
}

static NSString *learnedValue(void) {
    BOOL nod = ASMVitrineInt(ASMVitrineKeyHeadNod, 0) > 0, shake = ASMVitrineInt(ASMVitrineKeyHeadShake, 0) > 0;
    return nod && shake ? @"Learned" : nod ? @"Nod learned" : shake ? @"Shake learned" : @"";
}

static BOOL anythingLearned(void) {
    return ASMVitrineInt(ASMVitrineKeyHeadNod, 0) > 0 || ASMVitrineInt(ASMVitrineKeyHeadShake, 0) > 0;
}

// Both learned sizes back to the defaults, asked first; `done` runs once they are.
static void forget(void (^done)(void)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Forget your nod and shake?"
        message:@"Both go back to the default sizes. You can teach them again." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Forget" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        ASMVitrineSetInt(ASMVitrineKeyHeadNod, 0);
        ASMVitrineSetInt(ASMVitrineKeyHeadShake, 0);
        ASMVitrineHeadGesturesSettingsChanged();
        done();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ASMVitrineTopController() presentViewController:alert animated:YES completion:nil];
}

static ASMVitrineModRow *actionRow(NSString *title, ASMVitrineHeadGesture gesture) {
    return ASMVitrineMenuRow(title, actionNames(), ^NSString *{ return actionNames()[(NSUInteger)ASMVitrineHeadGestureAction(gesture)]; },
                     ^(NSInteger index) { ASMVitrineSetHeadGestureAction(gesture, index); });
}

UIViewController *ASMVitrineHeadGesturesSettingsPage(void) {
    ASMVitrineModRow *toggle = ASMVitrineOptionRow(@"Head gestures", @"Nod twice or shake your head to control the music", ASMVitrineKeyHeadGestures);
    toggle.changed = ^(BOOL on) { ASMVitrineHeadGesturesSettingsChanged(); };

    ASMVitrineModRow *nodAction = ASMVitrineWithSymbol(actionRow(@"Nod twice", ASMVitrineHeadGestureDoubleNod), @"arrow.up.and.down");
    ASMVitrineModRow *shakeAction = ASMVitrineWithSymbol(actionRow(@"Shake your head", ASMVitrineHeadGestureShake), @"arrow.left.and.right");
    ASMVitrineModRow *chime = ASMVitrineWithSymbol(ASMVitrineSwitchRow(@"Chime on activation", nil, ASMVitrineKeyHeadChime), @"bell");

    __block __weak ASMVitrineModPage *page;
    ASMVitrineModRow *teach = ASMVitrineStatActionRow(@"Teach your gestures", @"Five of each, one after each tone", ^NSString *{ return learnedValue(); }, ^{
        if (!headTracking()) return;
        ASMVitrinePresentHeadGesturesTeaching(page, ^{ [page refreshVisibility]; });
    });

    ASMVitrineModRow *sensitivity = ASMVitrineSliderRow(@"Sensitivity", @"Higher counts a smaller move",
        ASMVitrineHeadSensitivityMin, ASMVitrineHeadSensitivityMax, ASMVitrineHeadSensitivityStep,
        ^double { return MAX(ASMVitrineHeadSensitivityMin, MIN(ASMVitrineHeadSensitivityMax, ASMVitrineInt(ASMVitrineKeyHeadSensitivity, 100))); },
        ^(double value) {
            ASMVitrineSetInt(ASMVitrineKeyHeadSensitivity, lround(value));
            ASMVitrineHeadGesturesSettingsChanged();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });

    // What the last try picked up, read out on its row until the next; a new page starts blank.
    __block NSString *tried = @"";
    __block BOOL trying = NO;
    ASMVitrineModRow *tryRow = ASMVitrineStatActionRow(@"Try it", @"Listens after the tone and says what it picked up", ^NSString *{ return tried; }, ^{
        if (trying || !headTracking()) return;
        trying = YES;
        tried = @"Listening…";
        [page.tableView reloadData];
        ASMVitrineHeadGesturesCue(ASMVitrineHeadCueReady);
        ASMVitrineHeadGesturesTry(kTrySeconds, ^(ASMVitrineHeadGesture gesture, BOOL heard) {
            trying = NO;
            tried = gesture == ASMVitrineHeadGestureDoubleNod ? @"Nod twice" : gesture == ASMVitrineHeadGestureShake ? @"Head shake" : heard ? @"Nothing" : @"No motion";
            ASMVitrineHeadGesturesCue(gesture != ASMVitrineHeadGestureNone ? ASMVitrineHeadCueWorked : ASMVitrineHeadCueFailed);
            NSString *spoken = gesture != ASMVitrineHeadGestureNone ? [@"Picked up: " stringByAppendingString:tried]
                             : heard ? @"Picked up nothing. Try a bigger move, or raise Sensitivity."
                                     : @"No motion came. Put in AirPods that track head motion.";
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, spoken);
            [page.tableView reloadData];
        });
    });

    ASMVitrineModRow *forgetRow = ASMVitrineActionRow(@"Forget what it learned", nil, ^{ forget(^{ [page refreshVisibility]; }); });
    forgetRow.color = ASMVitrineRed();
    forgetRow.visible = ^BOOL { return anythingLearned(); };
    for (ASMVitrineModRow *row in @[nodAction, shakeAction, chime, teach, sensitivity, tryRow, forgetRow]) row.waitsOn = ASMVitrineKeyHeadGestures;

    ASMVitrineModPage *shown = [[ASMVitrineModPage alloc] initWithTitle:@"AirPods gestures" intro:nil sections:@[
        ASMVitrineSection(nil, @[ASMVitrineWithSymbol(toggle, @"airpods.pro")]),
        ASMVitrineNotedSection(@"Gestures", @[nodAction, shakeAction, chime],
            @"They work while Spotify plays through headphones that track head motion: AirPods Pro, AirPods (3rd "
            "generation and later), AirPods Max and some Beats. Set to Play or pause, they listen with a song paused too. With the chime on, a "
            "tone in the music confirms each, a rising pair when it worked and a low one when it did not, with the "
            "iPhone on silent too. iOS asks once for Motion & Fitness access, which is how Spotify reads the movement."),
        ASMVitrineNotedSection(@"Fit to you", @[teach, sensitivity, tryRow, forgetRow],
            @"Teaching sets how big a move counts from five of your own. Sensitivity scales that for both. Try it does "
            "nothing to the music, so you can tune it while a song plays."),
    ] footer:nil];
    page = shown;
    return shown;
}
