// Home redesign: the header the way the Music app has it. The filter pills (All, Music, Podcasts) go and
// a large title takes their place at the leading edge; the avatar that opens the side drawer moves to the
// trailing edge; the scrim Spotify lays behind the header goes too, the soft scroll edge (Kit/ASMVitrineREdgeEffect.x)
// being what keeps the page scrolling under it soft; the title itself scrolls away (followScroll).
//
// Tree (trees/clean/home/10.txt:3018-3051): FunkisViewController's view holds a 402x112 UIView around
// Reprise_LiquidGlassKit LiquidGlass.GradientView (the scrim) and, at {0, 62}, an
// ElementView<HomeHeaderElement> 402x50 holding HomeHeaderView > UIStackView {0, 8} 402x34 of two arranged
// views: ListeningActivity_ElementsKit.AdaptiveFaceContainer {16, 0} 32x34 (the avatar, an EncoreButton in 9.1.90,
// id=Components.UI.SideDrawerButton) and LiquidGlass.LeadingFadeMaskView {48, 1} 354x32 around
// Home_PillUIKit.PillScrollView.
//
// The avatar moves by the stack's layout direction rather than by a frame of ours. Right to left, the stack
// lays its first view out at the trailing edge itself on every pass, whatever width the face container
// takes when friends listening show beside the avatar; its leading margin, 16pt, is the one Spotify gives
// the header in a right to left language. The pills stay in the stack with no alpha rather than hidden,
// the way the redesign takes any view out of a stack Spotify arranges (Kit/ASMVitrineRRestyle.h).
//
// The title is Spotify's own name for the tab, read off its tab bar item (id=TabBar.Item.Home, 10.txt:3100),
// so it follows the app's language.
#import "Core/ASMVitrineCore.h"
#import "Redesigned/Kit/ASMVitrineRKit.h"
#import "Home.h"

// Tries at finding the tab's name before settling for the English one: a miss walks the window.
static const NSUInteger kTitleTries = 8;

static char kTitleKey, kTabKey, kPillGlassKey, kGlassKey, kButtonsKey, kConnectKey, kTintKey, kWatchKey;
// The title row's pill: a glass capsule around the filter button and the avatar, 44pt tall, as the reference has
// it; the menu drives Spotify's own filter chips, hidden in the stack, and offers the device picker when Spotify
// has one (a now playing bar) and the large shelf's Show all, its heading being gone (HomeTopPicks.x).
static const CGFloat kPillHeight = 44, kPillButton = 44, kPillPad = 6;
// The page's color behind the title (ASMVitrineRHomeSetPageTint), fading to black over this height.
static const CGFloat kTintHeight = 480;

// The pill's buttons sit above Spotify's stack, which would take every touch in the header otherwise; a touch
// outside a button goes through to the avatar under them.
@interface ASMVitrineRHomePillButtons : UIView
@property (nonatomic, strong) UIButton *filter;
@end
@implementation ASMVitrineRHomePillButtons
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

@interface ASMVitrineRHomeTintView : UIView
@end
@implementation ASMVitrineRHomeTintView
+ (Class)layerClass {
    return CAGradientLayer.class;
}
@end
static NSString *asm_vitrine_tabName;

static void vanish(UIView *view) {
    if (!view) return;
    if (view.alpha != 0) view.alpha = 0;
    view.userInteractionEnabled = NO;
    view.accessibilityElementsHidden = YES;
}

static UIView *childNamed(UIView *host, NSString *marker) {
    for (UIView *sub in host.subviews) {
        if ([NSStringFromClass(sub.class) containsString:marker]) return sub;
    }
    return nil;
}

static NSString *tabName(UIWindow *window) {
    if (asm_vitrine_tabName || !window) return asm_vitrine_tabName ?: @"Home";
    static NSUInteger tries;
    if (tries >= kTitleTries) return @"Home";
    tries++;
    UIView *item = ASMVitrineRFindByIdentifier(window, @"TabBar.Item.Home", &kTabKey);
    __block NSString *name = nil;
    if (item) ASMVitrineForEachView(item, ^(UIView *v) {
        if (!name && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) name = ((UILabel *)v).text;
    });
    if (!name) {
        if (tries == kTitleTries) ASMVitrineLog(@"redesign home: the Home tab's name not found, the title stays English");
        return @"Home";
    }
    asm_vitrine_tabName = [name copy];
    ASMVitrineLog(@"redesign home: title \"%@\" from the tab bar", asm_vitrine_tabName);
    return asm_vitrine_tabName;
}

