// Original host integration using MediaPlayer's public iOS 26 artwork API.
#import "ASMLockScreen.h"
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <objc/message.h>
static NSObject *asm_lock;
static NSDictionary *asm_base, *asm_extras;
static NSString *asm_title, *asm_artist;
static CFAbsoluteTime asm_baseAt;
static void (*asm_original)(id, SEL, NSDictionary *);
static NSDictionary *decorate(NSDictionary *info) {
    if (!info.count || !asm_extras.count || ![info[MPMediaItemPropertyTitle] isEqual:asm_title] ||
        ![(info[MPMediaItemPropertyArtist] ?: @"") isEqual:asm_artist]) return info;
    NSMutableDictionary *copy = [info mutableCopy]; [copy addEntriesFromDictionary:asm_extras]; return copy;
}
static void setInfo(id center, SEL selector, NSDictionary *info) {
    NSDictionary *shown;
    @synchronized(asm_lock) { asm_base = [info copy]; asm_baseAt = CFAbsoluteTimeGetCurrent(); shown = decorate(info); }
    asm_original(center, selector, shown);
    // Never block Spotify's metadata writer on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        Class host = NSClassFromString(@"ASMLockScreenHost"); SEL receive = NSSelectorFromString(@"receive:");
        if ([host respondsToSelector:receive]) ((void(*)(id,SEL,id))objc_msgSend)(host, receive, info);
    });
}
void ASMLockScreenInstall(void) {
    static dispatch_once_t once; dispatch_once(&once, ^{
        asm_lock = [NSObject new];
        Method method = class_getInstanceMethod(MPNowPlayingInfoCenter.class, @selector(setNowPlayingInfo:));
        if (method) asm_original = (void *)method_setImplementation(method, (IMP)setInfo);
    });
}
void ASMLockScreenPublish(NSDictionary *extras, NSString *title, NSString *artist) {
    if (!asm_original) return;
    NSMutableDictionary *current;
    @synchronized(asm_lock) {
        asm_extras = [extras copy]; asm_title = [title copy]; asm_artist = [artist copy]; current = [decorate(asm_base) mutableCopy];
        NSNumber *elapsed = asm_base[MPNowPlayingInfoPropertyElapsedPlaybackTime];
        if (elapsed) current[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(elapsed.doubleValue +
            [asm_base[MPNowPlayingInfoPropertyPlaybackRate] doubleValue] * MAX(0, CFAbsoluteTimeGetCurrent() - asm_baseAt));
    }
    asm_original(MPNowPlayingInfoCenter.defaultCenter, @selector(setNowPlayingInfo:), current);
}
BOOL ASMLockScreenAnimationAvailable(void) {
    if (@available(iOS 26.0, *)) return MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys.count > 0;
    return NO;
}
NSDictionary *ASMLockScreenAnimated(NSURL *file, UIImage *preview, NSString *identifier) {
    if (@available(iOS 26.0, *)) {
        NSArray *keys = MPNowPlayingInfoCenter.supportedAnimatedArtworkKeys;
        NSString *key = [keys containsObject:MPNowPlayingInfoProperty1x1AnimatedArtwork] ? MPNowPlayingInfoProperty1x1AnimatedArtwork : nil;
        if (!key) return @{};
        MPMediaItemAnimatedArtwork *artwork = [[MPMediaItemAnimatedArtwork alloc] initWithArtworkID:identifier
            previewImageRequestHandler:^(CGSize size, void (^done)(UIImage *)) {
                if (size.width < 1 || size.height < 1) { done(preview); return; }
                UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat]; format.scale = 1; format.opaque = YES;
                UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                    CGFloat scale = MAX(size.width / MAX(1,preview.size.width), size.height / MAX(1,preview.size.height));
                    CGSize drawn = CGSizeMake(preview.size.width * scale, preview.size.height * scale);
                    [preview drawInRect:CGRectMake((size.width-drawn.width)/2,(size.height-drawn.height)/2,drawn.width,drawn.height)];
                }]; done(image);
            } videoAssetFileURLRequestHandler:^(CGSize size, void (^done)(NSURL *)) { done(file); }];
        return @{key: artwork};
    }
    return @{};
}
