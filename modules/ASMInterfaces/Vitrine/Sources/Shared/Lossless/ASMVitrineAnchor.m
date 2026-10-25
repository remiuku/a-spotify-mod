#if ASMVitrine_DRIVER
#import <mach/mach_time.h>
#import "Core/ASMVitrineLog.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/SpeedPitch.h"
#import "Shared/Sing/Sing.h"
#import "Shared/Lyrics/Lyrics.h"
#import "ASMVitrineAnchor.h"

static ASMVitrineAnchorSample asm_vitrine_latest;
static BOOL asm_vitrine_haveSample;
static double asm_vitrine_tickSeconds;
static uint64_t asm_vitrine_session, asm_vitrine_sequence;
static BOOL asm_vitrine_enabled;

static NSString *field(NSString *value) {
    static NSCharacterSet *allowed;
    if (!allowed) allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:._-"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"-";
}

void ASMVitrineAnchorLog(NSString *kind, NSString *evidence, uint64_t epoch, uint64_t host) {
    if (!asm_vitrine_enabled) return;
    unsigned dropped;
    ASMVitrineAnchorSample sample;
    if (ASMVitrinePlayerAnchorRead(&sample, &dropped)) { asm_vitrine_latest = sample; asm_vitrine_haveSample = YES; }
    uint64_t before = mach_absolute_time();
    SPTPlayerState *state = ASMVitrinePlayerState();
    double position = state ? (state.isPaused ? state.positionAsOfTimestamp : state.position) : -1;
    double raw = state ? ASMVitrineSingSourcePosition(state) : -1;
    NSInteger karaoke = ASMVitrineKaraokePositionMs();
    double lead = ASMVitrineSingHeldLead(), correction = state ? ASMVitrineSingLeadOf(state) : 0;
    bool engaged;
    double latency = ASMVitrinePlayerAnchorLatency(&engaged);
    uint64_t after = mach_absolute_time();
    double control = ((double)before + (double)(after - before) / 2) * asm_vitrine_tickSeconds;
    double sampleTime = asm_vitrine_haveSample ? asm_vitrine_latest.host * asm_vitrine_tickSeconds : 0;
    ASMVitrineLog(@"lossless-anchor: v=1 session=%llu seq=%llu kind=%@ evidence=%@ event_host=%.6f event_epoch=%llu control_host=%.6f read_ms=%.3f epoch=%llu sample=%d sample_epoch=%llu output=%llu source_frame=%.0f frames=%u rate=%.0f host=%.6f age_ms=%.3f silent=%d status=%d dropped=%u uri=%@ karaoke_uri=%@ position_ms=%.3f raw_ms=%.3f asof_ms=%.3f stamp=%.3f karaoke_ms=%ld playing=%d paused=%d speed=%.6f pitch=%.3f follows=%d tp_engaged=%d tp_latency_ms=%.3f sing_on=%d sing_active=%d sing_state=%ld sing_lead_ms=%.3f sing_correction_ms=%.3f",
        (unsigned long long)asm_vitrine_session, (unsigned long long)++asm_vitrine_sequence, kind, evidence,
        host * asm_vitrine_tickSeconds, (unsigned long long)epoch, control, (after - before) * asm_vitrine_tickSeconds * 1000,
        (unsigned long long)ASMVitrinePlayerSourceEpoch(), asm_vitrine_haveSample, (unsigned long long)asm_vitrine_latest.epoch,
        (unsigned long long)asm_vitrine_latest.output, asm_vitrine_latest.sourceFrame, asm_vitrine_latest.frames, asm_vitrine_latest.rate,
        sampleTime, asm_vitrine_haveSample ? (control - sampleTime) * 1000 : -1, asm_vitrine_latest.silent, asm_vitrine_latest.status, dropped,
        field(ASMVitrineURIString(state.track.URI)), field(ASMVitrineKaraokePlayingTrack()), position * 1000, raw * 1000, state ? state.positionAsOfTimestamp * 1000 : -1,
        state.timestamp ? state.timestamp.timeIntervalSinceReferenceDate : 0, (long)karaoke,
        state.isPlaying, state.isPaused, ASMVitrinePlayerSpeed(), ASMVitrinePlayerPitch(), ASMVitrinePlayerPitchFollowsSpeed(), engaged, latency * 1000,
        ASMVitrineSingOn(), ASMVitrineSingAnchorStageActive(), (long)ASMVitrineSingCurrentState(), lead * 1000, correction * 1000);
}

__attribute__((constructor)) static void start(void) {
    return; // Host owns shared behavior.
    dispatch_async(dispatch_get_main_queue(), ^{
        // The compile flag follows FLEX packaging; the runtime check matches Sing's dev model slot.
        if (!NSClassFromString(@"FLEXManager")) return;
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        asm_vitrine_tickSeconds = (double)timebase.numer / timebase.denom / 1e9;
        asm_vitrine_session = mach_absolute_time();
        asm_vitrine_enabled = YES;
        ASMVitrineAnchorLog(@"start", @"diagnostic", ASMVitrinePlayerSourceEpoch(), asm_vitrine_session);
        static dispatch_source_t timer;
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_MSEC * 50);
        dispatch_source_set_event_handler(timer, ^{
            static double speed, pitch;
            static BOOL follows;
            double nextSpeed = ASMVitrinePlayerSpeed(), nextPitch = ASMVitrinePlayerPitch();
            BOOL nextFollows = ASMVitrinePlayerPitchFollowsSpeed();
            BOOL changed = speed && (nextSpeed != speed || nextPitch != pitch || nextFollows != follows);
            speed = nextSpeed; pitch = nextPitch; follows = nextFollows;
            if (changed) ASMVitrinePlayerInvalidateSource();
            ASMVitrineAnchorLog(changed ? @"speed_pitch" : @"sample", changed ? @"polled" : @"timer",
                        ASMVitrinePlayerSourceEpoch(), mach_absolute_time());
        });
        dispatch_resume(timer);
    });
}
#endif
