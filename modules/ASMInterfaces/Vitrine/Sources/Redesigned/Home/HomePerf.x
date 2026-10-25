// Home redesign, FLEX builds only: what a scroll of Home costs. While Home's list is dragged or
// decelerating, a display link at the screen's own rate times each frame, and the Home hooks add up
// the calls and the time spent in them (ASMVitrineRHomeProbeBegin/End). When the list settles, one log line
// says the scroll's frames, its hitches (a frame late by half a frame or more), the worst frame and
// each hook's share. A hitch the hooks do not account for is Spotify's main thread; lag with no
// hitches here is the render server (masks, clipping), which a display link does not see.
//
// Main thread stalls over 120 ms are sampled too (Diagnostics/ASMVitrineHangSampler.h): for 90 s once Home is
// up, and during every scroll.
//
// The hooks install with the rest of the redesign and return at once outside a FLEX build: FLEX is
// injected after the tweak, so whether it is there is only known once the app runs.
#import <QuartzCore/QuartzCore.h>
#import "Core/ASMVitrineCore.h"
#import "Diagnostics/Diagnostics.h"
#import "Diagnostics/ASMVitrineHangSampler.h"
#import "Home.h"

// Frames with nothing moving before a scroll counts as over.
static const NSUInteger kSettledFrames = 10;
// A frame this long is described, the first few of each scroll.
static const CFTimeInterval kLongFrame = 0.1;
static const NSUInteger kLongFramesDescribed = 5;

// Section sizing includes Spotify's own measuring of the cell, which the hook calls through.
static const char *const kProbeNames[ASMVitrineRHomeProbeCount] = {"section sizing", "header", "headings", "cards", "tiles",
    "labels", "labels matched", "indicator shown", "list attrs", "shelf layout", "large card", "tint asks", "feed model"};
static NSUInteger asm_vitrine_calls[ASMVitrineRHomeProbeCount];
static CFTimeInterval asm_vitrine_time[ASMVitrineRHomeProbeCount];
static __weak UIScrollView *asm_vitrine_list;
static char kHomeTabKey;

static BOOL probing(void) {
    static int state = -1;
    if (state < 0) state = ASMVitrineIsDebugBuild() ? 1 : 0;
    return state == 1;
}

// Home at rest: once a second, the calls and time of each hook since the last line, the list's layouts and the
// frames the display link saw late, logged only for a second in which any of them happened. A Home that is
// still and quiet logs nothing, which is the proof that nothing fires at rest (`make log | grep "home perf/s"`).
// Off unless asked for: its display link holds the screen at up to 120 Hz while Spotify is open
// (scripts/phone.py pref --key asm.interface.vitrine.redesign.debug.homeRestMeter --value 1, then relaunch).
static NSUInteger asm_vitrine_restFrames, asm_vitrine_restHitches, asm_vitrine_listLayouts;
static CFTimeInterval asm_vitrine_restLast;
@interface ASMVitrineRHomeRestMeter : NSObject
@end
@implementation ASMVitrineRHomeRestMeter
- (void)tick:(CADisplayLink *)link {
    CFTimeInterval expected = link.targetTimestamp - link.timestamp;
    if (asm_vitrine_restLast > 0 && expected > 0) {
        asm_vitrine_restFrames++;
        if (link.timestamp - asm_vitrine_restLast > expected * 1.5) asm_vitrine_restHitches++;
    }
    asm_vitrine_restLast = link.timestamp;
}
@end
static void startRestMeter(void) {
    static dispatch_source_t timer;
    static NSUInteger calls[ASMVitrineRHomeProbeCount];
    static CFTimeInterval time[ASMVitrineRHomeProbeCount];
    static ASMVitrineRHomeRestMeter *meter;
    if (timer || !ASMVitrineFlag(@"asm.interface.vitrine.redesign.debug.homeRestMeter", NO)) return;
    meter = [ASMVitrineRHomeRestMeter new];
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:meter selector:@selector(tick:)];
    if (@available(iOS 15.0, *)) link.preferredFrameRateRange = CAFrameRateRangeMake(80, 120, 120);
    [link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), NSEC_PER_SEC, NSEC_PER_SEC / 20);
    dispatch_source_set_event_handler(timer, ^{
        NSMutableString *line = [NSMutableString string];
        CFTimeInterval total = 0;
        for (NSUInteger i = 0; i < ASMVitrineRHomeProbeCount; i++) {
            NSUInteger n = asm_vitrine_calls[i] - calls[i];
            CFTimeInterval t = asm_vitrine_time[i] - time[i];
            calls[i] = asm_vitrine_calls[i];
            time[i] = asm_vitrine_time[i];
            total += t;
            if (n) [line appendFormat:@" %s %lu/%.2fms", kProbeNames[i], (unsigned long)n, t * 1000];
        }
        if (line.length || asm_vitrine_restHitches || asm_vitrine_listLayouts) {
            ASMVitrineLog(@"home perf/s: frames %lu hitches %lu list layouts %lu hooks %.2f ms%@", (unsigned long)asm_vitrine_restFrames,
                  (unsigned long)asm_vitrine_restHitches, (unsigned long)asm_vitrine_listLayouts, total * 1000, line.length ? line : @" (none)");
        }
        asm_vitrine_restFrames = asm_vitrine_restHitches = asm_vitrine_listLayouts = 0;
    });
    dispatch_resume(timer);
}

