// Keeps the areas the redesign stripped transparent when Spotify repaints them, and learns which view
// is the now playing bar's card from the album-colour paint.
#import "Core/ASMSpotiCore.h"
#import "ASMSpotiRRepaint.h"

__weak UIView *asm_spotipw_r_nowPlayingRoot = nil;
__weak UIView *asm_spotipw_r_nowPlayingCard = nil;
__weak UIView *asm_spotipw_r_lyricsPageRoot = nil;
__weak UIView *asm_spotipw_r_playlistRoot = nil;
__weak UIView *asm_spotipw_r_albumRoot = nil;
__weak UIView *asm_spotipw_r_artistRoot = nil;

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (asm_spotipw_r_nowPlayingRoot || asm_spotipw_r_lyricsPageRoot || asm_spotipw_r_playlistRoot || asm_spotipw_r_albumRoot || asm_spotipw_r_artistRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !ASMSpotiKeepsColor(view)) {
            if (ASMSpotiIsInside(view, asm_spotipw_r_nowPlayingRoot)) {
                if (ASMSpotiLooksLikeCard(view, color) && asm_spotipw_r_nowPlayingCard != view) {
                    asm_spotipw_r_nowPlayingCard = view;
                    UIView *bar = asm_spotipw_r_nowPlayingRoot;
                    dispatch_async(dispatch_get_main_queue(), ^{ [bar.superview setNeedsLayout]; });
                }
                color = NULL;
            } else if (ASMSpotiIsInside(view, asm_spotipw_r_lyricsPageRoot)) {
                color = NULL;
            } else if (ASMSpotiIsBaseSurface(color) && (ASMSpotiIsInside(view, asm_spotipw_r_playlistRoot) || ASMSpotiIsInside(view, asm_spotipw_r_albumRoot) || ASMSpotiIsInside(view, asm_spotipw_r_artistRoot))) {
                color = NULL;
            }
        }
    }
    %orig(color);
}
%end

%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiRedesignedUI()) return;
    %init;
}
