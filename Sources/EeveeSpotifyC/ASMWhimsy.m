#import "ASMWhimsy.h"
#import "Tweak.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <stdatomic.h>
#import <stdbool.h>
#import <math.h>

static atomic_bool asm_enabled;
static BOOL asm_installed;
static __thread unsigned asm_applying;
static char asm_textKey, asm_imageKey, asm_highlightKey;
static NSHashTable<UILabel *> *asm_labels;
static NSHashTable<UIImageView *> *asm_images;
static void (*asm_text)(UILabel *, SEL, NSString *);
static void (*asm_attributed)(UILabel *, SEL, NSAttributedString *);
static void (*asm_image)(UIImageView *, SEL, UIImage *);
static void (*asm_highlight)(UIImageView *, SEL, UIImage *);
static void (*asm_labelWindow)(UILabel *, SEL);
static void (*asm_imageWindow)(UIImageView *, SEL);
static id asm_motionObserver;
static void visit(UIView *root);

BOOL ASMWhimsyIsEnabled(void) { return atomic_load_explicit(&asm_enabled, memory_order_relaxed); }

static atomic_uint asm_seed;
static char asm_displayTextKey, asm_displayImageKey;

static NSString *displayText(NSString *text, BOOL rich) {
    if (!ASMWhimsyIsEnabled() || !text.length || objc_getAssociatedObject(text, &asm_displayTextKey)) return text;
    const char *input=text.UTF8String;
    if (!input) return text;
    BOOL hasLetters=NO;
    for (const char *p=input; *p; p++) if ((*p>='a' && *p<='z') || (*p>='A' && *p<='Z')) { hasLetters=YES; break; }
    if (!hasLetters) return text; // Keep clocks, numbers, :3 and whitespace intact.
    static NSCache<NSString *, NSString *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache=[NSCache new]; cache.countLimit=1024; cache.totalCostLimit=1024*1024; });
    uint32_t seed=ASMUwuStableSeed(input, atomic_load(&asm_seed));
    NSString *key=[NSString stringWithFormat:@"%d/%u/%@",rich,seed,text];
    NSString *cached=[cache objectForKey:key];
    if (cached) return cached;
    size_t count=rich ? ASMUwuDecoratedText(input,seed,NULL,0) : ASMUwuText(input,NULL,0);
    if (count==SIZE_MAX) return text;
    char *bytes=malloc(count+1);
    if (!bytes) return text;
    size_t actual=rich ? ASMUwuDecoratedText(input,seed,bytes,count+1) : ASMUwuText(input,bytes,count+1);
    // Use a separate heap object so the marker never attaches to an interned
    // tagged NSString also used as original model/UI text elsewhere.
    NSString *result=[[NSMutableString alloc] initWithBytes:bytes length:MIN(actual,count) encoding:NSUTF8StringEncoding];
    free(bytes);
    if (!result) return text;
    objc_setAssociatedObject(result,&asm_displayTextKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cache setObject:result forKey:key cost:result.length*2];
    return result;
}
NSString *ASMWhimsyDisplayText(NSString *text) { return displayText(text,YES); }
NSString *ASMWhimsyDisplayLyricText(NSString *text) { return displayText(text,NO); }

