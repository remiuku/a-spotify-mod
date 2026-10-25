// Screen dumps for FLEX builds: the visible screen's view tree, served over the phone's loopback
// and logged when the app goes to the background.
#import <UIKit/UIKit.h>

BOOL ASMVitrineIsDebugBuild(void);
NSString *ASMVitrineScreenTree(void);
void ASMVitrineDumpScreen(NSString *reason);
// Runs `block` on the main thread and waits for it at most `timeout` seconds; for any thread but main,
// where it just runs the block. NO when main did not get to it in time (the block still runs later).
BOOL ASMVitrineRunOnMain(NSTimeInterval timeout, dispatch_block_t block);
// The app's SPTEsperantoPlayer, nil until something asked it for its state (PlayerState.x).
id ASMVitrineDiagnosticsPlayer(void);

#if ASMVitrine_DRIVER
// The phone driver (Driver.m): whether `command`, a request path without its slash, is one of its
// commands, and running one with the request's query items, answering JSON. Called off the main thread.
BOOL ASMVitrineDriverHandles(NSString *command);
NSData *ASMVitrineDriverRun(NSString *command, NSDictionary<NSString *, NSString *> *params);
// Defined in App/ModSettings.x: declared low, defined high.
void ASMVitrineOpenModSettings(UIView *source);
// Defined in Shared/Player/SpeedPitch.x.
double ASMVitrinePlayerSpeed(void);
void ASMVitrineSetPlayerSpeed(double speed);
// Defined in Shared/Sing/Sing.x.
void ASMVitrineSetSingOn(BOOL on);
// Defined in Redesigned/Player/PlayerLandscape.x: the landscape lyrics, for a Simulator that cannot turn.
void ASMVitrineRPlayerShowLandscape(BOOL show);
// Defined in Shared/Lossless/LosslessProbe.m: lossless anchor --path P, check, stop. Nil with *error on failure.
NSDictionary *ASMVitrineLosslessProbe(NSString *verb, NSDictionary *p, NSString **error);
// Defined in Shared/AutoMix/AutoMix.x: Spotify's Automix and Crossfade settings, read or written.
NSDictionary *ASMVitrineAutoMixProbeCommand(NSDictionary *p, NSString **error);
#endif
