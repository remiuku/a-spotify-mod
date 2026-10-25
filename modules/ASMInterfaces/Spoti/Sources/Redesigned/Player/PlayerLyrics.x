#import "Core/ASMHost.h"
// Player redesign: the lyrics come to the player itself, the way the Music app shows them. The player
// is one screen and does not scroll (PlayerScroll.x), so the footer's lyrics glyph is the only way to
// them: it shrinks the cover into a thumbnail at the top of the artwork band, lifts the track's title
// up beside it, and fades the Apple Music style lines (Redesigned/Lyrics/ASMSpotiRKaraokeView.h) into the
// room that frees between the title and the progress bar. Tapping it again puts the cover back.
//
// Nothing of Spotify's is taken apart for it. The cover is the Kit's now playing artwork drawn again
// in a view of the redesign's own, flown from where Spotify's cover is drawn to where the thumbnail
// belongs, while Spotify's list of covers goes to alpha 0 underneath: one view to move instead of a
// paging list of them, and the two pictures are the same one, so the swap is not seen. The title row
// is Spotify's own unit translated, the way PlayerFooter.x moves the footer's controls -- a transform
// survives the stack view laying its arranged views out again -- with a mask over it where the controls
// it moved towards begin, so a long title fades out before them instead of running under them. The row
// of chips over it (Switch to video) goes while the lines are up, since they take the room it sits in.
//
// Tree (trees/clean/player/01.txt): SPTNowPlayingView (:26) holds the content layers, the header row
// (:91), and id=npv.bottomStackView {0, 576.67, 402, 236} (:127) whose arranged views are the
// information unit {0, 0, 402, 64} (:160, the title, the artist and the add button), the duration unit
// {0, 64, 402, 40} (:209), the controls (:240) and the footer (:295). The title is
// id=now-playing-title-label and the artist id=now-playing-subtitle-label (:174, :185), both inside one
// arranged element view {12, 2.33, 304, 43.33} of the unit's row. Every measurement here is taken from
// the views themselves, since a player with a volume row or another mode's units has other numbers.
//
// The geometry is re-applied on every layout pass of the units, since a new track rebuilds the
// elements inside them, and it is undone before the player closes: the bar morphs back into a full
// size cover, which a thumbnail would not match.
#import "Core/ASMSpotiCore.h"
#import "Redesigned/Kit/ASMSpotiRKit.h"
#import "Redesigned/Lyrics/ASMSpotiRKaraokeView.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Player.h"

static const CGFloat kThumbSide = 72;          // the cover once the lyrics are up
static const CGFloat kThumbGap = 16;           // between the thumbnail and the title beside it
static const CGFloat kTitleGap = 12;           // between the title and the controls at the trailing edge
static const CGFloat kTitleFade = 20;          // over how much of its end a title too long to fit fades out
static const CGFloat kThumbTop = 8;            // below the top of the artwork band
static const CGFloat kLyricsTop = 20;          // between the title row and the first line
static const CGFloat kLyricsBottom = 8;        // above the progress bar
// The lines are a surface arriving, not something moving: they come up from just under full size as the
// room for them opens, and go at once when it closes. An exit the eye waits through reads as a stall.
static const CGFloat kLyricsEnterScale = 0.96;
static const NSTimeInterval kLyricsIn = 0.3, kLyricsInDelay = 0.12, kLyricsOut = 0.16;
// A track that changes while the lines are up has this long to bring its own before they are put away.
static const NSTimeInterval kLyricsGrace = 3;
// Below this the player has not laid out yet and nothing can be measured from it.
static const CGFloat kLivingHeight = 200;

static char kOverlayKey, kPlateKey, kTitleKey;
static BOOL asm_spotipw_open;
static BOOL asm_spotipw_moving;                      // the transition is in flight, so no layout pass may re-place it
static __weak UIView *asm_spotipw_host;              // SPTNowPlayingView
static __weak UIViewController *asm_spotipw_info, *asm_spotipw_duration, *asm_spotipw_floating;
static __weak UIView *asm_spotipw_titleElement;      // the arranged element view holding the title and the artist

#pragma mark - the overlay