// Original WebP bytes referenced by the supplied extension, bundled locally.
// No image requests are made while using the app. ImageIO downsamples decoded
// frames and caps the one animated variant at 48 frames instead of decoding its
// complete 137-frame loop into every image view.
static UIImage *boyAsset(NSUInteger variant, BOOL animated) {
    static NSCache<NSNumber *, UIImage *> *cache;
    static NSBundle *bundle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache=[NSCache new]; cache.countLimit=14; cache.totalCostLimit=12*1024*1024;
        NSString *path=[NSBundle.mainBundle pathForResource:@"EeveeSpotify" ofType:@"bundle"];
        bundle=[NSBundle bundleWithPath:path ?: EeveeJBRootPath(@"/Library/Application Support/EeveeSpotify.bundle")];
    });
    NSNumber *key=@(variant*2+(animated ? 1 : 0));
    UIImage *cached=[cache objectForKey:key];
    if (cached) return cached;
    NSURL *url=[bundle URLForResource:[NSString stringWithFormat:@"%lu",(unsigned long)variant] withExtension:@"webp" subdirectory:@"Boykisserfication"];
    if (!url) return nil;
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)url,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
    if (!source) return nil;
    size_t total=CGImageSourceGetCount(source), count=animated ? MIN(total,48) : MIN(total,1);
    NSMutableArray<UIImage *> *frames=[NSMutableArray new];
    NSTimeInterval duration=0;
    if (count>1) for (size_t i=0; i<total; i++) {
        NSDictionary *properties=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,i,NULL));
        NSDictionary *webp=properties[(__bridge NSString *)kCGImagePropertyWebPDictionary];
        NSNumber *delay=webp[(__bridge NSString *)kCGImagePropertyWebPUnclampedDelayTime] ?: webp[(__bridge NSString *)kCGImagePropertyWebPDelayTime];
        duration+=MAX(0.02,delay ? delay.doubleValue : 0.1);
    }
    NSUInteger cost=0;
    for (size_t i=0; i<count; i++) {
        size_t index=count>1 ? i*total/count : 0;
        NSDictionary *options=@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
            (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform:@YES,
            (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@(count>1 ? 192 : 512)};
        CGImageRef frame=CGImageSourceCreateThumbnailAtIndex(source,index,(__bridge CFDictionaryRef)options);
        if (frame) { cost+=CGImageGetWidth(frame)*CGImageGetHeight(frame)*4; [frames addObject:[UIImage imageWithCGImage:frame]]; CGImageRelease(frame); }
    }
    CFRelease(source);
    UIImage *result=frames.count>1 ? [UIImage animatedImageWithImages:frames duration:MAX(duration,0.1)] : frames.firstObject;
    if (result) [cache setObject:result forKey:key cost:cost];
    return result;
}

UIImage *ASMWhimsyDisplayImage(UIImage *original) {
    if (!ASMWhimsyIsEnabled() || !original || original.size.width<=0 || original.size.height<=0 || objc_getAssociatedObject(original,&asm_displayImageKey)) return original;
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache=[NSCache new]; cache.totalCostLimit=32*1024*1024; cache.countLimit=128; });
    // The same source image keeps its choice on every redraw; different image
    // identities can pick any of the seven variants. Re-enabling rerolls them.
    uintptr_t identity=(uintptr_t)original.CGImage;
    if (!identity) identity=(uintptr_t)(__bridge void *)original;
    uint32_t mixed=(uint32_t)identity^(uint32_t)(identity>>32)^atomic_load(&asm_seed);
    mixed^=mixed>>16; mixed*=0x7feb352du; mixed^=mixed>>15; mixed*=0x846ca68bu; mixed^=mixed>>16;
    NSUInteger variant=mixed%7+1;
    BOOL animate=variant==1 && !UIAccessibilityIsReduceMotionEnabled() && MAX(original.size.width,original.size.height)>=80;
    NSString *key=[NSString stringWithFormat:@"%lu/%d/%.4f/%.4f",(unsigned long)variant,animate,original.size.width,original.size.height];
    UIImage *result=[cache objectForKey:key];
    if (!result) {
        UIImage *asset=boyAsset(variant,animate);
        if (!asset) return original;
        CGFloat maxEdge=animate ? 192 : 256;
        CGFloat ratio=MIN(maxEdge/original.size.width,maxEdge/original.size.height);
        CGSize pixels=CGSizeMake(MAX(1,round(original.size.width*ratio)),MAX(1,round(original.size.height*ratio)));
        UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat]; format.scale=1;
        UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:pixels format:format];
        NSMutableArray<UIImage *> *frames=[NSMutableArray new];
        for (UIImage *frame in asset.images ?: @[asset]) {
            UIImage *bitmap=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) { [frame drawInRect:(CGRect){CGPointZero,pixels}]; }];
            UIImage *sized=[UIImage imageWithCGImage:bitmap.CGImage scale:pixels.width/original.size.width orientation:UIImageOrientationUp];
            [frames addObject:[sized imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        }
        result=frames.count>1 ? [UIImage animatedImageWithImages:frames duration:asset.duration] : frames.firstObject;
        [cache setObject:result forKey:key cost:(NSUInteger)(pixels.width*pixels.height*4*frames.count)];
    }
    UIImage *display=[result imageWithAlignmentRectInsets:original.alignmentRectInsets];
    objc_setAssociatedObject(display,&asm_displayImageKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return display;
}

