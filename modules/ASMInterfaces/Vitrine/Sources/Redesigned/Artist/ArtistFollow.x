// Whether the user follows the page's artist, read from Spotify's collection state (following saves the
// artist to the collection) rather than the Follow button, whose only state is its localized title.
// The provider is the one Spotify's own code uses, kept weakly.
#import "Core/ASMVitrineCore.h"
#import "Artist.h"

@protocol ASMVitrineRCollectionState <NSObject>
+ (id)saved;
- (BOOL)contains:(id)state;
- (NSInteger)rawValue;
@end

@protocol ASMVitrineRCollectionStateProvider <NSObject>
- (id)subscribeCollectionStateForURL:(NSURL *)url completion:(void (^)(id state, NSError *error))completion;
@end

static __weak id asm_vitrine_provider;

// Called from wherever Spotify reaches for its provider, any thread.
static void keepProvider(id provider) {
    if (!provider || ![provider respondsToSelector:@selector(subscribeCollectionStateForURL:completion:)]) return;
    static NSMutableSet<NSString *> *logged;
    @synchronized (NSObject.class) {
        if (provider == asm_vitrine_provider) return;
        asm_vitrine_provider = provider;
        if (!logged) logged = [NSMutableSet set];
        NSString *name = NSStringFromClass([provider class]);
        if ([logged containsObject:name]) return;
        [logged addObject:name];
    }
    ASMVitrineLog(@"redesign artist: collection state from %@", NSStringFromClass([provider class]));
}

static __weak id asm_vitrine_platform;

static id currentProvider(void) {
    id provider;
    @synchronized (NSObject.class) {
        provider = asm_vitrine_provider;
    }
    if (!provider && [asm_vitrine_platform respondsToSelector:@selector(stateProvider)]) {
        provider = [asm_vitrine_platform performSelector:@selector(stateProvider)];
        keepProvider(provider);
    }
    return provider;
}

%hook SPTCollectionPlatformImplementation
- (id)initWithCosmosDataLoader:(id)loader isGatedEntityRelationsEnabled:(BOOL)gated {
    id platform = %orig;
    asm_vitrine_platform = platform;
    return platform;
}
- (id)stateProvider {
    id provider = %orig;
    keepProvider(provider);
    return provider;
}
%end

%hook _TtC23Collection_PlatformImpl22CollectionPlatformImpl
- (id)stateProvider {
    id provider = %orig;
    keepProvider(provider);
    return provider;
}
%end

%hook _TtC23Collection_PlatformImpl27CollectionPlatformMigration
- (id)stateProvider {
    id provider = %orig;
    keepProvider(provider);
    return provider;
}
%end

%hook _TtC26AlignedCuration_CommonImpl21ACUCollectionPlatform
- (id)stateProvider {
    id provider = %orig;
    keepProvider(provider);
    return provider;
}
%end

%hook _TtC23Collection_PlatformImpl35CollectionPlatformStateProviderImpl
- (id)subscribeCollectionStateForURL:(id)url completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURLs:(id)urls completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURL:(id)url inContextURL:(id)context completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURLs:(id)urls inContextURL:(id)context completion:(id)completion {
    keepProvider(self);
    return %orig;
}
%end

%hook _TtC26AlignedCuration_CommonImpl25ACUEsperantoStateProvider
- (id)subscribeCollectionStateForURL:(id)url completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURLs:(id)urls completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURL:(id)url inContextURL:(id)context completion:(id)completion {
    keepProvider(self);
    return %orig;
}
- (id)subscribeCollectionStateForURLs:(id)urls inContextURL:(id)context completion:(id)completion {
    keepProvider(self);
    return %orig;
}
%end

// The Follow element asks Curation's provider, which wraps the collection one.
%hook _TtC21Curation_PlatformImpl30CUPStateProviderImplementation
- (id)subscribeCollectionStateForURL:(id)url inContext:(id)context completion:(id)completion {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "collectionPlatformStateProvider");
    if (ivar) keepProvider(object_getIvar(self, ivar));
    return %orig;
}
%end

#pragma mark - one subscription per page

// Held by the page, so the subscription ends with it.
@interface ASMVitrineRFollowWatch : NSObject
@property (nonatomic, copy) NSURL *uri;
@property (nonatomic, strong) id token;
@property (nonatomic) BOOL subscribed;
@property (nonatomic) NSInteger following;   // -1 until the first state arrives
@property (nonatomic, copy) void (^changed)(void);
@end