static UILabel *titleIn(UIView *header) {
    UILabel *title = objc_getAssociatedObject(header, &kTitleKey);
    if (!title) {
        title = [UILabel new];
        title.textColor = ASMVitrineRPrimary();
        title.accessibilityTraits = UIAccessibilityTraitHeader;
        title.adjustsFontSizeToFitWidth = YES;
        title.minimumScaleFactor = 0.6;
        title.userInteractionEnabled = NO;
        objc_setAssociatedObject(header, &kTitleKey, title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (title.superview != header) [header addSubview:title];
    return title;
}

// The header's views, found once: the page lays out again as it appears, and the walk names classes.
static __weak UIView *asm_vitrine_header;
static __weak UIStackView *asm_vitrine_stack;
static __weak UIView *asm_vitrine_scrim;
static UIControl *connectButton(UIView *window);

#pragma mark - the pill

// Spotify's filter chips (All, Music, Podcasts, Audiobooks), controls in the stack's hidden pill scroller, in
// their order there.
static NSArray<UIControl *> *chips(UIStackView *stack) {
    NSMutableArray<UIControl *> *found = [NSMutableArray array];
    ASMVitrineForEachView(stack, ^(UIView *v) {
        if ([v.accessibilityIdentifier hasPrefix:@"home-feed-"] && [v isKindOfClass:UIControl.class]) [found addObject:(UIControl *)v];
    });
    return [found sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        CGFloat xa = [a convertRect:a.bounds toView:stack].origin.x, xb = [b convertRect:b.bounds toView:stack].origin.x;
        return xa < xb ? NSOrderedAscending : xa > xb ? NSOrderedDescending : NSOrderedSame;
    }];
}

// The chip in effect: selected, or drawn solid with its glass hidden (home-feed-default, trees 2026-10-11).
static BOOL chosen(UIControl *chip) {
    if (chip.selected) return YES;
    __block BOOL solid = NO;
    ASMVitrineForEachView(chip, ^(UIView *v) {
        if ([NSStringFromClass(v.class) containsString:@"ChipGlassView"] && v.hidden) solid = YES;
    });
    return solid;
}

static NSArray<UIMenuElement *> *menuElements(void) {
    NSMutableArray<UIMenuElement *> *elements = [NSMutableArray array];
    NSMutableArray<UIMenuElement *> *filters = [NSMutableArray array];
    for (UIControl *chip in chips(asm_vitrine_stack)) {
        __weak UIControl *weakChip = chip;
        UIAction *action = [UIAction actionWithTitle:chip.accessibilityLabel ?: @"" image:nil identifier:nil handler:^(UIAction *a) {
            if (weakChip) ASMVitrineRActivate(weakChip);
        }];
        action.state = chosen(chip) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [filters addObject:action];
    }
    if (filters.count) [elements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:filters]];
    NSMutableArray<UIMenuElement *> *more = [NSMutableArray array];
    UIControl *connect = connectButton(asm_vitrine_header.window);
    if (connect) {
        __weak UIControl *weakConnect = connect;
        [more addObject:[UIAction actionWithTitle:@"Devices" image:[UIImage systemImageNamed:@"hifispeaker"] identifier:nil handler:^(UIAction *a) {
            if (weakConnect) ASMVitrineRActivate(weakConnect);
        }]];
    }
    NSString *title = nil;
    UIControl *showAll = ASMVitrineRHomeTopPicksShowAll(&title);
    if (showAll) {
        __weak UIControl *weakShowAll = showAll;
        [more addObject:[UIAction actionWithTitle:title.length ? [NSString stringWithFormat:@"Show all · %@", title] : @"Show all"
                                            image:[UIImage systemImageNamed:@"rectangle.stack"] identifier:nil handler:^(UIAction *a) {
            if (weakShowAll) ASMVitrineRActivate(weakShowAll);
        }]];
    }
    if (more.count) [elements addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:more]];
    return elements;
}