// The thumbnail and the lines, side by side under one view so the lines' own view has no sibling of
// ours to hide: ASMSpotiRKaraokeView takes the whole of whatever it is put in and dims what is next to it.
@interface ASMSpotiRPlayerLyricsOverlay : UIView
@property (nonatomic, readonly) UIView *thumb;       // the cover, at full size, moved by its transform
@property (nonatomic, readonly) UIImageView *cover;
@property (nonatomic, readonly) UIView *stage;       // holds the lines' view alone
@property (nonatomic, readonly) ASMSpotiRKaraokeView *lyrics;
@end

@implementation ASMSpotiRPlayerLyricsOverlay {
    UIView *_thumb, *_stage;
    UIImageView *_cover;
    ASMSpotiRKaraokeView *_lyrics;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _thumb = [[UIView alloc] initWithFrame:CGRectZero];
    _thumb.userInteractionEnabled = NO;
    _cover = [[UIImageView alloc] initWithFrame:CGRectZero];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.layer.cornerCurve = kCACornerCurveContinuous;
    _cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_thumb addSubview:_cover];
    _stage = [[UIView alloc] initWithFrame:CGRectZero];
    [self addSubview:_stage];
    [self addSubview:_thumb];
    return self;
}

- (UIView *)thumb { return _thumb; }
- (UIImageView *)cover { return _cover; }
- (UIView *)stage { return _stage; }

// The lines seek when they are tapped and the thumbnail takes no touches, so everywhere else the
// overlay would only swallow them: a view that takes touches does, even with nothing on it.
//
// What it hands them to instead is the title row. Translated to the top of the player it is drawn well
// outside the stack view it is arranged in, and UIKit stops looking at a view whose bounds the touch is
// not in, so the add button and the menu that rode up with it are past Spotify's own reach. Asked here
// directly, the row answers for where it is drawn.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit != self) return hit;
    UIView *row = ASMSpotiRPlayerLyricsOpen() ? asm_spotipw_info.viewIfLoaded : nil;
    UIView *inRow = row ? [row hitTest:[row convertPoint:point fromView:self] withEvent:event] : nil;
    return inRow == row ? nil : inRow;
}

