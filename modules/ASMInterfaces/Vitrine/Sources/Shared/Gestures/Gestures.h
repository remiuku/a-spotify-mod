// Double tap zones over the player's artwork: the artwork already answers a sideways swipe with the
// next track and a vertical drag with the cards below, so a double tap is what is left free.
#import <UIKit/UIKit.h>

#define ASMVitrineKeyGestures @"asm.interface.vitrine.gestures"
#define ASMVitrineKeyGestureSplit @"asm.interface.vitrine.gestures.split"
#define ASMVitrineKeyGestureStep @"asm.interface.vitrine.gestures.step"
#define ASMVitrineKeyGestureZones @"asm.interface.vitrine.gestures.zones"

typedef NS_ENUM(NSInteger, ASMVitrineGestureAction) {
    ASMVitrineGestureNothing = 0,
    ASMVitrineGestureSeekBack,
    ASMVitrineGestureSeekForward,
    ASMVitrineGesturePlayPause,
    ASMVitrineGestureNextTrack,
    ASMVitrineGesturePreviousTrack,
    ASMVitrineGestureShuffle,
    ASMVitrineGestureRepeat,
};

NSArray<NSString *> *ASMVitrineGestureActionNames(void);
NSArray<NSString *> *ASMVitrineGestureSplitNames(void);
NSArray<NSNumber *> *ASMVitrineGestureStepChoices(void);

// The split and the seek step as indices into the lists above, and what they mean.
NSInteger ASMVitrineGestureSplit(void);
NSInteger ASMVitrineGestureStepChoice(void);
// The split as a grid: 2x1, 3x1 or 3x3.
void ASMVitrineGestureGrid(NSInteger *columns, NSInteger *rows);
double ASMVitrineGestureStep(void);

// The action of every cell of the current split, row-major, one entry per cell.
NSArray<NSNumber *> *ASMVitrineGestureZones(void);
void ASMVitrineSetGestureZone(NSInteger cell, ASMVitrineGestureAction action);
void ASMVitrineResetGestureZones(void);
// Which cell of the current split holds `point`, in a view of size `size`.
NSInteger ASMVitrineGestureCellAt(CGPoint point, CGSize size);

UIViewController *ASMVitrineGesturesSettingsPage(void);

// Told of each action a double tap is about to perform, before the player has acted on it; one observer,
// for a look that answers the gesture (the redesign's haptics). Main thread.
void ASMVitrineGestureSetObserver(void (^observer)(ASMVitrineGestureAction action));

// Puts the double tap on `host`, the view the player's grid covers, while the switch is on; again on
// every layout pass of the host, so taps Spotify adds later still wait for it. Main thread.
void ASMVitrineGestureAttach(UIView *host);
