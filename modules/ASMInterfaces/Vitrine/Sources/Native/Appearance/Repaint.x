// Keeps the areas the native look's tweaks stripped transparent when Spotify repaints them.
#import "Core/ASMVitrineCore.h"
#import "Repaint.h"

__weak UIView *asm_vitrine_lyricsCardRoot = nil;
__weak UIView *asm_vitrine_lyricsPageRoot = nil;
__weak UIView *asm_vitrine_homeRoot = nil;
__weak UIView *asm_vitrine_npvBackdropRoot = nil;

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (asm_vitrine_lyricsCardRoot || asm_vitrine_lyricsPageRoot || asm_vitrine_homeRoot || asm_vitrine_npvBackdropRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !ASMVitrineKeepsColor(view)) {
            if (ASMVitrineIsInside(view, asm_vitrine_lyricsCardRoot) || ASMVitrineIsInside(view, asm_vitrine_lyricsPageRoot)) {
                color = NULL;
            } else if (ASMVitrineIsInside(view, asm_vitrine_npvBackdropRoot)) {
                // The album color arrives on the plane per track, outside any layout pass.
                color = NULL;
            } else if (ASMVitrineIsBaseSurface(color) && ASMVitrineIsInside(view, asm_vitrine_homeRoot)) {
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

    if (!ASMVitrineNativeUI()) return;
    %init;
}
