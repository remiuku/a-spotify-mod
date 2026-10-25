// The action row's controls: the Play capsule and the button that stands in for one of Spotify's.
//
// Both are drawn from what Spotify's own button shows, and neither keeps state of its own. The glyph is
// looked for past what is hidden behind it -- a play button's glow ring is a hidden view holding an image
// of its own, and taken for the glyph it put a soft green ring in the capsule (device, 2026-09-17) -- and
// it is watched afterward, because Spotify swaps play for pause without laying the header out again.
#import "Core/ASMVitrineCore.h"
#import "ASMVitrineRActionRow.h"
#import "ASMVitrineRGlass.h"
#import "ASMVitrineRRestyle.h"
#import "ASMVitrineRTokens.h"
#import "ASMVitrineRAccent.h"
#import "ASMVitrineRDownload.h"

// The capsule: the glyph is Spotify's own 48pt canvas with the triangle small in the middle of it, so the
// lead is short and the gap to the word comes out of the canvas itself.
static const CGFloat kGlyphSide = 44, kCapsuleLead = 4, kCapsuleTrail = 20;
// The mirrored glyph, the size Spotify draws one inside a 48pt round button.
static const CGFloat kMirrorGlyph = 24;

static char kCapsuleGlassKey, kMirrorGlassKey;

// The glyph Spotify's button draws: an image view of the button's own size that nothing hidden is in the
// way of. `side` is the size to match, 0 for any image view that is showing.
static UIImageView *glyphIn(UIView *button, CGFloat side) {
    __block UIImageView *glyph = nil;
    ASMVitrineForEachView(button, ^(UIView *v) {
        if (glyph || ![v isKindOfClass:UIImageView.class] || !((UIImageView *)v).image) return;
        if (side > 0 && (fabs(v.bounds.size.width - side) > 2 || fabs(v.bounds.size.height - side) > 2)) return;
        for (UIView *up = v; up && up != button; up = up.superview) {
            if (up.hidden || up.alpha <= 0.01) return;
        }
        glyph = (UIImageView *)v;
    });
    return glyph;
}

static NSString *wordIn(UIView *button) {
    __block NSString *word = nil;
    ASMVitrineForEachView(button, ^(UIView *v) {
        if (!word && v.accessibilityLabel.length) word = v.accessibilityLabel;
    });
    return word;
}

#pragma mark - the Play capsule