// Made on the first tap and kept afterwards: it measures the song for its width before it can place a
// line, so a view built again on every tap would show nothing for the first frames. Out of the window
// it costs nothing -- its display link only runs while it is in one.
- (ASMSpotiRKaraokeView *)lyrics {
    if (!_lyrics) {
        _lyrics = [[ASMSpotiRKaraokeView alloc] initWithFrame:_stage.bounds];
        _lyrics.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    if (_lyrics.superview != _stage) [_stage addSubview:_lyrics];
    _lyrics.frame = _stage.bounds;
    return _lyrics;
}

@end

static ASMSpotiRPlayerLyricsOverlay *overlayIn(UIView *host) {
    ASMSpotiRPlayerLyricsOverlay *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (!overlay) {
        overlay = [[ASMSpotiRPlayerLyricsOverlay alloc] initWithFrame:host.bounds];
        objc_setAssociatedObject(host, &kOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // On top of the player: it reaches from under the header row down to the progress bar, so it is over
    // the covers and the gradients and clear of every control. Under them instead, the mixing background
    // Spotify keeps between the two (01.txt:72) would be free to draw over the lines.
    if (overlay.superview != host) [host addSubview:overlay];
    return overlay;
}

#pragma mark - the measurements

typedef struct {
    BOOL ok;
    CGRect cover;     // where Spotify draws the cover now, in the player
    CGRect thumb;     // where it goes
    CGRect stage;     // where the lines go
    CGFloat lift;     // how far the title row rises
    CGFloat shift;    // how far the title slides right to clear the thumbnail, 0 when it sits under it
} ASMSpotiRLyricsLayout;

// What a view's frame would be with the translation this file put on it left out.
static CGRect untransformed(UIView *view, UIView *host) {
    CGRect frame = ASMSpotiFrameIn(view, host);
    CGAffineTransform t = view.transform;
    return CGRectOffset(frame, -t.tx, -t.ty);
}

static ASMSpotiRLyricsLayout layoutIn(UIView *host) {
    ASMSpotiRLyricsLayout l = {0};
    UIView *info = asm_spotipw_info.viewIfLoaded, *duration = asm_spotipw_duration.viewIfLoaded, *title = asm_spotipw_titleElement;
    if (!host || host.bounds.size.height < kLivingHeight || !info || !duration) return l;
    CGRect area = ASMSpotiRPlayerArtworkAreaIn(host), cover = ASMSpotiRPlayerCoverFrameIn(host);
    if (CGRectIsNull(area) || CGRectIsNull(cover)) return l;
    CGRect row = untransformed(info, host), bar = untransformed(duration, host);
    // The thumbnail takes the title's own leading edge, so the two line up down the page.
    CGFloat leading = title ? CGRectGetMinX(untransformed(title, host)) : CGRectGetMinX(area) + ASMSpotiRSideMargin;
    l.cover = cover;
    l.thumb = CGRectMake(leading, CGRectGetMinY(area) + kThumbTop, kThumbSide, kThumbSide);
    // Beside the thumbnail when the title can be moved clear of it, under it when it cannot be found.
    CGFloat top = title ? CGRectGetMidY(l.thumb) - row.size.height / 2 : CGRectGetMaxY(l.thumb) + ASMSpotiRGrid;
    l.lift = top - CGRectGetMinY(row);
    l.shift = title ? kThumbSide + kThumbGap : 0;
    CGFloat lines = MAX(CGRectGetMaxY(l.thumb), top + row.size.height) + kLyricsTop;
    l.stage = CGRectMake(CGRectGetMinX(area), lines, area.size.width, CGRectGetMinY(bar) - kLyricsBottom - lines);
    l.ok = l.stage.size.height > kLivingHeight / 2 && l.lift < 0;
    return l;
}

#pragma mark - the title row

// Where the row's trailing controls start, in the unit's coordinates: the nearest arranged view on the
// trailing side of the title that is still there to be seen. The title may not reach it.
static CGFloat trailingEdgeIn(UIView *info) {
    UIView *title = asm_spotipw_titleElement, *row = title.superview;
    if (!title || !row) return CGFLOAT_MAX;
    CGFloat titleLeft = CGRectGetMinX(untransformed(title, info));
    CGFloat limit = CGRectGetMaxX(ASMSpotiFrameIn(row, info));
    for (UIView *view in row.subviews) {
        if (view == title || view.hidden || view.alpha < 0.01 || view.bounds.size.width < 1) continue;
        CGFloat x = CGRectGetMinX(ASMSpotiFrameIn(view, info));
        if (x > titleLeft && x < limit) limit = x;
    }
    return limit;
}

// The title moved right by the thumbnail would run into the add button beside it, and it cannot simply
// be narrowed: Spotify lays its marquee labels out with constraints, which put the width back the next
// time anything in the row lays out -- and a long title, being a marquee, lays out often. A mask on the
// element takes no part in that, so it holds between passes, and it fades the title out where Spotify's
// own fade would have been rather than cutting it.
static void clipTitle(UIView *element, CGFloat width) {
    CGRect bounds = element.bounds;
    if (width >= bounds.size.width - 0.5 || bounds.size.height < 1) {
        element.layer.mask = nil;
        return;
    }
    CAGradientLayer *mask = [element.layer.mask isKindOfClass:CAGradientLayer.class] ? (CAGradientLayer *)element.layer.mask : nil;
    if (!mask) {
        mask = [CAGradientLayer layer];
        mask.colors = @[(id)UIColor.whiteColor.CGColor, (id)UIColor.whiteColor.CGColor, (id)UIColor.clearColor.CGColor];
        mask.startPoint = CGPointMake(0, 0.5);
        mask.endPoint = CGPointMake(1, 0.5);
        element.layer.mask = mask;
    }
    CGFloat fade = MIN(kTitleFade, width);
    CGRect frame = CGRectMake(0, 0, MAX(0, width), bounds.size.height);
    if (CGRectEqualToRect(frame, mask.frame)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = frame;
    mask.locations = @[@0, @(width > 0 ? (width - fade) / width : 0), @1];
    [CATransaction commit];
}

// The unit's row lays its arranged views out after the unit's own pass, so the transforms go on after it.
static void placeTitleRow(ASMSpotiRLyricsLayout l) {
    UIView *info = asm_spotipw_info.viewIfLoaded;
    if (!info) return;
    [ASMSpotiRowIn(info) layoutIfNeeded];
    CGFloat lift = asm_spotipw_open ? l.lift : 0, shift = asm_spotipw_open ? l.shift : 0;
    CGAffineTransform rise = CGAffineTransformMakeTranslation(0, round(lift));
    if (!CGAffineTransformEqualToTransform(info.transform, rise)) info.transform = rise;
    UIView *title = asm_spotipw_titleElement;
    if (!title) return;
    CGAffineTransform slide = CGAffineTransformMakeTranslation(round(shift), 0);
    if (!CGAffineTransformEqualToTransform(title.transform, slide)) title.transform = slide;
    // Closed it reaches as far as Spotify meant it to; moved, only as far as the controls it moved towards.
    CGFloat room = CGFLOAT_MAX;
    if (asm_spotipw_open) room = trailingEdgeIn(info) - kTitleGap - (CGRectGetMinX(untransformed(title, info)) + shift);
    clipTitle(title, room);
}

#pragma mark - opening and closing

BOOL ASMSpotiRPlayerLyricsAvailable(void) {
    NSString *track = ASMSpotiKaraokePlayingTrack();
    return track != nil && ASMSpotiKaraokeLinesForTrack(track) != nil;
}

BOOL ASMSpotiRPlayerLyricsOpen(void) {
    return asm_spotipw_open;
}

// Puts the overlay's own views where the measurements say, without animating. The thumbnail is laid out
// at the size and place Spotify draws its cover at and moved by its transform alone, so a pass that
// runs while it is up leaves it exactly where the eye has it: the two are worked out from one
// measurement. Bounds and a centre, not a frame, since both views can be under a transform.
static void place(ASMSpotiRPlayerLyricsOverlay *overlay, UIView *host, ASMSpotiRLyricsLayout l) {
    overlay.frame = CGRectUnion(l.cover, CGRectUnion(l.thumb, l.stage));
    CGRect cover = [overlay convertRect:l.cover fromView:host], stage = [overlay convertRect:l.stage fromView:host];
    overlay.thumb.bounds = (CGRect){CGPointZero, cover.size};
    overlay.thumb.center = CGPointMake(CGRectGetMidX(cover), CGRectGetMidY(cover));
    overlay.cover.frame = overlay.thumb.bounds;
    ASMSpotiRShadowPlate *plate = ASMSpotiRShadowPlateIn(overlay.thumb, &kPlateKey);
    plate.bounds = overlay.thumb.bounds;
    plate.center = CGPointMake(CGRectGetMidX(overlay.thumb.bounds), CGRectGetMidY(overlay.thumb.bounds));
    overlay.stage.bounds = (CGRect){CGPointZero, stage.size};
    overlay.stage.center = CGPointMake(CGRectGetMidX(stage), CGRectGetMidY(stage));
}

// Where the thumbnail's view has to go to land on `l.thumb`, as a transform about its own centre: the
// shadow and the corners travel with it that way, instead of a shadow redrawn on every frame.
static CGAffineTransform thumbTransform(ASMSpotiRLyricsLayout l) {
    CGFloat scale = l.cover.size.width > 0 ? l.thumb.size.width / l.cover.size.width : 1;
    CGAffineTransform move = CGAffineTransformMakeTranslation(round(CGRectGetMidX(l.thumb) - CGRectGetMidX(l.cover)),
                                                             round(CGRectGetMidY(l.thumb) - CGRectGetMidY(l.cover)));
    return CGAffineTransformConcat(CGAffineTransformMakeScale(scale, scale), move);
}

// The corners as they will be drawn: a radius under a scale is drawn scaled, so the thumbnail asks for
// the radius it wants divided by the shrink, and the two ends of the animation are 12pt and 8pt corners.
static CGFloat thumbRadius(ASMSpotiRLyricsLayout l, BOOL open) {
    if (!open) return ASMSpotiRRadiusArtwork;
    CGFloat scale = l.cover.size.width > 0 ? l.thumb.size.width / l.cover.size.width : 1;
    return scale > 0 ? ASMSpotiRRadiusCover / scale : ASMSpotiRRadiusArtwork;
}

static void setOpen(BOOL open, BOOL animated) {
    UIView *host = asm_spotipw_host;
    if (open == asm_spotipw_open) return;
    if (!host) {
        ASMSpotiLog(@"redesign player: the lyrics were asked for before the player laid out");
        return;
    }
    ASMSpotiRLyricsLayout l = layoutIn(host);
    if (open && !l.ok) {
        ASMSpotiLog(@"redesign player: the lyrics have nowhere to go (stage %.0fx%.0f, lift %.0f)", l.stage.size.width, l.stage.size.height, l.lift);
        return;
    }
    // The thumbnail is the Kit's picture drawn again, and Spotify's cover goes as it appears: without a
    // picture there would be a hole where the cover was, so the cover stays and the lyrics wait.
    UIImage *picture = ASMSpotiRNowPlayingArtwork(NULL, NULL);
    if (open && !picture) {
        ASMSpotiLog(@"redesign player: no artwork read yet, the lyrics stay down");
        return;
    }
    asm_spotipw_open = open;
    ASMSpotiRPlayerLyricsChanged();

    ASMSpotiRPlayerLyricsOverlay *overlay = overlayIn(host);
    place(overlay, host, l);
    CGAffineTransform away = thumbTransform(l);
    // The state it starts from, so the animation has both ends of every value and nothing jumps into it.
    overlay.thumb.transform = open ? CGAffineTransformIdentity : away;
    overlay.cover.layer.cornerRadius = thumbRadius(l, !open);
    if (open) {
        overlay.cover.image = ASMSpotiRNowPlayingArtwork(NULL, NULL);
        overlay.stage.alpha = 0;
        overlay.stage.transform = CGAffineTransformMakeScale(kLyricsEnterScale, kLyricsEnterScale);
        [overlay lyrics];
        // Spotify's cover goes the moment the redesign's own takes its place: the same picture at the
        // same size with the same corners, so there is nothing to see in the swap. Coming back it waits
        // for the thumbnail to land on it, or the two would be on screen at once, one of them half size.
        ASMSpotiRPlayerCoverList().alpha = 0;
    }

    void (^move)(void) = ^{
        overlay.thumb.transform = open ? away : CGAffineTransformIdentity;
        overlay.cover.layer.cornerRadius = thumbRadius(l, open);
        placeTitleRow(l);
        asm_spotipw_floating.viewIfLoaded.alpha = open ? 0 : 1;
    };
    void (^show)(void) = ^{
        overlay.stage.alpha = open ? 1 : 0;
        overlay.stage.transform = open ? CGAffineTransformIdentity
                                       : CGAffineTransformMakeScale(kLyricsEnterScale, kLyricsEnterScale);
    };
    void (^settled)(BOOL) = ^(BOOL finished) {
        asm_spotipw_moving = NO;
        if (asm_spotipw_open) return;   // opened again while it was going away
        ASMSpotiRPlayerCoverList().alpha = 1;
        [overlay removeFromSuperview];
    };

    if (!animated) {
        move();
        show();
        settled(YES);
    } else {
        asm_spotipw_moving = YES;
        ASMSpotiRAnimate(ASMSpotiRMotionLayout, move, settled);
        // The lines come in behind the cover leaving, and go before it comes back.
        [UIView animateWithDuration:open ? kLyricsIn : kLyricsOut delay:open ? kLyricsInDelay : 0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:show completion:nil];
    }
    ASMSpotiLog(@"redesign player: lyrics %@, thumbnail %.0fx%.0f at %.0f,%.0f, title row up %.0f and right %.0f, lines %.0fx%.0f",
          open ? @"up" : @"away", l.thumb.size.width, l.thumb.size.height, l.thumb.origin.x, l.thumb.origin.y,
          -l.lift, l.shift, l.stage.size.width, l.stage.size.height);
}

void ASMSpotiRPlayerToggleLyrics(void) {
    if (!ASMSpotiRPlayerLyricsOpen() && ![ASMHostObject(@"renderer") isEqualToString:@"spotipw"]) { ASMHostAction(@"presentLyrics"); return; }

    if (!asm_spotipw_open && !ASMSpotiRPlayerLyricsAvailable()) return;
    setOpen(!asm_spotipw_open, YES);
}

// A layout pass, a new track or a turn of the phone: the state is put back where it belongs without
// animating, since the frames it is measured from have just changed.
static void replace(void) {
    UIView *host = asm_spotipw_host;
    if (!host || asm_spotipw_moving) return;   // a pass in the middle of the transition would cut it short
    ASMSpotiRLyricsLayout l = layoutIn(host);
    if (asm_spotipw_open && !l.ok) return;
    placeTitleRow(l);
    asm_spotipw_floating.viewIfLoaded.alpha = asm_spotipw_open ? 0 : 1;
    if (!asm_spotipw_open) return;
    ASMSpotiRPlayerLyricsOverlay *overlay = objc_getAssociatedObject(host, &kOverlayKey);
    if (!overlay.superview) return;
    place(overlay, host, l);
    overlay.thumb.transform = thumbTransform(l);
    overlay.cover.layer.cornerRadius = thumbRadius(l, YES);
    overlay.lyrics.frame = overlay.stage.bounds;
    ASMSpotiRPlayerCoverList().alpha = 0;
}

#pragma mark - the units

%hook _TtC19NowPlaying_ViewImpl24NowPlayingViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = ((UIViewController *)self).viewIfLoaded;
    if (!host || host.bounds.size.height < kLivingHeight) return;
    if (asm_spotipw_host != host) {
        asm_spotipw_host = host;
        ASMSpotiLog(@"redesign player: the lyrics have the player's view %.0fx%.0f", host.bounds.size.width, host.bounds.size.height);
    }
    replace();
}

// The bar morphs back out of a full size cover as the player closes, so the thumbnail is put away first.
- (void)viewWillDisappear:(BOOL)animated {
    if (asm_spotipw_open) setOpen(NO, NO);
    %orig;
}
%end

%hook _TtC20NowPlaying_ModesImpl23InformationElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    UIViewController *unit = (UIViewController *)self;
    asm_spotipw_info = unit;
    UIView *host = unit.viewIfLoaded;
    // The title and the artist are two labels of one arranged element view, which is what moves.
    UIView *label = ASMSpotiRFindByIdentifier(host, @"now-playing-title-label", &kTitleKey);
    UIView *element = nil;
    for (UIView *v = label; v && v != host; v = v.superview) {
        if ([v.superview isKindOfClass:UIStackView.class]) { element = v; break; }
    }
    if (element && asm_spotipw_titleElement != element) {
        asm_spotipw_titleElement = element;
        static dispatch_once_t once;
        dispatch_once(&once, ^{ ASMSpotiLog(@"redesign player: the title rides on %@ %@", NSStringFromClass(element.class), NSStringFromCGRect(element.frame)); });
    }
    replace();
}
%end

%hook _TtC20NowPlaying_ModesImpl19DurationElementUnit
- (void)viewDidLayoutSubviews {
    %orig;
    asm_spotipw_duration = (UIViewController *)self;
    replace();
}
%end

// The chips over the title (Switch to video and whatever else a track brings) sit in the middle of the
// room the lines take, so they go while the lines are up. The row keeps its height: the rest of the
// bottom stack stays where it was, which is the whole point of lifting only the title out of it.
%hook _TtC20NowPlaying_ModesImpl20FloatingElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    asm_spotipw_floating = (UIViewController *)self;
    replace();
}
%end

#pragma mark - the track changing under them

@interface ASMSpotiRPlayerLyricsWatcher : NSObject <ASMSpotiPlayerStateObserver>
@end

@implementation ASMSpotiRPlayerLyricsWatcher {
    NSString *_track;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = ASMSpotiURIString(state.track.URI);
    if (!track || [track isEqualToString:_track]) return;
    _track = track;
    // Lyrics arrive a moment after the track does, and nothing announces them: the glyph is asked again
    // while they would be coming, and the lines already up wait out the same grace before they go.
    for (NSNumber *delay in @[@1, @(kLyricsGrace)]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ASMSpotiRPlayerLyricsChanged();
            if (asm_spotipw_open && delay.doubleValue >= kLyricsGrace && !ASMSpotiRPlayerLyricsAvailable()) {
                ASMSpotiLog(@"redesign player: no lyrics for the track that came on, the cover is back");
                setOpen(NO, YES);
            }
        });
    }
}

@end

static ASMSpotiRPlayerLyricsWatcher *asm_spotipw_watcher;

%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiRedesignedUI()) return;
    %init;
    asm_spotipw_watcher = [ASMSpotiRPlayerLyricsWatcher new];
    ASMSpotiAddPlayerStateObserver(asm_spotipw_watcher);
    [NSNotificationCenter.defaultCenter addObserverForName:ASMSpotiRNowPlayingArtworkDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (!asm_spotipw_open) return;
        ASMSpotiRPlayerLyricsOverlay *overlay = objc_getAssociatedObject(asm_spotipw_host, &kOverlayKey);
        overlay.cover.image = ASMSpotiRNowPlayingArtwork(NULL, NULL);
    }];
    ASMSpotiRequireClasses(@[
        @"_TtC19NowPlaying_ViewImpl24NowPlayingViewController",
        @"_TtC20NowPlaying_ModesImpl23InformationElementsUnit",
        @"_TtC20NowPlaying_ModesImpl19DurationElementUnit",
        @"_TtC20NowPlaying_ModesImpl20FloatingElementsUnit",
    ]);
}