@implementation ASMVitrineRFollowWatch
- (void)dealloc {
    if ([_token respondsToSelector:@selector(cancel)]) [_token cancel];
}
@end

static char kWatchKey;

// The artist the page is for. The artist page's controllers carry no URI, but the header's ⋯ does:
// Components.UI.ContextMenuButton-<artist id>.
static NSURL *artistURI(UIView *page, NSString *moreIdentifier) {
    for (UIResponder *responder = page; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class] || ![responder respondsToSelector:@selector(spt_pageURI)]) continue;
        id uri = [(id)responder performSelector:@selector(spt_pageURI)];
        if ([uri isKindOfClass:NSURL.class] && [[uri absoluteString] hasPrefix:@"spotify:artist:"]) return uri;
    }
    NSString *prefix = @"Components.UI.ContextMenuButton-";
    if (![moreIdentifier hasPrefix:prefix]) return nil;
    NSString *identifier = [moreIdentifier substringFromIndex:prefix.length];
    NSCharacterSet *base62 = [NSCharacterSet alphanumericCharacterSet].invertedSet;
    if (identifier.length != 22 || [identifier rangeOfCharacterFromSet:base62].location != NSNotFound) return nil;
    return [NSURL URLWithString:[@"spotify:artist:" stringByAppendingString:identifier]];
}

static void subscribe(ASMVitrineRFollowWatch *watch, id provider) {
    Class stateClass = NSClassFromString(@"SPTCollectionPlatformState");
    if (![stateClass respondsToSelector:@selector(saved)]) return;
    id saved = [(Class<ASMVitrineRCollectionState>)stateClass saved];
    __weak ASMVitrineRFollowWatch *weakWatch = watch;
    NSURL *uri = watch.uri;
    watch.subscribed = YES;
    ASMVitrineLog(@"redesign artist: follow subscribes for %@ on %@", uri.absoluteString, NSStringFromClass([provider class]));
    watch.token = [(id<ASMVitrineRCollectionStateProvider>)provider subscribeCollectionStateForURL:uri completion:^(id state, NSError *error) {
        if (error || ![state respondsToSelector:@selector(contains:)]) {
            ASMVitrineLog(@"redesign artist: follow state for %@ unreadable: %@ %@", uri.absoluteString, [state class], error);
            return;
        }
        NSInteger raw = [state respondsToSelector:@selector(rawValue)] ? [(id<ASMVitrineRCollectionState>)state rawValue] : -1;
        BOOL following = [(id<ASMVitrineRCollectionState>)state contains:saved];
        dispatch_async(dispatch_get_main_queue(), ^{
            ASMVitrineRFollowWatch *current = weakWatch;
            if (!current || current.following == following) return;
            ASMVitrineLog(@"redesign kit: follow state %ld for %@", (long)raw, uri.absoluteString);
            current.following = following;
            if (current.changed) current.changed();
        });
    }];
}

BOOL ASMVitrineRArtistFollowing(UIView *page, NSString *moreIdentifier, BOOL *following, void (^changed)(void)) {
    if (!page) return NO;
    ASMVitrineRFollowWatch *watch = objc_getAssociatedObject(page, &kWatchKey);
    if (!watch) {
        NSURL *uri = artistURI(page, moreIdentifier);
        if (!uri) {
            static __weak UIView *loggedPage;
            if (loggedPage != page) {
                loggedPage = page;
                ASMVitrineLog(@"redesign artist: follow has no artist URI, more is %@", moreIdentifier);
            }
            return NO;
        }
        watch = [ASMVitrineRFollowWatch new];
        watch.uri = uri;
        watch.following = -1;
        objc_setAssociatedObject(page, &kWatchKey, watch, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    watch.changed = changed;
    id provider = watch.subscribed ? nil : currentProvider();
    if (provider) subscribe(watch, provider);
    if (watch.following < 0) return NO;
    if (following) *following = watch.following == 1;
    return YES;
}

%ctor {
    if (!(ASMVitrineRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineRedesignedUI()) return;
    %init;
    ASMVitrineRequireClasses(@[@"SPTCollectionPlatformState", @"_TtC23Collection_PlatformImpl35CollectionPlatformStateProviderImpl"]);
}
