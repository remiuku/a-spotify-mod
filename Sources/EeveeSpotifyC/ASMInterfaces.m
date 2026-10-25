#import "ASMInterfaces.h"
#import <dlfcn.h>

static void *asm_spoti, *asm_vitrine;
static void *loadPort(NSString *name) {
    NSString *path = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:[name stringByAppendingString:@".dylib"]];
    void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!handle) NSLog(@"[a spotify mod] %@ could not load: %s", name, dlerror());
    return handle;
}
BOOL ASMInterfacesLoad(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Both renderers can be selected under any interface. Their UI hook
        // constructors independently gate on the one launch-selected mode.
        asm_spoti = loadPort(@"ASMSpotiUI");
        asm_vitrine = loadPort(@"ASMVitrineUI");
    });
    return asm_spoti && asm_vitrine;
}
static void *port(NSString *mode) {
    if ([mode isEqualToString:@"spotipw"]) return asm_spoti;
    if ([mode isEqualToString:@"vitrine"]) return asm_vitrine;
    return NULL;
}
BOOL ASMInterfaceLoaded(NSString *mode) { return port(mode) != NULL; }
static void *factory(NSString *mode, NSString *name) {
    void *handle = port(mode);
    NSString *prefix = [mode isEqualToString:@"spotipw"] ? @"ASMSpoti" : @"ASMVitrine";
    return handle ? dlsym(handle, [[prefix stringByAppendingString:name] UTF8String]) : NULL;
}
UIView *ASMInterfaceLyricsView(NSString *mode) {
    UIView *(*make)(void) = factory(mode, @"CreateLyricsView");
    return make ? make() : nil;
}
UIViewController *ASMInterfaceSettingsPage(NSString *mode, NSString *page) {
    UIViewController *(*make)(void) = factory(mode, [NSString stringWithFormat:@"Create%@Settings", page]);
    return make ? make() : nil;
}
BOOL ASMOpenSpotifyLyrics(void) {
    // URI and entry-point identifiers verified in Spotify 9.1.88's binary.
    NSURL *uri = [NSURL URLWithString:@"spotify:lyrics:fullscreen"];
    NSInteger (*route)(NSURL *, NSString **) = asm_spoti ? dlsym(asm_spoti,"ASMSpotiSpotifyURIRoute") : NULL;
    BOOL (*open)(NSURL *) = asm_spoti ? dlsym(asm_spoti,"ASMSpotiOpenSpotifyURI") : NULL;
    if (route && open && route(uri,NULL) == 1) return open(uri);
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    for (UIWindow *window in windows) {
        NSMutableArray<UIView *> *remaining = [NSMutableArray arrayWithObject:window];
        while (remaining.count) {
            UIView *view = remaining.lastObject; [remaining removeLastObject];
            if (([view.accessibilityIdentifier isEqualToString:@"npv_lyrics_entry_point_button"] ||
                 [view.accessibilityIdentifier isEqualToString:@"lyrics-expand-button"]) && [view isKindOfClass:UIControl.class]) {
                [(UIControl *)view sendActionsForControlEvents:UIControlEventTouchUpInside];
                return YES;
            }
            [remaining addObjectsFromArray:view.subviews];
        }
    }
    return NO;
}
NSDictionary<NSString *, id> *ASMInterfaceForcedFlags(NSString *mode) {
    void *handle = port(mode);
    const char *name = [mode isEqualToString:@"spotipw"] ? "ASMSpotiRedesignSnapshot" : "ASMVitrineRedesignSnapshot";
    NSDictionary *(*snapshot)(void) = handle ? dlsym(handle,name) : NULL;
    return snapshot ? snapshot() : @{};
}

void ASMInterfaceCloseInlineLyrics(NSString *mode) {
    BOOL (*isOpen)(void) = factory(mode, @"RPlayerLyricsOpen");
    void (*toggle)(void) = factory(mode, @"RPlayerToggleLyrics");
    if (isOpen && toggle && isOpen()) toggle();
}
