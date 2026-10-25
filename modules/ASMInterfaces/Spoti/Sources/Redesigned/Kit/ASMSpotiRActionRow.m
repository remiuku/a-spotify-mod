// The action row's controls: the Play capsule and the button that stands in for one of Spotify's.
//
// Both are drawn from what Spotify's own button shows, and neither keeps state of its own. The glyph is
// looked for past what is hidden behind it -- a play button's glow ring is a hidden view holding an image
// of its own, and taken for the glyph it put a soft green ring in the capsule (device, 2026-09-17) -- and
// it is watched afterwards, because Spotify swaps play for pause without laying the header out again.
#import "Core/ASMSpotiCore.h"
#import "ASMSpotiRActionRow.h"
#import "ASMSpotiRGlass.h"
#import "ASMSpotiRRestyle.h"
#import "ASMSpotiRTokens.h"
#import "ASMSpotiRAccent.h"
#import "ASMSpotiRDownload.h"

// The capsule: the glyph is Spotify's own 48pt canvas with the triangle small in the middle of it, so the
// lead is short and the gap to the word comes out of the canvas itself.
static const CGFloat kGlyphSide = 44, kCapsuleLead = 4, kCapsuleTrail = 20;
// The mirrored glyph, the size Spotify draws one inside a 48pt round button.
static const CGFloat kMirrorGlyph = 24;

static char kCapsuleGlassKey, kMirrorGlassKey, kWordGlassKey;

// A word button's padding either side of the word.
static const CGFloat kWordPadding = 18;

