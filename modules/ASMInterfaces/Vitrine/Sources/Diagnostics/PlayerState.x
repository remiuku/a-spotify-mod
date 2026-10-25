// Debug builds only: the player the driver reads its state from (Driver.m).
#import "Core/ASMVitrineCore.h"
#import "Diagnostics.h"
#import "Headers/SPTPlayer.h"

static __weak id asm_vitrine_player;

id ASMVitrineDiagnosticsPlayer(void) {
    return asm_vitrine_player;
}

%hook SPTEsperantoPlayer
- (id)state {
    asm_vitrine_player = self;
    return %orig;
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineIsDebugBuild()) return;
    %init;
    ASMVitrineRequireClasses(@[@"SPTEsperantoPlayer"]);
}