static BOOL isInput(UIView *view) {
    for (UIView *current = view; current; current = current.superview) {
        NSString *name = NSStringFromClass(current.class);
        if ([current isKindOfClass:UITextField.class] || [current isKindOfClass:UITextView.class]
            || [name containsString:@"TextField"] || [name containsString:@"TextInput"] || [name containsString:@"Keyboard"]) return YES;
    }
    return NO;
}
static NSAttributedString *attributed(NSAttributedString *source) {
    if (!source) return nil;
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:@""];
    [source enumerateAttributesInRange:NSMakeRange(0, source.length) options:0 usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        NSMutableDictionary *copy = attributes.mutableCopy;
        NSTextAttachment *attachment = copy[NSAttachmentAttributeName];
        if ([attachment isKindOfClass:NSTextAttachment.class] && attachment.image) {
            NSTextAttachment *display = [NSTextAttachment new];
            display.image = ASMWhimsyDisplayImage(attachment.image); display.bounds = attachment.bounds;
            copy[NSAttachmentAttributeName] = display;
        }
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:ASMWhimsyDisplayText([source.string substringWithRange:range]) attributes:copy]];
    }];
    return result;
}
static void setText(UILabel *label, SEL selector, NSString *text) {
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread || isInput(label)) { asm_text(label, selector, text); return; }
    objc_setAssociatedObject(label, &asm_textKey, text.copy ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [asm_labels addObject:label];
    asm_applying++; asm_text(label, selector, ASMWhimsyDisplayText(text)); asm_applying--;
}
static void setAttributed(UILabel *label, SEL selector, NSAttributedString *text) {
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread || isInput(label)) { asm_attributed(label, selector, text); return; }
    objc_setAssociatedObject(label, &asm_textKey, text.copy ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [asm_labels addObject:label];
    asm_applying++; asm_attributed(label, selector, attributed(text)); asm_applying--;
}
static void setImage(UIImageView *view, SEL selector, UIImage *image) {
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread || isInput(view)) { asm_image(view, selector, image); return; }
    objc_setAssociatedObject(view, &asm_imageKey, image ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [asm_images addObject:view];
    asm_applying++; asm_image(view, selector, ASMWhimsyDisplayImage(image)); asm_applying--;
}
static void setHighlight(UIImageView *view, SEL selector, UIImage *image) {
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread || isInput(view)) { asm_highlight(view, selector, image); return; }
    objc_setAssociatedObject(view, &asm_highlightKey, image ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC); [asm_images addObject:view];
    asm_applying++; asm_highlight(view, selector, ASMWhimsyDisplayImage(image)); asm_applying--;
}
static void restoreLabel(UILabel *label) {
    id source = objc_getAssociatedObject(label, &asm_textKey);
    if ([source isKindOfClass:NSAttributedString.class]) asm_attributed(label, @selector(setAttributedText:), source);
    else if (source) asm_text(label, @selector(setText:), source == NSNull.null ? nil : source);
    objc_setAssociatedObject(label, &asm_textKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void restoreImage(UIImageView *view) {
    id source = objc_getAssociatedObject(view, &asm_imageKey), highlighted = objc_getAssociatedObject(view, &asm_highlightKey);
    if (source) asm_image(view, @selector(setImage:), source == NSNull.null ? nil : source);
    if (highlighted) asm_highlight(view, @selector(setHighlightedImage:), highlighted == NSNull.null ? nil : highlighted);
    objc_setAssociatedObject(view, &asm_imageKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &asm_highlightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void labelWindow(UILabel *label, SEL selector) {
    asm_labelWindow(label, selector);
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread) return;
    if (isInput(label)) { asm_applying++; restoreLabel(label); asm_applying--; }
    else if (label.window) visit(label);
}
static void imageWindow(UIImageView *view, SEL selector) {
    asm_imageWindow(view, selector);
    if (asm_applying || !ASMWhimsyIsEnabled() || !NSThread.isMainThread) return;
    if (isInput(view)) { asm_applying++; restoreImage(view); asm_applying--; }
    else if (view.window) visit(view);
}
static IMP installWindowMethod(Class cls, IMP hook) {
    SEL selector = @selector(didMoveToWindow);
    Method method = class_getInstanceMethod(cls, selector);
    IMP original = method_getImplementation(method);
    // Add an override for inherited implementations; never overwrite UIView's
    // base implementation when hooking just labels and image views.
    if (!class_addMethod(cls, selector, hook, method_getTypeEncoding(method))) method_setImplementation(method, hook);
    return original;
}
static void install(void) {
    if (asm_installed) return;
    asm_installed = YES;
    asm_labels = [NSHashTable weakObjectsHashTable]; asm_images = [NSHashTable weakObjectsHashTable];
    asm_text = (void *)method_setImplementation(class_getInstanceMethod(UILabel.class, @selector(setText:)), (IMP)setText);
    asm_attributed = (void *)method_setImplementation(class_getInstanceMethod(UILabel.class, @selector(setAttributedText:)), (IMP)setAttributed);
    asm_image = (void *)method_setImplementation(class_getInstanceMethod(UIImageView.class, @selector(setImage:)), (IMP)setImage);
    asm_highlight = (void *)method_setImplementation(class_getInstanceMethod(UIImageView.class, @selector(setHighlightedImage:)), (IMP)setHighlight);
    asm_labelWindow = (void *)installWindowMethod(UILabel.class, (IMP)labelWindow);
    asm_imageWindow = (void *)installWindowMethod(UIImageView.class, (IMP)imageWindow);
    asm_motionObserver=[NSNotificationCenter.defaultCenter addObserverForName:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        if (!ASMWhimsyIsEnabled()) return;
        for (UIImageView *view in asm_images.allObjects) {
            id image=objc_getAssociatedObject(view,&asm_imageKey), highlighted=objc_getAssociatedObject(view,&asm_highlightKey);
            if (image) view.image=image==NSNull.null ? nil : image;
            if (highlighted) view.highlightedImage=highlighted==NSNull.null ? nil : highlighted;
        }
    }];
}
static void visit(UIView *root) {
    if (isInput(root)) return;
    if ([root isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)root;
        if (!objc_getAssociatedObject(label, &asm_textKey)) {
            if (label.attributedText) label.attributedText = label.attributedText; else label.text = label.text;
        }
    }
    if ([root isKindOfClass:UIImageView.class]) {
        UIImageView *view = (UIImageView *)root;
        if (!objc_getAssociatedObject(view, &asm_imageKey)) view.image = view.image;
        if (!objc_getAssociatedObject(view, &asm_highlightKey)) view.highlightedImage = view.highlightedImage;
    }
    [root setNeedsDisplay];
    for (UIView *child in root.subviews) visit(child);
}
void ASMWhimsySetEnabled(BOOL enabled) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ ASMWhimsySetEnabled(enabled); }); return; }
    if (enabled == ASMWhimsyIsEnabled()) return;
    if (enabled) { install(); atomic_store(&asm_seed,arc4random()); }
    atomic_store(&asm_enabled, enabled);
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:@"asm.whimsy.enabled"];
    if (!enabled) {
        asm_applying++;
        for (UILabel *label in asm_labels.allObjects) restoreLabel(label);
        for (UIImageView *view in asm_images.allObjects) restoreImage(view);
        [asm_labels removeAllObjects]; [asm_images removeAllObjects]; asm_applying--;
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) if ([scene isKindOfClass:UIWindowScene.class]) {
        for (UIWindow *window in ((UIWindowScene *)scene).windows) { if (enabled) visit(window); else [window setNeedsDisplay]; }
    }
    [NSNotificationCenter.defaultCenter postNotificationName:@"ASMWhimsyChanged" object:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:@"ASMArtworkChanged" object:nil];
}
void ASMWhimsyInitialize(void) {
    // Opt-in per launch: a restart is also a recovery path if a screen does not
    // redraw correctly. Do not persist an app-wide prank across launches.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        atomic_store(&asm_enabled, false);
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"asm.whimsy.enabled"];
    });
}
