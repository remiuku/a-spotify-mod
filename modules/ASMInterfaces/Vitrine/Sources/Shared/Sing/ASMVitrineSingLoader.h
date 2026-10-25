// Sing's voice model in memory (Sing.h): loaded, warmed, kept a minute after the mic goes off, and dropped.
//
// A copy on the CPU alone comes first, as it loads in seconds: once one prediction of silence has warmed it, the
// separator is Ready and Sing works. Then, while Spotify is in the foreground and the Neural Engine is asked for, a
// copy of the same model on the CPU and Neural Engine loads beside it, warms the same way and is handed to the
// separator, which runs the windows on it from then on, in the background too. Its first load compiles the model for
// the Neural Engine (32-46 s on an iPhone 15 Pro, after every install, as an install moves the app's container; then
// 0.4 s), so it has a deadline of its own; it loads only when the process has the memory left for it.
//
// Core ML cannot cancel a load, and on an iPhone 15 Pro one has never come back. So each load runs on a queue of its
// own, has a deadline, and is abandoned when the deadline passes or the model is dropped: abandoned, it is left to
// finish or hang where it is, and whatever it brings back later is let go. A CPU copy past its deadline makes Sing
// Failed until the mic is switched off and on; a Neural Engine copy past its deadline leaves Sing on the CPU's.
//
// Threading: main thread, but for ASMVitrineSingLoaderSeparator's separator, which the engine's worker runs.
#import <CoreML/CoreML.h>

@class ASMVitrineSingSeparator;

typedef NS_ENUM(NSInteger, ASMVitrineSingLoaderState) {
    ASMVitrineSingLoaderIdle,      // nothing loaded or loading
    ASMVitrineSingLoaderLoading,   // the CPU copy loading or warming
    ASMVitrineSingLoaderReady,     // the CPU copy warm: ASMVitrineSingLoaderSeparator separates
    ASMVitrineSingLoaderFailed,    // the CPU copy did not load (ASMVitrineSingLoaderError says why); stays so until a retry
};

// What became of the Neural Engine copy (the "fast" one).
typedef NS_ENUM(NSInteger, ASMVitrineSingFastState) {
    ASMVitrineSingFastNone,        // none asked for, or not yet started
    ASMVitrineSingFastLoading,
    ASMVitrineSingFastReady,
    ASMVitrineSingFastSkipped,     // too little memory for it
    ASMVitrineSingFastFailed,      // Core ML refused it, or its warm-up failed
    ASMVitrineSingFastTimedOut,    // past its deadline
};

// Run on the main thread whenever the state, the separator or the Neural Engine copy changes.
void ASMVitrineSingLoaderSetChanged(void (^changed)(void));
// Loads the model at `url` or joins the load already running, with a Neural Engine copy beside the CPU's when `neural`;
// without it, any Neural Engine copy is dropped. Another `url` than the last drops the copies of that one (and a
// Failed) first. Does nothing while Failed. Call it only while Spotify is in the foreground.
void ASMVitrineSingLoaderWant(NSURL *url, BOOL neural);
// Compiles the Neural Engine copy of `url` ahead of the mic, with nothing else loaded or loading and the memory for it,
// then lets it go: Core ML keeps the compiled form. A Neural Engine copy wanted meanwhile takes this load over. `done`
// runs on the main thread with whether it loaded, unless the copy wanted took it over. NO when it did not start.
BOOL ASMVitrineSingLoaderPrepareNeural(NSURL *url, void (^done)(BOOL loaded));
// Seconds the compile ahead of the mic has run, -1 when none runs (or the mic's copy took it over).
NSTimeInterval ASMVitrineSingLoaderPreparingSeconds(void);
// The model last wanted, nil before the first want.
NSURL *ASMVitrineSingLoaderURL(void);
// The mic is off: the copies are kept for ASMVitrineSingLoaderKeepSeconds, then dropped unless wanted again by then.
// Failed is cleared, so the next want is a fresh load whatever an abandoned one is still doing.
void ASMVitrineSingLoaderRelease(void);
// Both copies dropped at once and any load abandoned, `why` logged when there was something to drop.
void ASMVitrineSingLoaderPurge(NSString *why);
// The Neural Engine copy alone dropped, the CPU's kept.
void ASMVitrineSingLoaderDropFast(NSString *why);
// Spotify became active or stopped being active: a load starts only while it is, the Neural Engine copy's when it
// becomes so.
void ASMVitrineSingLoaderSetForeground(BOOL foreground);

ASMVitrineSingLoaderState ASMVitrineSingLoaderCurrentState(void);
// Whether the process has the memory left for a CPU copy (always, where the OS does not say).
BOOL ASMVitrineSingLoaderHasRoom(void);
// Nil until Ready.
ASMVitrineSingSeparator *ASMVitrineSingLoaderSeparator(void);
NSString *ASMVitrineSingLoaderError(void);
// Seconds since the CPU copy began loading, while Loading.
NSTimeInterval ASMVitrineSingLoaderSeconds(void);
ASMVitrineSingFastState ASMVitrineSingLoaderFastState(void);
// Seconds since the Neural Engine copy began loading, while it loads.
NSTimeInterval ASMVitrineSingLoaderFastSeconds(void);
// Loads started since launch, and loads not come back yet (abandoned ones with them), for the harness.
unsigned ASMVitrineSingLoaderAttempts(void);
unsigned ASMVitrineSingLoaderOutstanding(void);

// The deadlines (the Neural Engine copy's covers its first compile) and the minute kept, in seconds; changed only by the
// harness.
extern double ASMVitrineSingLoaderCPUDeadline, ASMVitrineSingLoaderNeuralDeadline, ASMVitrineSingLoaderKeepSeconds;