CFTimeInterval ASMVitrineRHomeProbeBegin(void) {
    return probing() ? CACurrentMediaTime() : 0;
}

void ASMVitrineRHomeProbeEnd(ASMVitrineRHomeProbe probe, CFTimeInterval began) {
    if (began <= 0 || probe >= ASMVitrineRHomeProbeCount) return;
    asm_vitrine_calls[probe]++;
    asm_vitrine_time[probe] += CACurrentMediaTime() - began;
}

@interface ASMVitrineRHomeScrollMeter : NSObject
- (void)watch:(UIScrollView *)list;
@end

@implementation ASMVitrineRHomeScrollMeter {
    CADisplayLink *_link;
    __weak UIScrollView *_list;
    CFTimeInterval _start, _last, _worst, _frameSum;
    NSUInteger _frames, _hitches, _dropped, _settled, _layouts, _described;
    NSUInteger _calls[ASMVitrineRHomeProbeCount];
    CFTimeInterval _time[ASMVitrineRHomeProbeCount];
}

- (void)watch:(UIScrollView *)list {
    _layouts++;
    if (_link || !(list.isDragging || list.isDecelerating)) return;
    _list = list;
    _start = CACurrentMediaTime();
    _last = _worst = _frameSum = 0;
    _frames = _hitches = _dropped = _settled = _described = 0;
    _layouts = 1;
    ASMVitrineHangSamplerStart(@"home scroll", 0);
    memcpy(_calls, asm_vitrine_calls, sizeof(_calls));
    memcpy(_time, asm_vitrine_time, sizeof(_time));
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    // A link left at its default rate holds the whole app to 60 Hz while it runs (CLAUDE.md).
    if (@available(iOS 15.0, *)) _link.preferredFrameRateRange = CAFrameRateRangeMake(80, 120, 120);
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)tick:(CADisplayLink *)link {
    CFTimeInterval expected = link.targetTimestamp - link.timestamp;
    if (_last > 0 && expected > 0) {
        CFTimeInterval gap = link.timestamp - _last;
        _frames++;
        _frameSum += expected;
        _worst = MAX(_worst, gap);
        if (gap > expected * 1.5) {
            _hitches++;
            _dropped += (NSUInteger)MAX(1, round(gap / expected) - 1);
            if (gap > kLongFrame && _described < kLongFramesDescribed) {
                _described++;
                [self describeLongFrame:gap];
            }
        }
    }
    _last = link.timestamp;
    UIScrollView *list = _list;
    if (list && (list.isDragging || list.isDecelerating || list.isTracking)) {
        _settled = 0;
        return;
    }
    if (++_settled >= kSettledFrames) [self finish];
}

