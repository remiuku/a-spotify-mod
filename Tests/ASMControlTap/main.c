#include "ASMControlTapPolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const uint64_t primary = UINT64_C(1) << 13, touchUp = UINT64_C(1) << 6;
    assert(ASMControlTapEvent(0, primary, touchUp) == 0);
    assert(ASMControlTapEvent(touchUp, primary, touchUp) == touchUp);
    assert(ASMControlTapEvent(primary, primary, touchUp) == primary);
    assert(ASMControlTapEvent(primary | touchUp, primary, touchUp) == primary);
    assert(ASMControlTapEvent(UINT64_MAX, primary, touchUp) == primary);
    assert(ASMControlTapEvent(UINT64_C(1) << 20, primary, touchUp) == 0);
    // A header UIButton can have both registrations but only its touch event
    // starts playback. The explicit button route prefers that single event;
    // a primary-only UIAction still works through the fallback.
    assert(ASMControlTapEvent(primary | touchUp, touchUp, primary) == touchUp);
    assert(ASMControlTapEvent(primary, touchUp, primary) == primary);
    assert(ASMControlTapEvent(touchUp, touchUp, primary) == touchUp);
    assert(ASMControlTapEvent(0, touchUp, primary) == 0);
    unsigned playCalls = 0, decorationCalls = 0;
    uint64_t event = ASMControlTapEvent(primary | touchUp, touchUp, primary);
    if (event & touchUp) playCalls++;
    if (event & primary) decorationCalls++;
    assert(playCalls == 1 && decorationCalls == 0);
    bool active = false;
    unsigned calls = 0;
    for (unsigned i = 0; i < 10000; i++) {
        assert(ASMControlTapBegin(&active)); calls++;
        for (unsigned nested = 0; nested < 100; nested++) assert(!ASMControlTapBegin(&active));
        ASMControlTapEnd(&active);
        assert(!active);
    }
    assert(calls == 10000);
    puts("PASS native tap policy: explicit button touch preference, primary-only fallback, one playback activation with dual registrations; generic primary preference and 10000 reentry cases retained");
}
