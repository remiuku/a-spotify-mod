// Keeps the areas the native look's tweaks stripped transparent when Spotify repaints them.
#import "Core/ASMSpotiCore.h"
#import "Repaint.h"

__weak UIView *asm_spotipw_lyricsCardRoot = nil;
__weak UIView *asm_spotipw_lyricsPageRoot = nil;
__weak UIView *asm_spotipw_homeRoot = nil;
__weak UIView *asm_spotipw_npvBackdropRoot = nil;

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (asm_spotipw_lyricsCardRoot || asm_spotipw_lyricsPageRoot || asm_spotipw_homeRoot || asm_spotipw_npvBackdropRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !ASMSpotiKeepsColor(view)) {
            if (ASMSpotiIsInside(view, asm_spotipw_lyricsCardRoot) || ASMSpotiIsInside(view, asm_spotipw_lyricsPageRoot)) {
                color = NULL;
            } else if (ASMSpotiIsInside(view, asm_spotipw_npvBackdropRoot)) {
                // The album colour arrives on the plane per track, outside any layout pass.
                color = NULL;
            } else if (ASMSpotiIsBaseSurface(color) && ASMSpotiIsInside(view, asm_spotipw_homeRoot)) {
                // Home keeps its cards and its placeholders; only the base surface the gradient
                // of Native/Home/HomeGradient.x sits behind goes.
                color = NULL;
            }
        }
    }
    %orig(color);
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiNativeUI()) return;
    %init;
}
