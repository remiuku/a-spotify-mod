// The player's Visualizer background (PlayerVisualiser.x) reads the sound through this: what Spotify's
// output plays, cut into ASMVitrineRSpectrumBands bands spaced evenly in pitch from kLowest to kHighest Hz (ASMVitrineRSpectrum.m),
// each band's level in dB, 0 dB being a full scale sine in it.
//
// Every 1024 samples the last 4096, through a Hann window and Accelerate's real FFT, are summed into the bands
// and published, so at 48 kHz about 47 times a second. Plain C, so harness/visualiser/ runs it on the Mac.
//
// Threading: ASMVitrineRSpectrumPrepare on the main thread, once, before anything is fed. ASMVitrineRSpectrumFeed on the render
// thread only, one thread at a time: it allocates nothing and takes no lock. ASMVitrineRSpectrumRead from any thread.
// What it reads can mix two analyses, a band from each, which nothing drawn can show.
#import <stdint.h>

enum { ASMVitrineRSpectrumBands = 24 };
// What a band reads with nothing in it, and the least ASMVitrineRSpectrumRead hands out.
#define ASMVitrineRSpectrumFloor (-100.0f)

// Makes the FFT's tables. Repeat calls do nothing. Lives as long as the process: the render thread may be in
// ASMVitrineRSpectrumFeed at any time.
void ASMVitrineRSpectrumPrepare(void);
// Samples, mono, at `sampleRate`. A new rate starts the window over. Does nothing before ASMVitrineRSpectrumPrepare.
void ASMVitrineRSpectrumFeed(const float *samples, uint32_t count, double sampleRate);
// The last levels into `levels`, low band first; answers how many analyses there have been, so a caller can
// tell when nothing new came (paused, or the tap never ran).
uint64_t ASMVitrineRSpectrumRead(float levels[ASMVitrineRSpectrumBands]);
