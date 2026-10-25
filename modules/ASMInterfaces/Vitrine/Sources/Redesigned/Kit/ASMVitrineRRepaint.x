// Keeps the areas the redesign stripped transparent when Spotify repaints them, and learns which views
// could be the now playing bar's card from the album-color paint.
#import "Core/ASMVitrineCore.h"
#import "ASMVitrineRRepaint.h"

__weak UIView *asm_vitrine_r_nowPlayingRoot = nil;
NSHashTable<UIView *> *asm_vitrine_r_nowPlayingPainted = nil;
__weak UIView *asm_vitrine_r_lyricsPageRoot = nil;
__weak UIView *asm_vitrine_r_playlistRoot = nil;
__weak UIView *asm_vitrine_r_albumRoot = nil;
__weak UIView *asm_vitrine_r_artistRoot = nil;

%hook CALayer
- (void)setBackgroundColor:(CGColorRef)color {
    if (color && (asm_vitrine_r_nowPlayingRoot || asm_vitrine_r_lyricsPageRoot || asm_vitrine_r_playlistRoot || asm_vitrine_r_albumRoot || asm_vitrine_r_artistRoot)) {
        UIView *view = (UIView *)self.delegate;
        if ([view isKindOfClass:UIView.class] && view.layer == self && !ASMVitrineKeepsColor(view)) {
            if (ASMVitrineIsInside(view, asm_vitrine_r_nowPlayingRoot)) {
                // Its size is judged when the bar picks its card: Spotify can paint a card before it sizes it.
                if (ASMVitrineIsVisibleColor(color) && ![asm_vitrine_r_nowPlayingPainted containsObject:view]) {
                    [asm_vitrine_r_nowPlayingPainted addObject:view];
                    UIView *bar = asm_vitrine_r_nowPlayingRoot;
                    dispatch_async(dispatch_get_main_queue(), ^{ [bar.superview setNeedsLayout]; });
                }
                color = NULL;
            } else if (ASMVitrineIsInside(view, asm_vitrine_r_lyricsPageRoot)) {
                color = NULL;
            } else if (ASMVitrineIsBaseSurface(color) && (ASMVitrineIsInside(view, asm_vitrine_r_playlistRoot) || ASMVitrineIsInside(view, asm_vitrine_r_albumRoot) || ASMVitrineIsInside(view, asm_vitrine_r_artistRoot))) {
                color = NULL;
            }
        }
    }
    %orig(color);
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    %init;
}
