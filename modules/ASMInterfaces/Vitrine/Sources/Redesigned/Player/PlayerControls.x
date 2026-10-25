// Player redesign: previous, play and next as bare glyphs, the way the Music app draws them, and the
// timestamps under the slider in digits of one width, so they stop twitching every second.
//
// The glyphs are drawn over Spotify's controls rather than instead of them: each button keeps its
// action, its enabled state, its accessibility and the Gestures zones around it, and the glyph takes no
// touches. Previous and next get theirs inside the button's content view, so the button's own press
// and disabled look carry over; Spotify's icon under it goes transparent on every pass (SPTEncoreIconView
// is a Swift class, which ASMVitrineRSuppress cannot keep). Play loses its white disc, a plain UIImageView the
// size of the button, which ASMVitrineRSuppress keeps transparent, and the glyph over it follows the player's state.
//
// Tree (trees/clean/player/01.txt): PlaybackControlsElementsUnit's view holds
// id=SPTNowPlayingPreviousTrackButton 56x56 > UIView > StackView > StackView > SPTEncoreIconView (:257),
// id=SPTNowPlayingPlayButton (PlayButtonView 64x64, :266) > CondensedButton (a UIButton,
// objc-meta-Spotify.txt:207312) > UIImageView 64x64 and a hidden SpinnerView, next to a hidden UIView
// holding a UIImageView (:277), and id=SPTNowPlayingNextTrackButton. DurationElementUnit's view holds
// id=now-playing-time-take-label and id=now-playing-time-remaning-label, SPTEncoreLabels whose UILabel
// is id=...-internal (:227). The sticky header has a play button of its own (:492), which a search
// inside the unit's view never reaches.
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "Core/ASMVitrineCore.h"
#import "Redesigned/Kit/ASMVitrineRKit.h"
#import "Shared/Haptics/Haptics.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Player.h"

static const CGFloat kSkipGlyphSize = 32, kPlayGlyphSize = 44;
// A spinner that is still up this long after a state change is buffering, not a track starting.
static const NSTimeInterval kSpinnerCheck = 0.6;

// After a tap the glyph shows what the tap asked for, and a state still saying the opposite is taken for
// one sent before the player caught up, for this long; after it the player's word is final.
static const NSTimeInterval kTapTrust = 1.2;

static char kPreviousKey, kNextKey, kPlayKey, kGlyphKey, kTakeKey, kRemainingKey;
static __weak UIView *asm_vitrine_playView;
static __weak UIButton *asm_vitrine_playButton;
static CFTimeInterval asm_vitrine_tappedUntil;
static BOOL asm_vitrine_tappedPaused;
static __weak ASMVitrineRGlyphView *asm_vitrine_playGlyph;
static __weak UIView *asm_vitrine_controlsHost;