// What was on screen around a long frame: each section in sight, top down, by the class of its root, and
// whether HomeSections.x collapsed it.
- (void)describeLongFrame:(CFTimeInterval)gap {
    UICollectionView *list = (UICollectionView *)_list;
    if (![list isKindOfClass:UICollectionView.class]) return;
    NSArray<UICollectionViewCell *> *cells = [list.visibleCells sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : a.frame.origin.y > b.frame.origin.y ? NSOrderedDescending : NSOrderedSame;
    }];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (UICollectionViewCell *cell in cells) {
        UIView *root = cell.contentView.subviews.firstObject.subviews.firstObject;
        NSString *name = root ? NSStringFromClass(root.class) : @"empty";
        NSRange dot = [name rangeOfString:@"." options:NSBackwardsSearch];
        if (dot.location != NSNotFound) name = [name substringFromIndex:dot.location + 1];
        [parts addObject:[NSString stringWithFormat:@"%@%@ %.0f", name, ASMVitrineRHomeSectionCollapsed(cell) ? @" (collapsed)" : @"", cell.bounds.size.height]];
    }
    ASMVitrineLog(@"home perf: %.0f ms frame at offset %.0f over %@", gap * 1000, list.contentOffset.y, [parts componentsJoinedByString:@", "]);
}

- (void)finish {
    [_link invalidate];
    _link = nil;
    ASMVitrineHangSamplerStop();
    CFTimeInterval duration = CACurrentMediaTime() - _start;
    NSMutableString *hooks = [NSMutableString string];
    CFTimeInterval ours = 0;
    for (NSUInteger i = 0; i < ASMVitrineRHomeProbeCount; i++) {
        NSUInteger calls = asm_vitrine_calls[i] - _calls[i];
        CFTimeInterval time = asm_vitrine_time[i] - _time[i];
        ours += time;
        if (calls) [hooks appendFormat:@", %s %lu in %.1f ms", kProbeNames[i], (unsigned long)calls, time * 1000];
    }
    double rate = _frames && _frameSum > 0 ? _frames / _frameSum : 0;
    ASMVitrineLog(@"home perf: scroll %.1f s, %lu frames at %.0f Hz, %lu hitches (%lu frames dropped), worst frame %.0f ms, list laid out %lu times; hooks %.1f ms in all%@",
          duration, (unsigned long)_frames, rate, (unsigned long)_hitches, (unsigned long)_dropped, _worst * 1000,
          (unsigned long)_layouts, ours * 1000, hooks.length ? hooks : @", none called");
}

@end

static ASMVitrineRHomeScrollMeter *asm_vitrine_meter;

static BOOL isHomeTab(UIViewController *page) {
    NSNumber *answer = objc_getAssociatedObject(page, &kHomeTabKey);
    if (answer) return answer.boolValue;
    static Class funkis;
    if (!funkis) funkis = NSClassFromString(@"_TtC19Home_FunkisPageImpl20FunkisViewController");
    BOOL home = NO;
    for (UIViewController *parent = page.parentViewController; parent && !home; parent = parent.parentViewController) {
        home = [parent isKindOfClass:funkis];
    }
    if (page.parentViewController) objc_setAssociatedObject(page, &kHomeTabKey, @(home), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return home;
}

%hook _TtC16Home_EvoPageImpl33EvoLoadableResourceViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (!probing() || asm_vitrine_list) return;
    UIViewController *page = (UIViewController *)self;
    if (!isHomeTab(page)) return;
    for (UIView *sub in page.viewIfLoaded.subviews) {
        if ([sub isKindOfClass:UICollectionView.class]) asm_vitrine_list = (UIScrollView *)sub;
    }
    if (!asm_vitrine_list) return;
    ASMVitrineLog(@"home perf: measuring the scrolls of %@", NSStringFromClass(asm_vitrine_list.class));
    startRestMeter();
    // The lag reported came in the first half minute after launch, scrolling or not.
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineHangSamplerStart(@"after launch", 90); });
}
%end

// The list lays out on every frame it moves, which is when a scroll is noticed.
%hook _TtC16Home_CarouselKit29TouchCancellingCollectionView
- (void)layoutSubviews {
    %orig;
    if ((UIView *)self != asm_vitrine_list) return;
    asm_vitrine_listLayouts++;
    if (!asm_vitrine_meter) asm_vitrine_meter = [ASMVitrineRHomeScrollMeter new];
    [asm_vitrine_meter watch:(UIScrollView *)self];
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    %init;
    ASMVitrineRequireClasses(@[
        @"_TtC16Home_EvoPageImpl33EvoLoadableResourceViewController",
        @"_TtC16Home_CarouselKit29TouchCancellingCollectionView",
    ]);
}
