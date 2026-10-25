#import "ASMVitrinePCMReplacement.h"
#import <stdatomic.h>
#import <pthread.h>
#include <math.h>

typedef struct Snapshot {
    CFTypeRef owner;
    const float *left, *right;
    AudioUnit output;
    double rate;
    uint64_t epoch, sourceFrame, assetFrame, length;
    struct Snapshot *next;
} Snapshot;

static _Atomic(Snapshot *) asm_vitrine_active;
static atomic_uint asm_vitrine_readers;
static atomic_uint_fast64_t asm_vitrine_replaced;
static pthread_mutex_t asm_vitrine_control = PTHREAD_MUTEX_INITIALIZER; // never acquired on render
static Snapshot *asm_vitrine_retired;
static unsigned asm_vitrine_retiredCount;
static BOOL asm_vitrine_reclaimScheduled;

static void reclaim(void) {
    // Sequential consistency is required: a reader increments before loading active; a writer
    // exchanges active before checking readers. A future reader can only see the new snapshot.
    if (atomic_load(&asm_vitrine_readers)) return;
    while (asm_vitrine_retired) {
        Snapshot *old = asm_vitrine_retired; asm_vitrine_retired = old->next;
        CFRelease(old->owner); free(old); --asm_vitrine_retiredCount;
    }
}
static void scheduleReclaim(void) {
    if (asm_vitrine_reclaimScheduled || !asm_vitrine_retired) return;
    asm_vitrine_reclaimScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_MSEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        pthread_mutex_lock(&asm_vitrine_control);
        asm_vitrine_reclaimScheduled = NO;
        reclaim(); scheduleReclaim();
        pthread_mutex_unlock(&asm_vitrine_control);
    });
}
static void retire(Snapshot *old) {
    if (old) { old->next = asm_vitrine_retired; asm_vitrine_retired = old; ++asm_vitrine_retiredCount; }
    reclaim(); scheduleReclaim();
}
void ASMVitrinePCMReplacementEnable(void) { ASMVitrinePlayerSetSourceSelector(ASMVitrinePCMReplacementApply); }
BOOL ASMVitrinePCMReplacementInstall(ASMVitrinePreparedPCM *asset, AudioUnit output, uint64_t epoch,
                             uint64_t sourceFrame, uint64_t assetFrame) {
    if (!asset || !output || !epoch || assetFrame >= asset.frameCount || sourceFrame >= (1ULL<<53)) return NO;
    pthread_mutex_lock(&asm_vitrine_control);
    reclaim();
    if (epoch != ASMVitrinePlayerSourceEpoch() || asm_vitrine_retiredCount >= 2) { pthread_mutex_unlock(&asm_vitrine_control); return NO; }
    Snapshot *next = calloc(1, sizeof(*next));
    if (!next) { pthread_mutex_unlock(&asm_vitrine_control); return NO; }
    next->owner = CFBridgingRetain(asset);
    next->left = asset.left; next->right = asset.right; next->length = asset.frameCount;
    next->rate = asset.sampleRate; next->output = output; next->epoch = epoch;
    next->sourceFrame = sourceFrame; next->assetFrame = assetFrame;
    retire(atomic_exchange(&asm_vitrine_active, next));
    pthread_mutex_unlock(&asm_vitrine_control);
    return YES;
}
void ASMVitrinePCMReplacementCancel(void) {
    pthread_mutex_lock(&asm_vitrine_control);
    ASMVitrinePlayerInvalidateSource();
    retire(atomic_exchange(&asm_vitrine_active, NULL));
    pthread_mutex_unlock(&asm_vitrine_control);
}
uint64_t ASMVitrinePCMReplacementFrames(void) { return atomic_load(&asm_vitrine_replaced); }
void ASMVitrinePCMReplacementApply(AudioUnit output, uint64_t epoch, double sourceFrame,
                           double sampleRate, UInt32 frames, AudioBufferList *data) {
    atomic_fetch_add(&asm_vitrine_readers, 1);
    Snapshot *s = atomic_load(&asm_vitrine_active);
    if (!s || !frames || !data || data->mNumberBuffers != 2 || output != s->output || epoch != s->epoch
        || epoch != ASMVitrinePlayerSourceEpoch() || sampleRate != s->rate || !isfinite(sourceFrame)
        || sourceFrame < s->sourceFrame || sourceFrame >= (double)(1ULL<<53) || floor(sourceFrame) != sourceFrame) goto done;
    uint64_t delta = (uint64_t)sourceFrame - s->sourceFrame;
    if (delta > s->length - s->assetFrame || frames > s->length - s->assetFrame - delta) goto done;
    for (UInt32 b = 0; b < 2; ++b) {
        if (!data->mBuffers[b].mData || data->mBuffers[b].mNumberChannels != 1
            || data->mBuffers[b].mDataByteSize / sizeof(float) < frames) goto done;
    }
    uint64_t at = s->assetFrame + delta;
    memcpy(data->mBuffers[0].mData, s->left+at, frames*sizeof(float));
    memcpy(data->mBuffers[1].mData, s->right+at, frames*sizeof(float));
    atomic_fetch_add(&asm_vitrine_replaced, frames);
done:
    atomic_fetch_sub(&asm_vitrine_readers, 1);
}