void ASMVitrineRPlayerVanish(UIView *view) {
    if (!view) return;
    if (view.alpha != 0) view.alpha = 0;
    view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

static void logMissing(NSString *what) {
    static NSMutableSet<NSString *> *logged;
    if (!logged) logged = [NSMutableSet set];
    if ([logged containsObject:what]) return;
    [logged addObject:what];
    ASMVitrineLog(@"redesign player: %@ not found, left as Spotify's", what);
}

static ASMVitrineRGlyphView *glyphFor(UIView *owner, NSString *symbol, CGFloat size) {
    ASMVitrineRGlyphView *glyph = objc_getAssociatedObject(owner, &kGlyphKey);
    if (!glyph) {
        glyph = [[ASMVitrineRGlyphView alloc] initWithSymbol:symbol pointSize:size weight:UIImageSymbolWeightRegular];
        objc_setAssociatedObject(owner, &kGlyphKey, glyph, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return glyph;
}

// Centered by the autoresizing mask as well as here: the unit lays out before the buttons in its row
// have a size, so a center set then is the middle of nothing, (0, 0), and no later pass of the unit's
// comes to move it (trees/continuous/1.txt, 2026-09-17: glyphs at {-23.7, -14.7} in 56pt buttons).
static void keepOnTop(UIView *view, UIView *host) {
    if (view.superview != host) {
        view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin
                              | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [host addSubview:view];
    } else if (host.subviews.lastObject != view) {
        [host bringSubviewToFront:view];
    }
    view.center = CGPointMake(CGRectGetMidX(host.bounds), CGRectGetMidY(host.bounds));
}

#pragma mark - previous and next

static void skipGlyph(UIView *host, NSString *identifier, const void *findKey, NSString *symbol) {
    UIView *button = ASMVitrineRFindByIdentifier(host, identifier, findKey);
    UIView *content = button.subviews.firstObject;
    if (!content) {
        logMissing(identifier);
        return;
    }
    static Class icon;
    if (!icon) icon = NSClassFromString(@"SPTEncoreIconView");
    ASMVitrineRGlyphView *glyph = glyphFor(button, symbol, kSkipGlyphSize);
    ASMVitrineForEachView(content, ^(UIView *view) {
        if (view != glyph && [view isKindOfClass:icon]) ASMVitrineRPlayerVanish(view);
    });
    keepOnTop(glyph, content);
}

#pragma mark - play

static BOOL spinnerShowing(UIButton *button) {
    for (UIView *sub in button.subviews) {
        if (!sub.hidden && sub.alpha > 0.01 && [NSStringFromClass(sub.class) containsString:@"SpinnerView"]) return YES;
    }
    return NO;
}

static NSString *symbolFor(BOOL paused) {
    return paused ? @"play.fill" : @"pause.fill";
}

static void refreshPlayGlyph(BOOL animated) {
    ASMVitrineRGlyphView *glyph = asm_vitrine_playGlyph;
    SPTPlayerState *state = ASMVitrinePlayerState();
    if (!glyph || !state) return;
    glyph.alpha = spinnerShowing(asm_vitrine_playButton) ? 0 : 1;
    CFTimeInterval now = CACurrentMediaTime();
    if (now < asm_vitrine_tappedUntil) {
        if (state.isPaused != asm_vitrine_tappedPaused) return;
        asm_vitrine_tappedUntil = 0;
    }
    [glyph setSymbol:symbolFor(state.isPaused) animated:animated];
}

// The player's state reaches the glyph a beat after the tap (the request goes through the player core
// and comes back as a state), which read as a slow button; Spotify's own disc turns at the touch. So the
// glyph turns at the touch too, to the opposite of what it shows, and the state settles it after.
static void playTapped(void) {
    ASMVitrineRGlyphView *glyph = asm_vitrine_playGlyph;
    if (!glyph || glyph.alpha == 0) return;
    asm_vitrine_tappedPaused = ![glyph.symbol isEqualToString:@"play.fill"];
    asm_vitrine_tappedUntil = CACurrentMediaTime() + kTapTrust;
    [glyph setSymbol:symbolFor(asm_vitrine_tappedPaused) animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kTapTrust * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ refreshPlayGlyph(YES); });
}

void ASMVitrineRPlayerPlayGlyphIn(UIView *host) {
    // A state that lands after the layout asks this unit to lay out again (the watcher below).
    asm_vitrine_controlsHost = host;
    UIView *play = ASMVitrineRFindByIdentifier(host, @"SPTNowPlayingPlayButton", &kPlayKey);
    if (!play) {
        logMissing(@"SPTNowPlayingPlayButton");
        return;
    }
    // Before the player has reported a state the glyph could only guess, so the disc stays.
    SPTPlayerState *state = ASMVitrinePlayerState();
    if (!state) return;
    UIButton *button = nil;
    for (UIView *sub in play.subviews) {
        if ([sub isKindOfClass:UIButton.class]) button = (UIButton *)sub;
    }
    UIImageView *disc = nil;
    for (UIView *sub in button.subviews) {
        if ([sub isKindOfClass:UIImageView.class] && CGSizeEqualToSize(sub.bounds.size, button.bounds.size)) disc = (UIImageView *)sub;
    }
    if (!disc) {
        logMissing(@"the play button's disc");
        return;
    }
    ASMVitrineRSuppress(disc);
    // The holder Spotify crossfades a snapshot of the disc in when play turns to pause.
    for (UIView *sub in play.subviews) {
        if (object_getClass(sub) != UIView.class) continue;
        for (UIView *image in sub.subviews) {
            if ([image isKindOfClass:UIImageView.class]) ASMVitrineRSuppress(image);
        }
    }

    // Inside the button, over the disc it replaces, so it follows the button's own press.
    ASMVitrineRGlyphView *glyph = glyphFor(play, symbolFor(state.isPaused), kPlayGlyphSize);
    keepOnTop(glyph, button);
    asm_vitrine_playView = play;
    asm_vitrine_playButton = button;
    asm_vitrine_playGlyph = glyph;
    refreshPlayGlyph(NO);

    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineLog(@"redesign player: play glyph over %@ (disc %@ suppressed), spinner %@", NSStringFromClass(play.class), NSStringFromClass(disc.class), spinnerShowing(button) ? @"showing" : @"hidden"); });
}

