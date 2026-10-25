#include "SGDSPEngine.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>

enum { Frames = 48000 * 2, Chunk = 256 };
static float dry[2][Frames], wet[2][Frames];
static const double frequencies[15] = {25,40,63,100,160,250,400,630,1000,1600,2500,4000,6300,10000,16000};
static void render(SGDSPEngine *engine, float output[2][Frames]) {
    for (unsigned at = 0; at < Frames; at += Chunk) {
        unsigned n = Frames - at < Chunk ? Frames - at : Chunk;
        for (unsigned i = 0; i < n; i++) {
            double t = (at + i) / 48000.0;
            output[0][at+i] = .04 * sin(2*M_PI*100*t) + .03 * sin(2*M_PI*1000*t) + .02 * sin(2*M_PI*6000*t);
            output[1][at+i] = .02 * sin(2*M_PI*170*t) + .04 * sin(2*M_PI*1700*t);
        }
        SGDSPEngineProcess(engine, output[0]+at, output[1]+at, n);
    }
}
static void check(SGDSPEngine *engine, const char *name) {
    render(engine, wet);
    double difference = 0, reference = 0;
    for (int c=0; c<2; c++) for (int i=Frames/2; i<Frames; i++) {
        assert(isfinite(wet[c][i]));
        double delta = wet[c][i] - dry[c][i];
        difference += delta*delta;
        reference += dry[c][i]*dry[c][i];
    }
    double relative = sqrt(difference/reference);
    printf("%s: relative audio difference %.6f\n", name, relative);
    assert(relative > .005);
    assert(SGDSPEngineReadStats(engine, false).faults == 0);
    SGDSPEngineFree(engine);
}
int main(void) {
    SGDSPEngine *engine = SGDSPEngineCreate(48000);
    assert(engine);
    render(engine, dry);
    SGDSPEngineFree(engine);
    double gains[15]; for(int i=0;i<15;i++) gains[i]=-9;
    for (int filter=0; filter<6; filter++) {
        engine=SGDSPEngineCreate(48000);
        SGDSPEngineSetEqualizer(engine, true, filter, 0, frequencies, gains);
        check(engine,"15-band EQ");
    }
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetBassBoost(engine,true,15); check(engine,"bass");
    const double cf[7]={95,200,400,800,1600,3400,7500}, cg[7]={1,1,1,1,1,1,1};
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetCompander(engine,true,.22,2,0,cf,cg); check(engine,"compander");
    char error[300];
    engine=SGDSPEngineCreate(48000); assert(SGDSPEngineSetGraphicEq(engine,true,"GraphicEQ: 20 -9; 20000 -9;",error,sizeof error)); check(engine,"graphic EQ");
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetReverb(engine,true,4); check(engine,"reverb");
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetStereoWide(engine,true,75); check(engine,"width");
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetCrossfeed(engine,true,0); check(engine,"crossfeed");
    engine=SGDSPEngineCreate(48000); SGDSPEngineSetTube(engine,true,12); check(engine,"tube");
    engine=SGDSPEngineCreate(48000); assert(SGDSPEngineSetLiveprog(engine,true,"@init\nx=0;\n@sample\nspl0 *= 0.5; spl1 *= 0.5;",error,sizeof error)); check(engine,"Liveprog");
    engine=SGDSPEngineCreate(48000); assert(SGDSPEngineSetDDC(engine,true,"SR_44100:0.5,0,0,0,0\nSR_48000:0.5,0,0,0,0\n",error,sizeof error)); check(engine,"DDC");
    // A real WAV impulse with a delayed tap; exercise loading and convolution too.
    char path[]="/tmp/asm-impulse-XXXXXX.wav";
    int fd=mkstemps(path,4); assert(fd>=0);
    FILE *file=fdopen(fd,"wb"); assert(file);
    const uint32_t riff[]={36+4096*2,0x45564157,0x20746d66,16};
    const uint16_t format[]={1,1}; const uint32_t rate[]={48000,96000};
    const uint16_t align[]={2,16}; const uint32_t data[]={0x61746164,4096*2};
    fwrite("RIFF",1,4,file); fwrite(riff,1,sizeof riff,file); fwrite(format,1,sizeof format,file);
    fwrite(rate,1,sizeof rate,file); fwrite(align,1,sizeof align,file); fwrite(data,1,sizeof data,file);
    for(int i=0;i<4096;i++) { int16_t tap=i==0?16000:i==480?8000:0; fwrite(&tap,sizeof tap,1,file); }
    fclose(file);
    engine=SGDSPEngineCreate(48000); bool loaded=SGDSPEngineSetConvolver(engine,true,path,0,"-80;-100;0;0;0;0",error,sizeof error); if(!loaded) fprintf(stderr,"convolver: %s\n",error); assert(loaded); check(engine,"convolver");
    unlink(path);
    puts("PASS all tested DSP effects change actual audio samples");
}
