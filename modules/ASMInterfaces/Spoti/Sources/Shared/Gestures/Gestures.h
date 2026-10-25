// Double tap zones over the player's artwork: the artwork already answers a sideways swipe with the
// next track and a vertical drag with the cards below, so a double tap is what is left free.
#import <UIKit/UIKit.h>

#define ASMSpotiKeyGestures @"asm.interface.spotipw.gestures"
#define ASMSpotiKeyGestureSplit @"asm.interface.spotipw.gestures.split"
#define ASMSpotiKeyGestureStep @"asm.interface.spotipw.gestures.step"
#define ASMSpotiKeyGestureZones @"asm.interface.spotipw.gestures.zones"

typedef NS_ENUM(NSInteger, ASMSpotiGestureAction) {
    ASMSpotiGestureNothing = 0,
    ASMSpotiGestureSeekBack,
    ASMSpotiGestureSeekForward,
    ASMSpotiGesturePlayPause,
    ASMSpotiGestureNextTrack,
    ASMSpotiGesturePreviousTrack,
    ASMSpotiGestureShuffle,
    ASMSpotiGestureRepeat,
};

NSArray<NSString *> *ASMSpotiGestureActionNames(void);
NSArray<NSString *> *ASMSpotiGestureSplitNames(void);
NSArray<NSNumber *> *ASMSpotiGestureStepChoices(void);

// The split and the seek step as indices into the lists above, and what they mean.
NSInteger ASMSpotiGestureSplit(void);
NSInteger ASMSpotiGestureStepChoice(void);
// The split as a grid: 2x1, 3x1 or 3x3.
void ASMSpotiGestureGrid(NSInteger *columns, NSInteger *rows);
double ASMSpotiGestureStep(void);

// The action of every cell of the current split, row-major, one entry per cell.
NSArray<NSNumber *> *ASMSpotiGestureZones(void);
void ASMSpotiSetGestureZone(NSInteger cell, ASMSpotiGestureAction action);
void ASMSpotiResetGestureZones(void);
// Which cell of the current split holds `point`, in a view of size `size`.
NSInteger ASMSpotiGestureCellAt(CGPoint point, CGSize size);

UIViewController *ASMSpotiGesturesSettingsPage(void);

// Told of each action a double tap is about to perform, before the player has acted on it; one observer,
// for a look that answers the gesture (the redesign's haptics). Main thread.
void ASMSpotiGestureSetObserver(void (^observer)(ASMSpotiGestureAction action));

// Puts the double tap on `host`, the view the player's grid covers, while the switch is on; again on
// every layout pass of the host, so taps Spotify adds later still wait for it. Main thread.
void ASMSpotiGestureAttach(UIView *host);