%hook _TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *host = ((UIViewController *)self).viewIfLoaded;
    if (!host) return;
    // The unit lays out before its row does, and the glyphs are centered on the buttons in it.
    [ASMVitrineRowIn(host) layoutIfNeeded];
    skipGlyph(host, @"SPTNowPlayingPreviousTrackButton", &kPreviousKey, @"backward.fill");
    skipGlyph(host, @"SPTNowPlayingNextTrackButton", &kNextKey, @"forward.fill");
    ASMVitrineRPlayerPlayGlyphIn(host);
}
%end

@interface ASMVitrineRPlayerControlsWatcher : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineRPlayerControlsWatcher

- (void)playerStateDidChange:(SPTPlayerState *)state {
    // The first state can land after the controls laid out, which left the disc for want of one.
    if (!asm_vitrine_playGlyph) [asm_vitrine_controlsHost setNeedsLayout];
    refreshPlayGlyph(YES);
    // Spotify raises its spinner a moment after a state says loading, and drops it a moment after.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSpinnerCheck * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ refreshPlayGlyph(YES); });
}

@end

static ASMVitrineRPlayerControlsWatcher *asm_vitrine_controlsWatcher;

#pragma mark - times

static UILabel *monospaced(UIView *host, NSString *identifier, const void *findKey) {
    UILabel *label = (UILabel *)ASMVitrineRFindByIdentifier(host, identifier, findKey);
    if (![label isKindOfClass:UILabel.class]) {
        logMissing(identifier);
        return nil;
    }
    ASMVitrineRMonospacedDigits(label);
    return label;
}

// The action the play button's own UIButton sends (objc-methods.txt: -[PlayButtonView uiButtonTapped]).
// Only the player's button turns the glyph: the sticky header and every page with a play button of
// its own use the same class.
%hook _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView
- (void)uiButtonTapped {
    %orig;
    if ((UIView *)self != asm_vitrine_playView) return;
    playTapped();
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineLog(@"redesign player: play glyph turned at the tap"); });
}
%end

#pragma mark - tap to seek

// Spotify's slider only drags. A tap in the band around it seeks: anywhere across the duration unit's height,
// up to kSeekReach past either end of the bar, moving at most kSeekSlop and lifting within kSeekLongest. A tap
// on the thumb is the thumb's, and a tap on a time is Spotify's, which turns the remaining time into the length.
static const CGFloat kSeekReach = 12, kSeekSlop = 10, kThumbSlop = 6;
static const NSTimeInterval kSeekLongest = 0.5;
// The tap is played to the slider as a short drag, so Spotify's unit seeks the way it does at the end of one.
// Meanwhile the slider says it is still tracking, until the player's position is this near the place tapped or
// for this long at most, so the unit does not put the thumb back to the old place first. A drag that did not
// seek by kSeekCheck is seeked directly.
static const NSInteger kSeekNear = 1500;
static const NSTimeInterval kSeekHold = 2, kSeekCheck = 1;

static char kSliderKey, kSeekTapKey, kTakeTimeKey, kRemainingTimeKey;
static __weak UISlider *asm_vitrine_seekSlider;
static NSInteger asm_vitrine_seekTarget;
static CFTimeInterval asm_vitrine_seekHeldUntil;

static CGFloat thumbCentre(UISlider *slider, float value) {
    CGRect bounds = slider.bounds;
    return CGRectGetMidX([slider thumbRectForBounds:bounds trackRect:[slider trackRectForBounds:bounds] value:value]);
}

// Where along the song a point on the slider is, over the thumb's travel rather than the slider's width, so
// either end of the bar is the song's start or end exactly.
CGFloat ASMVitrineRSeekShareAt(UISlider *slider, CGPoint point) {
    CGFloat start = thumbCentre(slider, slider.minimumValue), end = thumbCentre(slider, slider.maximumValue);
    if (end - start < 1) return NAN;
    return MIN(1, MAX(0, (point.x - start) / (end - start)));
}