// Spotify's device picker button, in the now playing bar (Components.ConnectButtonOutputSwitcher > UIButton,
// trees 2026-10-11); nil without a bar.
static UIControl *connectButton(UIView *window) {
    UIView *holder = window ? ASMVitrineRFindByIdentifier(window, @"Components.ConnectButtonOutputSwitcher", &kConnectKey) : nil;
    __block UIControl *button = [holder isKindOfClass:UIControl.class] ? (UIControl *)holder : nil;
    if (!button) ASMVitrineForEachView(holder, ^(UIView *v) {
        if (!button && [v isKindOfClass:UIControl.class]) button = (UIControl *)v;
    });
    return button;
}

static UIButton *pillButton(NSString *symbol, NSString *label) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:config] forState:UIControlStateNormal];
    button.tintColor = ASMVitrineRPrimary();
    button.accessibilityLabel = label;
    // The menu takes the appearance of its button; outside Spotify's navigation stacks that is the system's.
    button.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    return button;
}

static ASMVitrineRHomePillButtons *buttonsIn(UIView *header) {
    ASMVitrineRHomePillButtons *buttons = objc_getAssociatedObject(header, &kButtonsKey);
    if (!buttons) {
        buttons = [ASMVitrineRHomePillButtons new];
        buttons.filter = pillButton(@"line.3.horizontal.decrease", @"Filter Home");
        buttons.filter.menu = [UIMenu menuWithChildren:@[[UIDeferredMenuElement elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement *> *)) {
            completion(menuElements());
        }]]];
        buttons.filter.showsMenuAsPrimaryAction = YES;
        [buttons addSubview:buttons.filter];
        objc_setAssociatedObject(header, &kButtonsKey, buttons, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (buttons.superview != header) [header addSubview:buttons];
    else if (header.subviews.lastObject != buttons) [header bringSubviewToFront:buttons];
    return buttons;
}

