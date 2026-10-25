// The player menu's Speed and Pitch applied to sound: Apple's own time and pitch unit (AUNewTimePitch,
// the one behind AVAudioUnitTimePitch), which plays its input faster or slower at the same pitch (rate),
// and higher or lower at the same speed (semitones).
//
// It takes its input one of two ways:
//
// - Pulled from a source: the unit asks the source for about rate times the frames it hands back, so a
//   rate over 1 consumes the music faster. This is how speed works, the source being Spotify's mixer.
// - In place: the buffer is pushed into a FIFO and the unit pulled for as many frames as came in, rate 1
//   only. This is pitch alone on a finished buffer, when there is no source to pull.
//
// Measured on the Mac (harness/pitch): the pitch exact to 0.01% at any rate, the rate exact in frames
// consumed, about 0.2% of a core, and the sound 4096 frames (93 ms at 44.1 kHz) later than it went in.
//
// Plain C over audio units: ASMSpotiTimePitchRender and ASMSpotiTimePitchProcess run on Core Audio's render
// thread, so they never allocate, lock, log or send a message. The rest is for any other thread.
// Compiles on the Mac as is.
#import <AudioToolbox/AudioToolbox.h>
#import <stdbool.h>

enum { kSGTimePitchMaxChannels = 2, kSGTimePitchMaxFrames = 4096 };

typedef struct ASMSpotiTimePitch ASMSpotiTimePitch;

// Fills `data` (the unit's buffers, one per channel) with the next `frames` frames of input.
typedef OSStatus (*ASMSpotiTimePitchSource)(void *context, UInt32 frames, AudioBufferList *data);

// Float, non-interleaved, `channels` of them, at `sampleRate`, in buffers of up to kSGTimePitchMaxFrames
// frames. With a source it pulls from it, without one it works in place. NULL when the unit could not be
// made. Not on the render thread.
ASMSpotiTimePitch *ASMSpotiTimePitchCreate(double sampleRate, UInt32 channels, ASMSpotiTimePitchSource source, void *context);
double ASMSpotiTimePitchSampleRate(const ASMSpotiTimePitch *unit);
UInt32 ASMSpotiTimePitchChannels(const ASMSpotiTimePitch *unit);

// Any thread, taking effect with the next buffer. Rate 1 is normal speed (0.25...4); semitones up or down.
void ASMSpotiTimePitchSetRate(ASMSpotiTimePitch *unit, float rate);
void ASMSpotiTimePitchSetSemitones(ASMSpotiTimePitch *unit, float semitones);

// Forgets the sound held, so the next buffer starts over from silence. Only while nothing renders.
void ASMSpotiTimePitchReset(ASMSpotiTimePitch *unit);

// Pull mode: `frames` frames of output into `data`, float non-interleaved buffers of the unit's channels.
OSStatus ASMSpotiTimePitchRender(ASMSpotiTimePitch *unit, UInt32 frames, AudioBufferList *data);

// In place mode: replaces `frames` samples of each channel with the same sound moved in pitch, the unit's
// latency later. Returns false, leaving them as they were, when it cannot (too many frames, the unit failed).
bool ASMSpotiTimePitchProcess(ASMSpotiTimePitch *unit, float *const *channels, UInt32 frames);

// Diagnostics, read from any thread: pulls the FIFO could not fully answer, render errors, the unit's own
// delay in seconds, the most frames it asked its input for at once, and the input frames it consumed.
UInt32 ASMSpotiTimePitchUnderruns(const ASMSpotiTimePitch *unit);
UInt32 ASMSpotiTimePitchFailures(const ASMSpotiTimePitch *unit);
double ASMSpotiTimePitchLatency(const ASMSpotiTimePitch *unit);
UInt32 ASMSpotiTimePitchLargestPull(const ASMSpotiTimePitch *unit);
uint64_t ASMSpotiTimePitchConsumed(const ASMSpotiTimePitch *unit);