// The glyph Spotify's button draws: an image view of the button's own size that nothing hidden is in the
// way of. `side` is the size to match, 0 for any image view that is showing.
static UIImageView *glyphIn(UIView *button, CGFloat side) {
    __block UIImageView *glyph = nil;
    ASMSpotiForEachView(button, ^(UIView *v) {
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
    ASMSpotiForEachView(button, ^(UIView *v) {
        if (!word && v.accessibilityLabel.length) word = v.accessibilityLabel;
    });
    return word;
}

#pragma mark - the Play capsule

@implementation ASMSpotiRPlayCapsule {
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
    [self addTarget:self action:@selector(asm_spotipw_r_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(asm_spotipw_r_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(asm_spotipw_r_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (CGFloat)asm_spotipw_r_width {
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
        ASMSpotiRGlassCapsuleInside(self, &kCapsuleGlassKey, bounds.size, YES);
    }
    // Given more room than the word asks for, the glyph and the word stay together in the middle.
    CGFloat lead = kCapsuleLead + MAX(0, round((bounds.size.width - [self asm_spotipw_r_width]) / 2));
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

    UIFont *font = ASMSpotiRFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, UIContentSizeCategoryLarge);
    if (![_title.font isEqual:font]) _title.font = font;
    UIColor *content = self.contentColor ?: ASMSpotiRAccent();
    if (![_title.textColor isEqual:content]) _title.textColor = content;
    if (word && ![_title.text isEqualToString:word]) {
        _title.text = word;
        self.accessibilityLabel = word;
        [self setNeedsLayout];
    }
    if (![_glyph.tintColor isEqual:content]) _glyph.tintColor = content;

    if (glyph.image && _glyph.image != glyph.image) {
        _glyph.image = [glyph.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            ASMSpotiLog(@"redesign kit: play glyph %@ from %@, word \"%@\"", NSStringFromCGSize(glyph.image.size),
                  NSStringFromClass(glyph.class), word);
        });
    }
    // Play becomes pause without the header laying out again. Watched per glyph view rather than once for
    // good, so a glyph Spotify hands to another button reports to the button it is in now.
    if (glyph && glyph != _watchedGlyph) {
        _watchedGlyph = glyph;
        __weak ASMSpotiRPlayCapsule *weakSelf = self;
        __weak UIView *weakSource = source;
        ASMSpotiRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)asm_spotipw_r_down {
    ASMSpotiRAnimate(ASMSpotiRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.94, 0.94); }, nil);
}

- (void)asm_spotipw_r_up {
    ASMSpotiRAnimate(ASMSpotiRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)asm_spotipw_r_tap {
    ASMSpotiRActivate(self.source);
}

@end

#pragma mark - a button standing in for Spotify's

// The label a button shows its word in, whether it has a word in it yet or not.
static UILabel *labelIn(UIView *button) {
    __block UILabel *found = nil;
    ASMSpotiForEachView(button, ^(UIView *v) {
        if (!found && [v isKindOfClass:UILabel.class]) found = (UILabel *)v;
    });
    return found;
}

// Whether a button that marks "on" with a small dot under its glyph (Encore's shuffle, a 4pt round view it
// hides while off) is on. `found` says whether the button has such a dot at all.
static BOOL indicatorOn(UIView *button, BOOL *found) {
    __block UIView *dot = nil;
    ASMSpotiForEachView(button, ^(UIView *v) {
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

// The text a button shows: the first label under it with something in it.
static NSString *labelTextIn(UIView *button) {
    __block NSString *text = nil;
    ASMSpotiForEachView(button, ^(UIView *v) {
        if (text || ![v isKindOfClass:UILabel.class]) return;
        NSString *candidate = [((UILabel *)v).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (candidate.length) text = candidate;
    });
    return text;
}

@implementation ASMSpotiRMirrorButton {
    UIImageView *_glyph;
    UILabel *_word;
    __weak UILabel *_watchedWord;
    __weak UIImageView *_watchedGlyph;
    // Spotify's own image, as it was taken: what the copy is compared against, since a copy re-rendered as
    // a template is no longer the same object.
    UIImage *_takenGlyph;
    // Standing in for Spotify's download button: its state drawn, and read again while on screen.
    ASMSpotiRDownloadGlyph *_download;
    NSTimer *_downloadTimer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _glyph = [UIImageView new];
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _glyph.userInteractionEnabled = NO;
    [self addSubview:_glyph];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(asm_spotipw_r_down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(asm_spotipw_r_up) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self addTarget:self action:@selector(asm_spotipw_r_tap) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (CGFloat)asm_spotipw_r_width {
    if (!self.showsWord || !_word.text.length) return ASMSpotiRActionHeight;
    [_word sizeToFit];
    return MAX(ASMSpotiRActionHeight, ceil(_word.bounds.size.width) + 2 * kWordPadding);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    // A word button waiting for its word draws the circle, and takes the capsule once the word is there:
    // only one of the two shapes is asked for on a pass, so the other is put away rather than left under it.
    if (self.showsWord && _word.text.length) {
        ASMSpotiRGlassCapsuleInside(self, &kWordGlassKey, bounds.size, NO);
        ((UIView *)objc_getAssociatedObject(self, &kMirrorGlassKey)).hidden = YES;
        [_word sizeToFit];
        CGSize text = _word.bounds.size;
        // Given less width than the word asked for -- what is left of the row beside a wide Play -- the
        // capsule spends its own padding on the word before it lets the word be cut ("Following").
        CGFloat padding = MIN(kWordPadding, MAX(0, floor((bounds.size.width - text.width) / 2)));
        _word.frame = CGRectMake(padding, round((bounds.size.height - text.height) / 2),
                                 MAX(0, bounds.size.width - 2 * padding), text.height);
        return;
    }
    ASMSpotiRGlassInside(self, &kMirrorGlassKey, ASMSpotiRGlassCircleSize);
    ((UIView *)objc_getAssociatedObject(self, &kWordGlassKey)).hidden = YES;
    _glyph.frame = CGRectMake(round((bounds.size.width - kMirrorGlyph) / 2), round((bounds.size.height - kMirrorGlyph) / 2),
                              kMirrorGlyph, kMirrorGlyph);
    _download.frame = _glyph.frame;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!_download) return;
    // Read again on the way in -- the download may have moved on while the page was away -- and not at all
    // while out of the window.
    if (self.window && self.source) [self feedFrom:self.source];
    else [self asm_spotipw_r_followDownload:0];
}

- (void)dealloc {
    [_downloadTimer invalidate];
}

// Shows Spotify's download state; YES when `source` is a download button.
- (BOOL)asm_spotipw_r_feedDownloadFrom:(UIView *)source {
    ASMSpotiRDownloadState state;
    CGFloat progress;
    if (!ASMSpotiRReadDownload(source, &state, &progress)) {
        if (_download && !_download.hidden) {
            _download.hidden = YES;
            _glyph.hidden = NO;
            [self asm_spotipw_r_followDownload:0];
        }
        return NO;
    }
    if (!_download) {
        _download = [[ASMSpotiRDownloadGlyph alloc] initWithFrame:_glyph.frame];
        [self addSubview:_download];
    }
    _download.hidden = NO;
    _glyph.hidden = YES;
    [_download showState:state progress:progress animated:YES];

    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    NSString *value = state == ASMSpotiRDownloadDownloading && progress >= 0
        ? [NSNumberFormatter localizedStringFromNumber:@(progress) numberStyle:NSNumberFormatterPercentStyle] : nil;
    if (![self.accessibilityValue ?: @"" isEqualToString:value ?: @""]) self.accessibilityValue = value;

    // Spotify lays nothing out that the page hears as a download moves on, so the state is read again:
    // twice a second while one runs, for the ring, and now and then otherwise, for one started or removed
    // from elsewhere (the ⋯ sheet). Only while the button is on screen.
    BOOL running = state == ASMSpotiRDownloadWaiting || state == ASMSpotiRDownloadDownloading;
    [self asm_spotipw_r_followDownload:self.window ? (running ? 0.5 : 2) : 0];
    return YES;
}

// Reads the download again every `interval` seconds; 0 stops.
- (void)asm_spotipw_r_followDownload:(NSTimeInterval)interval {
    if (interval <= 0) {
        [_downloadTimer invalidate];
        _downloadTimer = nil;
        return;
    }
    if (_downloadTimer.valid && fabs(_downloadTimer.timeInterval - interval) < 0.01) return;
    [_downloadTimer invalidate];
    __weak ASMSpotiRMirrorButton *weakSelf = self;
    _downloadTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
        ASMSpotiRMirrorButton *button = weakSelf;
        if (!button || !button.window || !button.source) {
            [timer invalidate];
            return;
        }
        [button feedFrom:button.source];
    }];
    _downloadTimer.tolerance = interval * 0.2;
}

// The glyph is taken as Spotify drew it, colour and all: the shuffle button turns its own glyph the accent
// colour while shuffle is on, and a copy rendered as a template would lose that.
- (void)feedFrom:(UIView *)source {
    if (!source) return;
    _source = source;

    if (self.showsWord) {
        if (!_word) {
            _word = [UILabel new];
            _word.userInteractionEnabled = NO;
            _word.textAlignment = NSTextAlignmentCenter;
            _word.font = ASMSpotiRFont(UIFontTextStyleSubheadline, UIFontWeightSemibold, UIContentSizeCategoryExtraLarge);
            _word.textColor = ASMSpotiRPrimary();
            [self addSubview:_word];
        }
        NSString *text = labelTextIn(source);
        if (text && ![_word.text isEqualToString:text]) {
            _word.text = text;
            self.accessibilityLabel = source.accessibilityLabel ?: text;
            [self setNeedsLayout];
            [self.superview setNeedsLayout];
        }
        // Spotify's word is its state, which it fills in a moment after the button itself is there and
        // changes without laying out anything the page hears (the artist's Follow, issue #52). So the label
        // it puts the word in is watched, and the button hears it land.
        UILabel *source_word = labelIn(source);
        if (source_word && source_word != _watchedWord) {
            _watchedWord = source_word;
            __weak ASMSpotiRMirrorButton *weakSelf = self;
            __weak UIView *weakSource = source;
            ASMSpotiRObserveText(source_word, ^(UILabel *label) {
                if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
            });
        }
        // Until the word is there the button is the glyph it falls back to, which says what it does, rather
        // than an empty capsule.
        BOOL hasWord = _word.text.length > 0;
        if (_glyph.hidden != hasWord) {
            _glyph.hidden = hasWord;
            [self setNeedsLayout];
        }
        if (!hasWord && self.fallbackGlyph && _glyph.image != self.fallbackGlyph) {
            _glyph.image = self.fallbackGlyph;
            _glyph.tintColor = ASMSpotiRPrimary();
        }
        if (!hasWord && !self.accessibilityLabel) self.accessibilityLabel = source.accessibilityLabel;
        return;
    }

    if ([self asm_spotipw_r_feedDownloadFrom:source]) return;

    UIImageView *glyph = glyphIn(source, 0);
    NSString *word = source.accessibilityLabel ?: wordIn(source);
    if (word && ![self.accessibilityLabel isEqualToString:word]) self.accessibilityLabel = word;
    // A button that says "on" with its dot is drawn in our colours, on and off. One expected to have a dot
    // and found without keeps Spotify's colours, which are then all that tells on from off.
    BOOL hasDot = NO;
    BOOL on = self.onGlyphColor && indicatorOn(source, &hasDot);
    UIColor *ownColor = !self.onGlyphColor ? self.glyphColor
                      : hasDot ? (on ? self.onGlyphColor : self.glyphColor ?: ASMSpotiRPrimary()) : nil;
    if (glyph.image && (_takenGlyph != glyph.image || (ownColor != nil) != (_glyph.image.renderingMode == UIImageRenderingModeAlwaysTemplate))) {
        _takenGlyph = glyph.image;
        _glyph.image = ownColor ? [glyph.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] : glyph.image;
    }
    if (!glyph && self.fallbackGlyph && _glyph.image != self.fallbackGlyph) {
        _takenGlyph = nil;
        _glyph.image = self.fallbackGlyph;
    }
    UIColor *tint = ownColor ?: (glyph ? glyph.tintColor : ASMSpotiRPrimary());
    if (tint && ![_glyph.tintColor isEqual:tint]) {
        // Turning on or off is a moment of its own: the colour fades across rather than jumping.
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
        __weak ASMSpotiRMirrorButton *weakSelf = self;
        __weak UIView *weakSource = source;
        ASMSpotiRObserveImage(glyph, ^(UIImageView *view) {
            if (weakSelf && weakSource) [weakSelf feedFrom:weakSource];
        });
    }
}

- (void)asm_spotipw_r_down {
    ASMSpotiRAnimate(ASMSpotiRMotionPress, ^{ self.transform = CGAffineTransformMakeScale(0.92, 0.92); }, nil);
}

- (void)asm_spotipw_r_up {
    ASMSpotiRAnimate(ASMSpotiRMotionPress, ^{ self.transform = CGAffineTransformIdentity; }, nil);
}

- (void)asm_spotipw_r_tap {
    ASMSpotiRActivate(self.source);
    // The word is watched where Spotify writes it, but a button that rebuilds its content on the state it
    // just took writes the new word into a label the watch has never seen. So a tap, and only a tap, asks
    // the button again a moment later, which also moves the watch onto whatever label it ended up with. The
    // same goes for shuffle's dot and a download's state, which change with no image or word to watch.
    __weak ASMSpotiRMirrorButton *weakSelf = self;
    for (NSNumber *delay in @[@0.3, @1.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ASMSpotiRMirrorButton *button = weakSelf;
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
// Recorded on touch down rather than on touch up: the button's own -asm_spotipw_r_tap is registered first and fires
// Spotify's ⋯ from the same event, so a sheet Spotify puts up in that same turn would ask which page it
// belonged to before a target added after -asm_spotipw_r_tap had answered.
static __weak UIView *asm_spotipw_morePage;
static NSTimeInterval asm_spotipw_moreTappedAt;
static char kRecorderKey;

UIView *ASMSpotiRPinnedMoreRecentPage(void) {
    if (!asm_spotipw_morePage || CACurrentMediaTime() - asm_spotipw_moreTappedAt > ASMSpotiRPinnedMoreWindow) return nil;
    return asm_spotipw_morePage;
}

@interface ASMSpotiRPinnedMoreRecorder : NSObject
@end
@implementation ASMSpotiRPinnedMoreRecorder
- (void)asm_spotipw_r_moreTapped:(ASMSpotiRMirrorButton *)button {
    asm_spotipw_morePage = button.superview;
    asm_spotipw_moreTappedAt = CACurrentMediaTime();
}
@end

ASMSpotiRMirrorButton *ASMSpotiRPinnedMore(UIView *page, const void *key, UIView *source) {
    if (!page) return nil;
    ASMSpotiRMirrorButton *button = objc_getAssociatedObject(page, key);
    if (!button) {
        button = [[ASMSpotiRMirrorButton alloc] initWithFrame:CGRectZero];
        button.fallbackGlyph = [UIImage systemImageNamed:@"ellipsis"];
        // ⋯ sits in an Encore Tertiary button in Spotify's own row, which draws it grey; in the corner of
        // the page it is the one control there and reads white, like the back button opposite it.
        button.glyphColor = ASMSpotiRPrimary();
        // Held by the button, which is held by the page, so the recorder lives exactly as long as both.
        ASMSpotiRPinnedMoreRecorder *recorder = [ASMSpotiRPinnedMoreRecorder new];
        objc_setAssociatedObject(button, &kRecorderKey, recorder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:recorder action:@selector(asm_spotipw_r_moreTapped:) forControlEvents:UIControlEventTouchDown];
        objc_setAssociatedObject(page, key, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Over the page's list and its header both, and put back on top whenever Spotify adds to the page.
    if (button.superview != page) [page addSubview:button];
    else if (page.subviews.lastObject != button) [page bringSubviewToFront:button];
    if (source) [button feedFrom:source];
    if (button.hidden != (source == nil)) button.hidden = source == nil;

    // Measured in the window and converted back, never from the page's own safe area: a page under a
    // navigation bar counts the bar into its inset, so the playlist's read 116 where the window's reads 62
    // and the button sat a bar's height below the back button (device, trees/continuous/1.txt 2026-09-20).
    UIWindow *window = page.window;
    CGFloat side = ASMSpotiRGlassCircleSize;
    CGRect frame;
    if (window) {
        CGRect inWindow = CGRectMake(window.bounds.size.width - kCornerSide - side, window.safeAreaInsets.top, side, side);
        frame = [page convertRect:inWindow fromView:nil];
    } else {
        frame = CGRectMake(page.bounds.size.width - kCornerSide - side, page.safeAreaInsets.top, side, side);
    }
    if (!CGRectIsEmpty(frame) && !CGRectEqualToRect(button.frame, frame)) button.frame = frame;
    return button;
}