// Whether a tap at `point` in the duration unit's view seeks.
BOOL ASMVitrineRSeekTapLands(UIView *unit, UISlider *slider, CGPoint point) {
    // The AI DJ's unit keeps a slider in a hidden element on a live stream: nothing to seek there.
    if (!slider.window || !slider.enabled || ![slider isDescendantOfView:unit] || !ASMVitrineShownUnder(slider, unit) || !CGRectContainsPoint(unit.bounds, point)) return NO;
    CGRect bar = [unit convertRect:slider.bounds fromView:slider];
    if (point.x < CGRectGetMinX(bar) - kSeekReach || point.x > CGRectGetMaxX(bar) + kSeekReach) return NO;
    CGRect bounds = slider.bounds;
    CGRect thumb = [slider thumbRectForBounds:bounds trackRect:[slider trackRectForBounds:bounds] value:slider.value];
    if (CGRectContainsPoint(CGRectInset([unit convertRect:thumb fromView:slider], -kThumbSlop, -kThumbSlop), point)) return NO;
    for (UIView *time in @[ASMVitrineRFindByIdentifier(unit, @"now-playing-time-take-label", &kTakeTimeKey) ?: NSNull.null,
                           ASMVitrineRFindByIdentifier(unit, @"now-playing-time-remaning-label", &kRemainingTimeKey) ?: NSNull.null]) {
        if ([time isKindOfClass:UIView.class] && !time.hidden && CGRectContainsPoint([unit convertRect:time.bounds fromView:time], point)) return NO;
    }
    return YES;
}

static BOOL seekHeld(void) {
    if (!asm_vitrine_seekHeldUntil) return NO;
    NSInteger at = ASMVitrineKaraokePositionMs();
    if (CACurrentMediaTime() < asm_vitrine_seekHeldUntil && (at < 0 || labs(at - asm_vitrine_seekTarget) >= kSeekNear)) return YES;
    asm_vitrine_seekHeldUntil = 0;
    return NO;
}

// Whether Spotify listens to the slider's control events, which is how a played drag reaches it.
static BOOL listensToSlider(UISlider *slider) {
    __block BOOL listens = NO;
    [slider enumerateEventHandlers:^(UIAction *action, id target, SEL selector, UIControlEvents events, BOOL *stop) {
        if (events & (UIControlEventTouchUpInside | UIControlEventValueChanged)) listens = *stop = YES;
    }];
    return listens;
}

static void seekTo(UISlider *slider, CGFloat share) {
    SPTPlayerState *state = ASMVitrinePlayerState();
    if (!state || state.duration <= 0 || isnan(share)) return;
    NSInteger ms = (NSInteger)(share * state.duration * 1000);
    ASMVitrinePlayFeedback(ASMVitrineFeedbackSkip);
    BOOL played = listensToSlider(slider);
    static NSUInteger logged;
    if (logged++ < 3) ASMVitrineLog(@"redesign player: a tap seeks to %.3f of the song, %@", share, played ? @"played to the slider as a drag" : @"directly (nothing listens to the slider)");
    if (!played) {
        ASMVitrineKaraokeSeek(ms);
        return;
    }
    [slider setValue:slider.minimumValue + share * (slider.maximumValue - slider.minimumValue) animated:NO];
    asm_vitrine_seekSlider = slider;
    asm_vitrine_seekTarget = ms;
    asm_vitrine_seekHeldUntil = CACurrentMediaTime() + kSeekHold;
    [slider sendActionsForControlEvents:UIControlEventTouchDown];
    [slider sendActionsForControlEvents:UIControlEventValueChanged];
    [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSeekCheck * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger at = ASMVitrineKaraokePositionMs();
        if (asm_vitrine_seekTarget != ms || at < 0 || labs(at - ms) < kSeekNear) return;
        ASMVitrineLog(@"redesign player: the played drag did not seek (at %ld ms, not %ld), seeking directly", (long)at, (long)ms);
        asm_vitrine_seekHeldUntil = 0;
        ASMVitrineKaraokeSeek(ms);
    });
}

