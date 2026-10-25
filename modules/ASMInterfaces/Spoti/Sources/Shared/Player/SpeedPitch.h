// Speed and pitch: two sliders in the more button's menu, done to Spotify's sound, under either look.
// Nothing here draws on a Spotify screen of its own: the block goes into Spotify's own context menu
// sheet, and the rest is audio.
//
//     SpeedPitchMenu.x   the expandable row and its two sliders, put into Spotify's context menu
//     SpeedPitch.x       speed and pitch done to Spotify's audio, between its mixer and its speaker unit
//     ASMSpotiTimePitch.m      Apple's time and pitch unit, pulling the mixer or working in place
//
// Speed and pitch last until Spotify quits; neither is stored.
// Threading: main thread only, except what ASMSpotiTimePitch.h says runs on the render thread.
#import <UIKit/UIKit.h>

// Marks a menu opened soon after a tap on `button`, the player's more button, as the player's, so it gets
// Speed and pitch (watching it twice does nothing). The redesign's PlayerHeader.x hands its button over;
// a menu presented from a now playing controller is taken for the player's without it, which is how the
// native look's player gets the block.
void ASMSpotiPlayerMenuWatchMoreButton(UIView *button);
// The speed Spotify's sound plays at, 1 when normal.
double ASMSpotiPlayerSpeed(void);
// Whether speed can apply: Spotify's output was taken over when it wired it.
BOOL ASMSpotiPlayerSpeedAllowed(void);
void ASMSpotiSetPlayerSpeed(double speed);
// Semitones Spotify's output is moved by, 0 when it is not.
float ASMSpotiPlayerPitch(void);
void ASMSpotiSetPlayerPitch(float semitones);
// Whether the output could be reached to change its pitch.
BOOL ASMSpotiPlayerPitchAvailable(void);
