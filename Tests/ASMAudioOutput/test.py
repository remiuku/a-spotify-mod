"""Exercise the actual read-only render tap with a minimal CoreAudio type shim."""
from pathlib import Path
import subprocess, tempfile

root=Path(__file__).resolve().parents[2]
source=(root/'Sources/EeveeSpotifyC/SpotiAudio/JamesDSP.m').read_text()
def function(name):
    start=source.rfind('\n',0,source.index(name+'('))+1
    begin=source.index('{',start)
    end,depth=begin+1,1
    while depth:
        depth+=(source[end]=='{')-(source[end]=='}')
        end+=1
    return source[start:end]

shim=r'''
#include <assert.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
typedef bool BOOL;
typedef uint32_t UInt32;
typedef int32_t OSStatus;
typedef uint32_t AudioUnitRenderActionFlags;
typedef struct {double unused;} AudioTimeStamp;
typedef struct {UInt32 mNumberChannels,mDataByteSize; void *mData;} AudioBuffer;
typedef struct {UInt32 mNumberBuffers; AudioBuffer mBuffers[2];} AudioBufferList;
typedef struct {double rate;} SGDSPEngine;
#define YES true
#define NO false
#define MIN(a,b) ((a)<(b)?(a):(b))
#define kScratchFrames 4096
#define kAudioFormatFlagIsFloat 1
#define kAudioFormatFlagIsNonInterleaved 32
#define kLinearPCMFormatFlagsSampleFractionShift 7
#define kLinearPCMFormatFlagsSampleFractionMask (63<<7)
#define kAudioUnitRenderAction_PostRender 8
#define kAudioUnitRenderAction_OutputIsSilence 16
#define noErr 0
typedef void (*ASMAudioOutputReader)(const float*,uint32_t,double);
static _Atomic(ASMAudioOutputReader) asm_outputReader;
static bool tempoEnabled;
static unsigned tempoCalls,tempoFrames;
static bool ASMTempoCaptureIsEnabled(void) {return tempoEnabled;}
static void ASMTempoCaptureProcess(const float *samples,uint32_t count,double rate) {
    assert(samples && count && rate==48000);tempoCalls++;tempoFrames+=count;
}
static float asm_mono[kScratchFrames];
static atomic_uint_fast64_t sg_layout,sg_rateBits;
static atomic_bool sg_running;
static _Atomic(SGDSPEngine*) sg_engine;
static unsigned processed;
static double SGDSPEngineSampleRate(SGDSPEngine *engine) {return engine->rate;}
static void processBuffer(SGDSPEngine *e,AudioUnitRenderActionFlags *f,UInt32 n,AudioBufferList*d) {
    (void)e;(void)f;(void)n;(void)d;processed++;
}
static unsigned calls,total;
static float expected;
static void receiver(const float *samples,uint32_t count,double rate) {
    assert(rate==48000);assert(count>0&&count<=4096);calls++;total+=count;
    for(unsigned i=0;i<count;i++) assert(samples[i]==expected);
}
static void format(uint32_t flags,uint32_t channels,uint32_t bytes) {
    atomic_store(&sg_layout,flags|((uint64_t)channels<<32)|((uint64_t)bytes<<48));
    double rate=48000;uint64_t bits;memcpy(&bits,&rate,8);atomic_store(&sg_rateBits,bits);
    calls=total=0;
}
'''
tests=r'''
int main(void) {
    float left[4097],right[4097];
    for(unsigned i=0;i<4097;i++){left[i]=1;right[i]=-.5f;}
    AudioBufferList data={2,{{1,sizeof(left),left},{1,sizeof(right),right}}};
    format(33,2,4);expected=.25f;
    readOutput(0,4097,&data);assert(calls==0);
    ASMSetAudioOutputReader(receiver);
    readOutput(0,4097,&data);assert(calls==2&&total==4097);
    for(unsigned i=0;i<4097;i++)assert(left[i]==1&&right[i]==-.5f);
    format(33,2,4);expected=0;readOutput(16,4097,&data);assert(total==4097);
    assert(left[0]==1&&right[0]==-.5f);
    int16_t interleaved[]={16384,-16384,16384,-16384};
    data=(AudioBufferList){1,{{2,sizeof(interleaved),interleaved}}};
    format(0,2,2);expected=0;readOutput(0,2,&data);assert(total==2);
    int16_t mono[]={16384,16384};
    data=(AudioBufferList){1,{{1,sizeof(mono),mono}}};
    format(0,1,2);expected=.5f;readOutput(0,2,&data);assert(total==2);
    int32_t fixed[]={1<<23,1<<23};
    data=(AudioBufferList){1,{{1,sizeof(fixed),fixed}}};
    format(24<<7,1,4);readOutput(0,2,&data);assert(total==2);
    format(24<<7,1,4);data.mBuffers[0].mDataByteSize--;readOutput(0,2,&data);assert(calls==0);
    data.mBuffers[0].mDataByteSize++;format(0,1,3);readOutput(0,2,&data);assert(calls==0);
    data=(AudioBufferList){2,{{1,sizeof(left),left},{1,sizeof(right),right}}};
    format(33,2,4);expected=.25f;
    AudioUnitRenderActionFlags flags=8;
    rendered(NULL,&flags,NULL,0,4097,&data);
    assert(total==4097&&processed==0); // tap works while DSP master is off
    SGDSPEngine engine={48000};atomic_store(&sg_engine,&engine);atomic_store(&sg_running,true);
    rendered(NULL,&flags,NULL,0,4097,&data);assert(processed==1);
    flags=0;unsigned previous=calls;rendered(NULL,&flags,NULL,0,4097,&data);assert(calls==previous);
    ASMSetAudioOutputReader(NULL);readOutput(0,4097,&data);assert(calls==previous);
    tempoEnabled=true;readOutput(0,4097,&data);assert(tempoCalls==2&&tempoFrames==4097&&calls==previous);
    ASMSetAudioOutputReader(receiver);readOutput(0,4097,&data);assert(tempoCalls==4&&calls==previous+2);
    assert(left[0]==1&&right[0]==-.5f); // both readers leave audio unchanged
    puts("PASS actual output tap: split/interleaved/mono/fixed PCM, 4097-frame chunking, silence, bounds, no audio writes, DSP-off reading and post-render ordering");
}
'''
with tempfile.TemporaryDirectory(prefix='asm-output-') as directory:
    path=Path(directory)
    (path/'test.c').write_text(shim+'\n'+'\n'.join(function(name) for name in ['ASMSetAudioOutputReader','loadDouble','readSample','readOutput','rendered'])+tests)
    subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror','-Wno-unused-parameter',str(path/'test.c'),'-o',str(path/'test')],check=True)
    subprocess.run([str(path/'test')],check=True)