@implementation ASMVitrineRPlayCapsule {
    UIImageView *_glyph;
    UILabel *_title;
    __weak UIImageView *_watchedGlyph;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _glyph = [UIImageView new];
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _glyph.userInteractionEnabled = NO;
    [self addSubview:_glyph];

    _title = [UILabel new];
    _title.userInteractionEnabled = NO;
    [self addSubview:_title];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(asm_vitrine_r_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(asm_vitrine_r_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(asm_vitrine_r_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (CGFloat)asm_vitrine_r_width {
    [_title sizeToFit];
    return kCapsuleLead + kGlyphSide + ceil(_title.bounds.size.width) + kCapsuleTrail;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    if (self.fillColor) {
        if (![self.backgroundColor isEqual:self.fillColor]) self.backgroundColor = self.fillColor;
        self.layer.cornerRadius = bounds.size.height / 2;
        self.layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        ASMVitrineRGlassCapsuleInside(self, &kCapsuleGlassKey, bounds.size, YES);
    }
    // Given more room than the word asks for, the glyph and the word stay together in the middle.
    CGFloat lead = kCapsuleLead + MAX(0, round((bounds.size.width - [self asm_vitrine_r_width]) / 2));
    _glyph.frame = CGRectMake(lead, round((bounds.size.height - kGlyphSide) / 2), kGlyphSide, kGlyphSide);
    // Spotify's glyph comes on a 48pt canvas and is scaled down into the frame; one drawn tight is shown at
    // its own size instead of blown up to fill it.
    CGSize image = _glyph.image.size;
    UIViewContentMode mode = image.width <= kGlyphSide && image.height <= kGlyphSide ? UIViewContentModeCenter : UIViewContentModeScaleAspectFit;
    if (_glyph.contentMode != mode) _glyph.contentMode = mode;
    [_title sizeToFit];
    CGSize text = _title.bounds.size;
    _title.frame = CGRectMake(CGRectGetMaxX(_glyph.frame), round((bounds.size.height - text.height) / 2),
                              MAX(0, bounds.size.width - kCapsuleTrail - CGRectGetMaxX(_glyph.frame)), text.height);
}

- (void)feedFrom:(UIView *)source {
    if (!source) return;
    _source = source;

    NSString *word = wordIn(source);
    // The disc is as tall as the button, not always as wide: Liked Songs' is 80x48 with the 48pt disc at
    // x=16 (trees/continuous/1.txt, 2026-09-18), and matched by width the capsule drew no glyph at all.
    CGSize size = source.bounds.size;
    UIImageView *glyph = glyphIn(source, MIN(size.width, size.height));

    UIFont *font = ASMVitrineRFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, UIContentSizeCategoryLarge);
    if (![_title.font isEqual:font]) _title.font = font;
    UIColor *content = self.contentColor ?: ASMVitrineRAccent();
    if (![_title.textColor isEqual:content]) _title.textColor = content;
    if (word && ![_title.text isEqualToString:word]) {
        _title.text = word;
        self.accessibilityLabel = word;
        [self setNeedsLayout];
        // The header sizes the capsule to its word ("Play", "Shuffle Play" with shuffle on).
        [self.superview setNeedsLayout];
    }
    if (![_glyph.tintColor isEqual:content]) _glyph.tintColor = content;

    if (glyph.image && _glyph.image != glyph.image) {
        _glyph.image = [glyph.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            ASMVitrineLog(@"redesign kit: play glyph %@ from %@, word \"%@\"", NSStringFromCGSize(glyph.image.size),
                  NSStringFromClass(glyph.class), word);
        });
    }
    // Play becomes pause without the header laying out again. Watched per glyph view rather than once for
    // good, so a glyph Spotify hands to another button reports to the button it is in now.
    if (glyph && glyph != _watchedGlyph) {
        _watchedGlyph = glyph;
        __weak ASMVitrineRPlayCapsule *weakSelf = self;
        __weak UIView *weakSource = source;
        ASMVitrineRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)asm_vitrine_r_down {
    ASMVitrineRAnimate(ASMVitrineRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.94, 0.94); }, nil);
}

- (void)asm_vitrine_r_up {
    ASMVitrineRAnimate(ASMVitrineRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)asm_vitrine_r_tap {
    ASMVitrineRActivate(self.source);
}

@end

#pragma mark - a button standing in for Spotify's

// Whether a button that marks "on" with a small dot under its glyph (Encore's shuffle, a 4pt round view it
// hides while off) is on. `found` says whether the button has such a dot at all.
static BOOL indicatorOn(UIView *button, BOOL *found) {
    __block UIView *dot = nil;
    ASMVitrineForEachView(button, ^(UIView *v) {
        if (dot || v == button || [v isKindOfClass:UIImageView.class] || [v isKindOfClass:UILabel.class]) return;
        CGSize size = v.bounds.size;
        if (size.width < 2 || size.width > 8 || size.height < 2 || size.height > 8) return;
        CGColorRef paint = v.layer.backgroundColor;
        if (paint && CGColorGetAlpha(paint) > 0.5) dot = v;
    });
    if (found) *found = dot != nil;
    for (UIView *up = dot; up && up != button; up = up.superview) {
        if (up.hidden || up.alpha <= 0.01) return NO;
    }
    return dot != nil;
}

@implementation ASMVitrineRMirrorButton {
    UIImageView *_glyph;
    __weak UIImageView *_watchedGlyph;
    // Spotify's own image, as it was taken: what the copy is compared against, since a copy re-rendered as
    // a template is no longer the same object.
    UIImage *_takenGlyph;
    // Standing in for Spotify's download button: its state drawn, and read again while on screen.
    ASMVitrineRDownloadGlyph *_download;
    NSTimer *_downloadTimer;
    // A two-state glyph drawn for Spotify (add-to, readState): 1 on, 0 off, -1 none drawn.
    NSInteger _stateShown;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _glyph = [UIImageView new];
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _glyph.userInteractionEnabled = NO;
    [self addSubview:_glyph];
    _stateShown = -1;

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(asm_vitrine_r_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(asm_vitrine_r_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(asm_vitrine_r_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    // Until its state is known the button draws nothing: a guess would flash the wrong glyph first.
    if (self.readState && _stateShown < 0) {
        ((UIView *)objc_getAssociatedObject(self, &kMirrorGlassKey)).hidden = YES;
        return;
    }
    ASMVitrineRGlassInside(self, &kMirrorGlassKey, ASMVitrineRGlassCircleSize);
    _glyph.frame = CGRectMake(round((bounds.size.width - kMirrorGlyph) / 2), round((bounds.size.height - kMirrorGlyph) / 2),
                              kMirrorGlyph, kMirrorGlyph);
    _download.frame = _glyph.frame;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!_download && _stateShown < 0 && !self.readState) return;
    // Read again on the way in -- the state may have moved on while the page was away -- and not at all
    // while out of the window.
    if (self.window && self.source) [self feedFrom:self.source];
    else [self asm_vitrine_r_followDownload:0];
}

- (void)dealloc {
    [_downloadTimer invalidate];
}

// Shows Spotify's download state; YES when `source` is a download button.
- (BOOL)asm_vitrine_r_feedDownloadFrom:(UIView *)source {
    ASMVitrineRDownloadState state;
    CGFloat progress;
    if (!ASMVitrineRReadDownload(source, &state, &progress)) {
        if (_download && !_download.hidden) {
            _download.hidden = YES;
            _glyph.hidden = NO;
            [self asm_vitrine_r_followDownload:0];
        }
        return NO;
    }
    if (!_download) {
        _download = [[ASMVitrineRDownloadGlyph alloc] initWithFrame:_glyph.frame];
        [self addSubview:_download];
    }
    _download.hidden = NO;
    _glyph.hidden = YES;
    [_download showState:state progress:progress animated:YES];

    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    NSString *value = state == ASMVitrineRDownloadDownloading && progress >= 0
        ? [NSNumberFormatter localizedStringFromNumber:@(progress) numberStyle:NSNumberFormatterPercentStyle] : nil;
    if (![self.accessibilityValue ?: @"" isEqualToString:value ?: @""]) self.accessibilityValue = value;

    // Spotify lays nothing out that the page hears as a download moves on, so the state is read again:
    // twice a second while one runs, for the ring, and now and then otherwise, for one started or removed
    // from elsewhere (the ⋯ sheet). Only while the button is on screen.
    BOOL running = state == ASMVitrineRDownloadWaiting || state == ASMVitrineRDownloadDownloading;
    [self asm_vitrine_r_followDownload:self.window ? (running ? 0.5 : 2) : 0];
    return YES;
}

// Draws `offSymbol`, or `onSymbol` in the accent color, switching between them in place.
- (void)asm_vitrine_r_showOn:(BOOL)on off:(NSString *)offSymbol on:(NSString *)onSymbol source:(UIView *)source {
    if (_stateShown != on) {
        UIImage *image = [UIImage systemImageNamed:on ? onSymbol : offSymbol];
        BOOL animated = _stateShown >= 0 && self.window && !ASMVitrineRReduceMotion();
        BOOL first = _stateShown < 0;
        _stateShown = on;
        _takenGlyph = nil;
        _glyph.hidden = NO;
        if (@available(iOS 17.0, *)) {
            if (animated) [_glyph setSymbolImage:image withContentTransition:[NSSymbolReplaceContentTransition replaceDownUpTransition]];
            else _glyph.image = image;
        } else {
            _glyph.image = image;
        }
        // On is saved or followed, in the accent color, as downloaded is.
        _glyph.tintColor = on ? ASMVitrineRAccent() : ASMVitrineRPrimary();
        if (first) [self setNeedsLayout];
    }
    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    // Nothing is laid out when it changes from elsewhere (the ⋯ sheet), so it is read again as download is.
    [self asm_vitrine_r_followDownload:self.window ? 2 : 0];
}

// Shows whether Spotify's add-to button has its album or playlist saved; YES when `source` is one.
- (BOOL)asm_vitrine_r_feedAddToFrom:(UIView *)source {
    BOOL added;
    if (!ASMVitrineRReadAddTo(source, &added)) {
        _stateShown = -1;
        return NO;
    }
    [self asm_vitrine_r_showOn:added off:@"plus" on:@"checkmark" source:source];
    return YES;
}

// Reads the state again every `interval` seconds; 0 stops.
- (void)asm_vitrine_r_followDownload:(NSTimeInterval)interval {
    if (interval <= 0) {
        [_downloadTimer invalidate];
        _downloadTimer = nil;
        return;
    }
    if (_downloadTimer.valid && fabs(_downloadTimer.timeInterval - interval) < 0.01) return;
    [_downloadTimer invalidate];
    __weak ASMVitrineRMirrorButton *weakSelf = self;
    _downloadTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        ASMVitrineRMirrorButton *button = weakSelf;
        if (!button || !button.window || !button.source) {
            [timer invalidate];
            return;
        }
        [button feedFrom:button.source];
    }];
    _downloadTimer.tolerance = interval * 0.2;
}

// The glyph is taken as Spotify drew it, color and all: the shuffle button turns its own glyph the accent
// color while shuffle is on, and a copy rendered as a template would lose that.
- (void)feedFrom:(UIView *)source {
    if (!source) return;
    _source = source;

    if (self.readState) {
        BOOL on = NO;
        if (self.readState(&on)) [self asm_vitrine_r_showOn:on off:self.stateOffSymbol on:self.stateOnSymbol source:source];
        else [self asm_vitrine_r_followDownload:self.window ? 2 : 0];
        BOOL known = _stateShown >= 0;
        if (_glyph.hidden == known) _glyph.hidden = !known;
        if (self.userInteractionEnabled != known) {
            self.userInteractionEnabled = known;
            self.isAccessibilityElement = known;
        }
        return;
    }

    if ([self asm_vitrine_r_feedDownloadFrom:source]) return;
    if ([self asm_vitrine_r_feedAddToFrom:source]) return;

    UIImageView *glyph = glyphIn(source, 0);
    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    // A button that says "on" with its dot is drawn in our colors, on and off. One expected to have a dot
    // and found without keeps Spotify's colors, which are then all that tells on from off.
    BOOL hasDot = NO;
    BOOL on = self.onGlyphColor && indicatorOn(source, &hasDot);
    UIColor *ownColor = !self.onGlyphColor ? self.glyphColor
                      : hasDot ? (on ? self.onGlyphColor : self.glyphColor ?: ASMVitrineRPrimary()) : nil;
    if (glyph.image && (_takenGlyph != glyph.image || (ownColor != nil) != (_glyph.image.renderingMode == UIImageRenderingModeAlwaysTemplate))) {
        _takenGlyph = glyph.image;
        _glyph.image = ownColor ? [glyph.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : glyph.image;
    }
    if (!glyph && self.fallbackGlyph && _glyph.image != self.fallbackGlyph) {
        _takenGlyph = nil;
        _glyph.image = self.fallbackGlyph;
    }
    UIColor *tint = ownColor ?: (glyph ? glyph.tintColor : ASMVitrineRPrimary());
    if (tint && ![_glyph.tintColor isEqual:tint]) {
        // Turning on or off is a moment of its own: the color fades across rather than jumping.
        BOOL fade = self.window && _glyph.tintColor && hasDot;
        if (fade) {
            [UIView transitionWithView:_glyph duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{ self->_glyph.tintColor = tint; } completion:nil];
        } else {
            _glyph.tintColor = tint;
        }
    }

    // As the capsule does: watched per glyph view, so a reused one reports where it is now.
    if (glyph && glyph != _watchedGlyph) {
        _watchedGlyph = glyph;
        __weak ASMVitrineRMirrorButton *weakSelf = self;
        __weak UIView *weakSource = source;
        ASMVitrineRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)asm_vitrine_r_down {
    ASMVitrineRAnimate(ASMVitrineRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); }, nil);
}

- (void)asm_vitrine_r_up {
    ASMVitrineRAnimate(ASMVitrineRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)asm_vitrine_r_tap {
    ASMVitrineRActivate(self.source);
    // The word is watched where Spotify writes it, but a button that rebuilds its content on the state it
    // just took writes the new word into a label the watch has never seen. So a tap, and only a tap, asks
    // the button again a moment later, which also moves the watch onto whatever label it ended up with. The
    // same goes for shuffle's dot and a download's state, which change with no image or word to watch.
    __weak ASMVitrineRMirrorButton *weakSelf = self;
    for (NSNumber *delay in @[@0.3, @1.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ASMVitrineRMirrorButton *button = weakSelf;
            if (button.source) [button feedFrom:button.source];
        });
    }
}

@end

#pragma mark - the page's pinned ⋯

// A mirror of the back button, which UIKit draws as a 44pt glass circle at the top of the safe area, 16pt
// in from the leading edge (trees/continuous/1.txt:2554: the navigation bar's own glass at {16, 0} 44x44,
// the bar itself at the safe area's top). ⋯ takes the same size and the same insets on the other side, so
// the two read as one row on every page (issue #57).
static const CGFloat kCornerSide = 16;

// The page whose pinned ⋯ was last tapped, and when: what tells the sheet that opens a moment later which
// page's menu it is. The same trick Shared/Player/SpeedPitchMenu.x plays on the player's more button, but
// from this side of it, since this button is the redesign's own and knows its own page.
//
// Recorded on touch down rather than on touch up: the button's own -asm_vitrine_r_tap is registered first and fires
// Spotify's ⋯ from the same event, so a sheet Spotify puts up in that same turn would ask which page it
// belonged to before a target added after -asm_vitrine_r_tap had answered.
static __weak UIView *asm_vitrine_morePage;
static __weak ASMVitrineRMirrorButton *asm_vitrine_moreButton;
static NSTimeInterval asm_vitrine_moreTappedAt;
static char kRecorderKey;

UIView *ASMVitrineRPinnedMoreRecentPage(void) {
    if (!asm_vitrine_morePage || CACurrentMediaTime() - asm_vitrine_moreTappedAt > ASMVitrineRPinnedMoreWindow) return nil;
    return asm_vitrine_morePage;
}

ASMVitrineRMirrorButton *ASMVitrineRPinnedMoreRecentButton(void) {
    if (!asm_vitrine_moreButton || CACurrentMediaTime() - asm_vitrine_moreTappedAt > ASMVitrineRPinnedMoreWindow) return nil;
    return asm_vitrine_moreButton;
}

@interface ASMVitrineRPinnedMoreRecorder : NSObject
@end
@implementation ASMVitrineRPinnedMoreRecorder
- (void)asm_vitrine_r_moreTapped:(ASMVitrineRMirrorButton *)button {
    asm_vitrine_morePage = button.superview;
    asm_vitrine_moreButton = button;
    asm_vitrine_moreTappedAt = CACurrentMediaTime();
}
@end

// Over the page's list and its header both, and put back on top whenever Spotify adds to the page.
static void keepOnTop(UIView *page, UIView *button) {
    if (button.superview != page) [page addSubview:button];
    else if (page.subviews.lastObject != button) [page bringSubviewToFront:button];
}

// Level with the window's safe area at the top, kCornerSide in from the trailing edge of the page. The height is measured in the window and converted back, never from the page's own safe area: a
// page under a navigation bar counts the bar into its inset, so the playlist's read 116 where the window's
// reads 62 and the button sat a bar's height below the back button. The inset from the side is taken from
// the page's own bounds and not converted from the window: the swipe back slides the page across the
// window, and a frame converted from the window's x would hold the button still while the page left under
// it, over the screen below, until the page was gone and took it along.
static void placeInCorner(UIView *page, UIView *button) {
    UIWindow *window = page.window;
    UIView *space = window ?: page;
    CGFloat side = ASMVitrineRGlassCircleSize;
    CGFloat x = page.bounds.size.width - kCornerSide - side;
    CGFloat y = space.safeAreaInsets.top;
    if (window) y = [page convertPoint:CGPointMake(0, y) fromView:nil].y;
    CGRect frame = CGRectMake(x, y, side, side);
    if (!CGRectIsEmpty(frame) && !CGRectEqualToRect(button.frame, frame)) button.frame = frame;
}

ASMVitrineRMirrorButton *ASMVitrineRPinnedMore(UIView *page, const void *key, UIView *source) {
    if (!page) return nil;
    ASMVitrineRMirrorButton *button = objc_getAssociatedObject(page, key);
    if (!button) {
        button = [[ASMVitrineRMirrorButton alloc] initWithFrame:CGRectZero];
        button.fallbackGlyph = [UIImage systemImageNamed:@"ellipsis"];
        // ⋯ sits in an Encore Tertiary button in Spotify's own row, which draws it gray; in the corner of
        // the page it is the one control there and reads white, like the back button opposite it.
        button.glyphColor = ASMVitrineRPrimary();
        // Held by the button, which is held by the page, so the recorder lives exactly as long as both.
        ASMVitrineRPinnedMoreRecorder *recorder = [ASMVitrineRPinnedMoreRecorder new];
        objc_setAssociatedObject(button, &kRecorderKey, recorder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:recorder action:@selector(asm_vitrine_r_moreTapped:) forControlEvents:UIControlEventTouchDown];
        objc_setAssociatedObject(page, key, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    keepOnTop(page, button);
    if (source) [button feedFrom:source];
    if (button.hidden != (source == nil)) button.hidden = source == nil;
    placeInCorner(page, button);
    return button;
}