static UIView *glassIn(UIView *header) {
    UIView *glass = objc_getAssociatedObject(header, &kGlassKey);
    if (!glass) {
        glass = [UIView new];
        glass.userInteractionEnabled = NO;
        objc_setAssociatedObject(header, &kGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (glass.superview != header) [header insertSubview:glass atIndex:0];
    else if (header.subviews.firstObject != glass) [header sendSubviewToBack:glass];
    return glass;
}

// Lays the pill out around the avatar, which stays Spotify's in its stack; the pill's leading edge.
// The stack's place in the header with no transform on it (its center and bounds, which a transform leaves
// alone): Spotify animates the stack in with a transform, and the one pass this ran in on a 440pt phone saw the
// stack's frame half a width to the left, with no pass after to put the pill right.
static CGRect untransformed(UIView *view) {
    CGSize size = view.bounds.size;
    return CGRectMake(view.center.x - size.width / 2, view.center.y - size.height / 2, size.width, size.height);
}

// The avatar's place, by its center and bounds too: it carries the scroll's transform (followScroll).
static CGRect facePlace(UIStackView *stack, UIView *face) {
    CGRect place = untransformed(stack);
    return CGRectOffset(untransformed(face), place.origin.x - stack.bounds.origin.x, place.origin.y - stack.bounds.origin.y);
}

// A view placed by bounds and center, which the scroll's transform leaves alone.
static void place(UIView *view, CGRect frame) {
    CGRect bounds = (CGRect){CGPointZero, frame.size};
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    if (!CGRectEqualToRect(view.bounds, bounds)) view.bounds = bounds;
    if (!CGPointEqualToPoint(view.center, center)) view.center = center;
}

static CGFloat layoutPill(UIView *header, UIStackView *stack, UIView *face) {
    ASMVitrineRHomePillButtons *buttons = buttonsIn(header);
    UIView *glass = glassIn(header);
    CGRect faceFrame = face ? facePlace(stack, face) : CGRectZero;
    CGFloat width = kPillPad + kPillButton + (face ? faceFrame.size.width + kPillPad * 2 : kPillPad);
    CGFloat maxX = face ? CGRectGetMaxX(faceFrame) + kPillPad : header.bounds.size.width - ASMVitrineRSideMargin;
    CGFloat midY = face ? CGRectGetMidY(faceFrame) : CGRectGetMidY(untransformed(stack));
    CGRect pill = CGRectMake(round(maxX - width), round(midY - kPillHeight / 2), width, kPillHeight);
    place(glass, pill);
    place(buttons, pill);
    CGRect filter = CGRectMake(kPillPad, 0, kPillButton, kPillHeight);
    if (!CGRectEqualToRect(buttons.filter.frame, filter)) buttons.filter.frame = filter;
    ASMVitrineRGlassCapsuleInside(glass, &kPillGlassKey, pill.size, NO);
    return CGRectGetMinX(pill);
}

#pragma mark - the page's color

static UIColor *asm_vitrine_pageTint;
static __weak ASMVitrineRHomeTintView *asm_vitrine_tintView;

static void paintTint(ASMVitrineRHomeTintView *tint, BOOL animated) {
    CAGradientLayer *layer = (CAGradientLayer *)tint.layer;
    UIColor *top = asm_vitrine_pageTint ?: UIColor.blackColor;
    NSArray *colors = @[(id)top.CGColor, (id)[top colorWithAlphaComponent:0].CGColor];
    if ([layer.colors isEqualToArray:colors]) return;
    if (animated && tint.window) {
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"colors"];
        fade.fromValue = layer.colors;
        fade.duration = ASMVitrineRCrossfade;
        [layer addAnimation:fade forKey:@"colors"];
    }
    layer.colors = colors;
}

void ASMVitrineRHomeSetPageTint(UIColor *color) {
    if (color == asm_vitrine_pageTint || [color isEqual:asm_vitrine_pageTint]) return;
    asm_vitrine_pageTint = color;
    if (asm_vitrine_tintView) paintTint(asm_vitrine_tintView, YES);
}

// The gradient at the back of the page's view (HomePageView, which holds the feed), the feed's own black cleared so
// it shows through behind the title and the first shelf; the shelves clear theirs (HomeSections.x).
static void layoutTint(UIView *view) {
    __block UIView *page = asm_vitrine_tintView.superview;
    if (!page) ASMVitrineForEachView(view, ^(UIView *v) {
        if (!page && [v.accessibilityIdentifier hasPrefix:@"HomePageView"]) page = v;
    });
    if (!page) return;
    ASMVitrineRHomeTintView *tint = objc_getAssociatedObject(page, &kTintKey);
    if (!tint) {
        tint = [ASMVitrineRHomeTintView new];
        tint.userInteractionEnabled = NO;
        objc_setAssociatedObject(page, &kTintKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        asm_vitrine_tintView = tint;
        paintTint(tint, NO);
    }
    if (tint.superview != page) [page insertSubview:tint atIndex:0];
    CGRect frame = CGRectMake(0, 0, page.bounds.size.width, kTintHeight);
    if (!CGRectEqualToRect(tint.frame, frame)) tint.frame = frame;
    for (UIView *sub in page.subviews) {
        if ([sub isKindOfClass:UICollectionView.class] && ![sub.backgroundColor isEqual:UIColor.clearColor]) sub.backgroundColor = UIColor.clearColor;
    }
}

static BOOL findHeader(UIView *view) {
    if (asm_vitrine_stack && [asm_vitrine_stack isDescendantOfView:view]) return YES;
    for (UIView *wrapper in view.subviews) {
        UIView *scrim = childNamed(wrapper, @"GradientView");
        if (scrim) asm_vitrine_scrim = scrim;
    }
    UIView *header = childNamed(childNamed(view, @"HomeHeaderElement"), @"HomeHeaderView");
    for (UIView *sub in header.subviews) {
        if ([sub isKindOfClass:UIStackView.class]) asm_vitrine_stack = (UIStackView *)sub;
    }
    asm_vitrine_header = header;
    if (asm_vitrine_stack) return YES;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ ASMVitrineLog(@"redesign home: header stack not found, header left as Spotify's"); });
    return NO;
}

// The title row scrolls away with the page, as the Music app's large title and avatar do: the title, the glass pill
// and Spotify's avatar rise with what is under them and fade over the title's height, so the page never passes
// under them.
static __weak UIView *asm_vitrine_face;
static void rise(UIView *part, CGAffineTransform transform, CGFloat alpha) {
    if (!CGAffineTransformEqualToTransform(part.transform, transform)) part.transform = transform;
    if (part.alpha != alpha) part.alpha = alpha;
}