// A recognizer of its own rather than a tap: UIKit lets a slider keep a single tap from a tap recognizer
// over it, and the band reaches past the slider.
@interface ASMVitrineRSeekTap : UIGestureRecognizer
@property (nonatomic, weak) UISlider *slider;
@end

@implementation ASMVitrineRSeekTap {
    CGPoint _start;
    CFTimeInterval _began;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UIView *unit = self.view;
    UITouch *touch = touches.anyObject;
    CGPoint point = [touch locationInView:unit];
    if (touches.count > 1 || [event touchesForGestureRecognizer:self].count > 1 || !ASMVitrineRSeekTapLands(unit, self.slider, point)) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    _start = point;
    _began = CACurrentMediaTime();
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [touches.anyObject locationInView:self.view];
    if (hypot(point.x - _start.x, point.y - _start.y) > kSeekSlop) self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    BOOL tap = CACurrentMediaTime() - _began <= kSeekLongest;
    self.state = tap ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateFailed;
}

- (void)asm_vitrine_r_seek {
    UISlider *slider = self.slider;
    if (slider) seekTo(slider, ASMVitrineRSeekShareAt(slider, [self.view convertPoint:_start toView:slider]));
}
@end

static void watchSlider(UIView *host) {
    UISlider *slider = (UISlider *)ASMVitrineRFindByIdentifier(host, @"SPTNowPlayingSliderV2", &kSliderKey);
    if (![slider isKindOfClass:UISlider.class]) return;
    ASMVitrineRSeekTap *tap = objc_getAssociatedObject(host, &kSeekTapKey);
    if (!tap) {
        tap = [[ASMVitrineRSeekTap alloc] initWithTarget:nil action:nil];
        [tap addTarget:tap action:@selector(asm_vitrine_r_seek)];
        [host addGestureRecognizer:tap];
        objc_setAssociatedObject(host, &kSeekTapKey, tap, OBJC_ASSOCIATION_ASSIGN);
        ASMVitrineLog(@"redesign player: a tap around the progress bar seeks");
    }
    tap.slider = slider;
}

%hook _TtCO17NowPlaying_ECMKit11ProgressBar6Slider
- (BOOL)isTracking {
    return ((UISlider *)self == asm_vitrine_seekSlider && seekHeld()) || %orig;
}
%end

// The ordinary player's duration unit and the AI DJ's (DJMDurationElementsUnit) hold the same progress bar and times.
static void durationLaidOut(UIViewController *unit) {
    UIView *host = unit.viewIfLoaded;
    if (!host) return;
    watchSlider(host);
    UILabel *taken = monospaced(host, @"now-playing-time-take-label-internal", &kTakeKey);
    monospaced(host, @"now-playing-time-remaning-label-internal", &kRemainingKey);
    // Whether Spotify's font has digits of one width shows in the descriptor's feature settings.
    if (!taken) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineLog(@"redesign player: monospaced times in %@ %.0fpt, features %@", taken.font.fontName, taken.font.pointSize, taken.font.fontDescriptor.fontAttributes[UIFontDescriptorFeatureSettingsAttribute]); });
}

%hook _TtC20NowPlaying_ModesImpl19DurationElementUnit
- (void)viewDidLayoutSubviews {
    %orig;
    durationLaidOut((UIViewController *)self);
}
%end

// The DJ unit is another class, hooked only when the build has it (see %ctor).
%group ASMVitrineRDJControlsDurationHooks
%hook ASMVitrineRDJControlsDurationUnit
- (void)viewDidLayoutSubviews {
    %orig;
    durationLaidOut((UIViewController *)self);
}
%end
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    %init;
    Class djDuration = ASMVitrineRDJClass(@"DJMDurationElementsUnit");
    if (djDuration) { %init(ASMVitrineRDJControlsDurationHooks, ASMVitrineRDJControlsDurationUnit = djDuration); }
    asm_vitrine_controlsWatcher = [ASMVitrineRPlayerControlsWatcher new];
    ASMVitrineAddPlayerStateObserver(asm_vitrine_controlsWatcher);
    ASMVitrineRequireClasses(@[
        @"_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit",
        @"_TtC20NowPlaying_ModesImpl19DurationElementUnit",
        @"_TtC28EncoreConsumerMobile_BaseKit14PlayButtonView",
        @"SPTEncoreIconView",
        @"_TtCO17NowPlaying_ECMKit11ProgressBar6Slider",
    ]);
}