// The pill's glass takes no alpha (ASMVitrineRGlass.h): it rises with the row, and its material goes off once the row is
// half faded and comes back with it.
static BOOL asm_vitrine_glassShown = YES;
static void riseGlass(UIView *glass, CGAffineTransform transform, CGFloat alpha) {
    if (!glass) return;
    if (!CGAffineTransformEqualToTransform(glass.transform, transform)) glass.transform = transform;
    BOOL shown = alpha > 0.5;
    UIView *shape = objc_getAssociatedObject(glass, &kPillGlassKey);
    if (!shape || shown == asm_vitrine_glassShown) return;
    asm_vitrine_glassShown = shown;
    [UIView animateWithDuration:0.15 animations:^{ ASMVitrineRShowGlass(shape, shown); }];
}

static void followScroll(UIScrollView *scroll) {
    UILabel *title = asm_vitrine_header ? objc_getAssociatedObject(asm_vitrine_header, &kTitleKey) : nil;
    if (!title || !scroll) return;
    CGFloat scrolled = MAX(0, scroll.contentOffset.y + scroll.adjustedContentInset.top);
    CGAffineTransform up = CGAffineTransformMakeTranslation(0, -scrolled);
    CGFloat alpha = 1 - MIN(1, scrolled / MAX(1, title.bounds.size.height));
    rise(title, up, alpha);
    riseGlass(objc_getAssociatedObject(asm_vitrine_header, &kGlassKey), up, alpha);
    rise(objc_getAssociatedObject(asm_vitrine_header, &kButtonsKey), up, alpha);
    if ([asm_vitrine_face isDescendantOfView:asm_vitrine_header]) rise(asm_vitrine_face, up, alpha);
}

@interface ASMVitrineRHomeTitleFollower : NSObject
@property (nonatomic, weak) UIScrollView *scroll;
@end

@implementation ASMVitrineRHomeTitleFollower
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    followScroll(self.scroll);
}
@end

// The feed: the page's outermost scroll view taller than the pills, found once. Not the tallest: a shelf can grow taller
// than the page, and a shelf's offset never moves the title. Followed by an observer that lives as long as it does.
static char kFollowerKey;
static __weak UIScrollView *asm_vitrine_feed;
static __weak UIView *asm_vitrine_pageView;
static void followFeed(UIScrollView *feed) {
    asm_vitrine_feed = feed;
    if (!objc_getAssociatedObject(feed, &kFollowerKey)) {
        ASMVitrineRHomeTitleFollower *follower = [ASMVitrineRHomeTitleFollower new];
        follower.scroll = feed;
        [feed addObserver:follower forKeyPath:@"contentOffset" options:0 context:NULL];
        objc_setAssociatedObject(feed, &kFollowerKey, follower, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    followScroll(feed);
}

static void follow(UIView *view) {
    __block UIScrollView *feed = asm_vitrine_feed;
    if (![feed isDescendantOfView:view]) feed = nil;
    if (!feed) ASMVitrineForEachView(view, ^(UIView *v) {
        if (!feed && [v isKindOfClass:UIScrollView.class] && v.bounds.size.height > 300) feed = (UIScrollView *)v;
    });
    if (feed) followFeed(feed);
}

static void layoutHeader(UIViewController *page);

// The page's own pass can run before Spotify has sized its header at all (the header's view 0 by 0, its stack still
// a width to the left and centered on the origin: seen on a 440pt phone, with no pass of the page after, which
// left the pill beside the title). While the header has no size, this comes back a little later, for a few seconds
// at most, until it has one.
static const NSUInteger kHeaderWaits = 30;
static const NSTimeInterval kHeaderWait = 0.1;
static void layoutHeaderOnceSized(UIViewController *page, UIView *header) {
    // findHeader answers YES on the stack alone, so the header can be gone while the stack is not.
    if (!header) return;
    if (!CGRectIsEmpty(header.bounds)) {
        // Sized: a later spell without a size gets its waits again.
        if (objc_getAssociatedObject(header, &kWatchKey)) objc_setAssociatedObject(header, &kWatchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    NSUInteger waits = [objc_getAssociatedObject(header, &kWatchKey) unsignedIntegerValue];
    if (waits >= kHeaderWaits) return;
    objc_setAssociatedObject(header, &kWatchKey, @(waits + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIViewController *weakPage = page;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHeaderWait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongPage = weakPage;
        if (strongPage) layoutHeader(strongPage);
    });
}

static void layoutHeader(UIViewController *page) {
    UIView *view = page.viewIfLoaded;
    if (!view || !findHeader(view)) return;
    asm_vitrine_pageView = view;
    UIView *header = asm_vitrine_header;
    UIStackView *stack = asm_vitrine_stack;
    vanish(asm_vitrine_scrim);
    layoutHeaderOnceSized(page, header);

    UIView *face = nil;
    for (UIView *part in stack.arrangedSubviews) {
        if (ASMVitrineRIsAvatar(part) && !face) face = part;
        else vanish(part);
    }
    // A face that stopped being the avatar drops the scroll's transform and fade.
    if (asm_vitrine_face && asm_vitrine_face != face) rise(asm_vitrine_face, CGAffineTransformIdentity, 1);
    asm_vitrine_face = face;
    // Brought back if an earlier pass took it for a pill (vanish). Its alpha is otherwise the scroll's (followScroll).
    if (!face.userInteractionEnabled && face.accessibilityElementsHidden) {
        face.alpha = 1;
        face.userInteractionEnabled = YES;
        face.accessibilityElementsHidden = NO;
    }
    if (stack.semanticContentAttribute != UISemanticContentAttributeForceRightToLeft) {
        stack.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        [stack setNeedsLayout];
    }
    [stack layoutIfNeeded];
    // With the Home look off, the avatar stands alone in the stack and the title ends before it; it rises and fades
    // with the title either way.
    CGFloat pillLeading = face ? CGRectGetMinX(facePlace(stack, face)) : header.bounds.size.width - ASMVitrineRSideMargin + ASMVitrineRGrid;
    if (ASMVitrineRHomeLook()) {
        pillLeading = layoutPill(header, stack, face);
        layoutTint(view);
    }

    UILabel *title = titleIn(header);
    NSString *text = tabName(header.window);
    if (![title.text isEqualToString:text]) {
        title.text = text;
        title.accessibilityLabel = text;
    }
    UIFont *font = ASMVitrineRFont(UIFontTextStyleLargeTitle, UIFontWeightBold, UIContentSizeCategoryLarge);
    if (![title.font isEqual:font]) title.font = font;

    CGFloat trailing = pillLeading - ASMVitrineRGrid;
    CGFloat height = ceil(font.lineHeight);
    CGRect frame = CGRectMake(ASMVitrineRSideMargin, round(CGRectGetMidY(untransformed(stack)) - height / 2), MAX(0, trailing - ASMVitrineRSideMargin), height);
    place(title, frame);
    follow(view);

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ASMVitrineLog(@"redesign home: header %@, avatar %@ in the stack %@, title %@, scrim %@", NSStringFromCGRect(header.frame),
              face ? NSStringFromCGRect(face.frame) : @"not found", NSStringFromCGRect(stack.frame), NSStringFromCGRect(frame),
              asm_vitrine_scrim ? @"found" : @"not found");
    });
}

// The feed can come after the header's last pass (its page loads while the header is laid out, a few seconds on
// a slow account), and the page's view has no pass of its own after; a feed that replaces another (a filter) comes
// while the old one is still in the window. The feed's own controller hands it the follower on each of its passes.
%hook _TtC16Home_EvoPageImpl33EvoLoadableResourceViewController
- (void)viewDidLayoutSubviews {
    %orig;
    UIView *view = ((UIViewController *)self).viewIfLoaded;
    if (!asm_vitrine_pageView || !view.window || ![view isDescendantOfView:asm_vitrine_pageView]) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:UICollectionView.class]) {
            if (sub != asm_vitrine_feed) followFeed((UIScrollView *)sub);
            break;
        }
    }
}
%end

%hook _TtC19Home_FunkisPageImpl20FunkisViewController
- (void)viewDidLayoutSubviews {
    %orig;
    CFTimeInterval began = ASMVitrineRHomeProbeBegin();
    layoutHeader((UIViewController *)self);
    ASMVitrineRHomeProbeEnd(ASMVitrineRHomeProbeHeader, began);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig;
    [((UIViewController *)self).viewIfLoaded setNeedsLayout];
}
%end

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    %init;
    ASMVitrineRequireClasses(@[
        @"_TtC19Home_FunkisPageImpl20FunkisViewController",
        @"_TtC16Home_EvoPageImpl33EvoLoadableResourceViewController",
        @"_TtC29ListeningActivity_ElementsKit21AdaptiveFaceContainer",
    ]);
}
