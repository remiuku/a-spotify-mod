// The Kit's bridge into Spotify: the now playing artwork. The player's state, its open and close and
// links are Shared's (Shared/Player/PlayerState.h, Shared/Player/PlayerEvents.h,
// Shared/Navigation/Links.h). ASMSpotiRBridges.h names the hook and why it is the one.
#import "Core/ASMSpotiCore.h"
#import "Shared/Player/PlayerEvents.h"
#import "ASMSpotiRBridges.h"
#import "ASMSpotiRedesign.h"
#import "ASMSpotiRRestyle.h"

#pragma mark - now playing artwork

NSNotificationName const ASMSpotiRNowPlayingArtworkDidChangeNotification = @"asm.interface.spotipw.redesign.nowPlayingArtworkDidChange";

// The picture published, the track it was published for, the picture it is (its key) and how it was had.
static UIImage *asm_spotipw_artwork;
static NSString *asm_spotipw_artworkURI, *asm_spotipw_artworkKey;
static ASMSpotiRArtworkQuality asm_spotipw_artworkQuality;
static NSUInteger asm_spotipw_artworkSerial;
// The playing track and the picture its metadata names.
static NSString *asm_spotipw_wantedURI, *asm_spotipw_wantedKey;
// Every picture published, held weakly, with the key it was published as. A view still showing one of
// these while another picture is wanted is showing the last track's.
static NSMapTable<UIImage *, NSString *> *asm_spotipw_published;
static NSURLSessionDataTask *asm_spotipw_fetch;

// Retries of a fetch that failed, and how long before each.
static const NSTimeInterval kFetchRetry = 2;
static const NSUInteger kFetchAttempts = 2;

static void artworkLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void artworkLog(NSString *format, ...) {
    static NSUInteger logged;
    if (logged++ >= 40) return;
    va_list args;
    va_start(args, format);
    ASMSpotiLog(@"redesign kit: artwork %@", [[NSString alloc] initWithFormat:format arguments:args]);
    va_end(args);
}

// The image id in a metadata value: spotify:image:<id>, or an https URL ending in it.
static NSString *imageIDIn(id value) {
    if (![value isKindOfClass:NSString.class] || ![value length]) return nil;
    NSString *string = value;
    if ([string hasPrefix:@"spotify:image:"]) return [string substringFromIndex:@"spotify:image:".length];
    if ([string hasPrefix:@"https://"]) return string.lastPathComponent;
    return nil;
}

// The picture a track names, largest first, and where it can be fetched from.
static NSString *pictureOf(SPTPlayerTrack *track, NSURL **url) {
    NSDictionary *metadata = [track respondsToSelector:@selector(metadata)] ? track.metadata : nil;
    if (![metadata isKindOfClass:NSDictionary.class]) return nil;
    for (NSString *field in @[@"image_xlarge_url", @"image_large_url", @"image_url", @"image_small_url"]) {
        NSString *value = metadata[field], *identifier = imageIDIn(value);
        if (!identifier) continue;
        if (url) *url = [value hasPrefix:@"https://"] ? [NSURL URLWithString:value]
                                                     : [NSURL URLWithString:[@"https://i.scdn.co/image/" stringByAppendingString:identifier]];
        // Every size of one picture shares its last 24 digits; the first 16 are the size.
        return identifier.length == 40 ? [identifier substringFromIndex:16] : identifier;
    }
    return nil;
}

static void publish(UIImage *image, NSString *key, ASMSpotiRArtworkQuality quality) {
    asm_spotipw_artwork = image;
    asm_spotipw_artworkURI = asm_spotipw_wantedURI;
    asm_spotipw_artworkKey = key;
    asm_spotipw_artworkQuality = quality;
    asm_spotipw_artworkSerial++;
    [asm_spotipw_published setObject:key forKey:image];
    [NSNotificationCenter.defaultCenter postNotificationName:ASMSpotiRNowPlayingArtworkDidChangeNotification object:nil userInfo:@{
        @"image": image,
        @"trackURI": asm_spotipw_wantedURI ?: @"",
        @"quality": @(quality),
    }];
}

static NSURLSession *artworkSession(void) {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
        // An image id is the picture's own digest, so a stored answer never goes stale.
        NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
        configuration.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:24 * 1024 * 1024
                                                               directoryURL:[caches URLByAppendingPathComponent:@"spotifyglass-artwork"]];
        configuration.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
        configuration.timeoutIntervalForRequest = 20;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

static void fetchPicture(NSString *key, NSURL *url, NSUInteger attempt) {
    CFTimeInterval started = CACurrentMediaTime();
    asm_spotipw_fetch = [artworkSession() dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        UIImage *image = data.length && status == 200 ? [UIImage imageWithData:data] : nil;
        // Decoded here, off the main thread, rather than on the first frame that draws it.
        image = image.imageByPreparingForDisplay ?: image;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error.code == NSURLErrorCancelled) return;
            // A newer track asked for another picture meanwhile: this one would put the old one back.
            if (![key isEqualToString:asm_spotipw_wantedKey]) {
                artworkLog(@"%@ came after the track moved on to %@, dropped", key, asm_spotipw_wantedKey);
                return;
            }
            if (!image) {
                artworkLog(@"%@ not fetched (%ld, %@), attempt %lu", key, (long)status, error.localizedDescription, (unsigned long)attempt + 1);
                if (attempt + 1 >= kFetchAttempts) return;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kFetchRetry * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if ([key isEqualToString:asm_spotipw_wantedKey] && !([asm_spotipw_artworkKey isEqualToString:key] && asm_spotipw_artworkQuality == ASMSpotiRArtworkQualityExact)) {
                        fetchPicture(key, url, attempt + 1);
                    }
                });
                return;
            }
            artworkLog(@"%@ fetched %.0fx%.0f in %.0f ms", key, image.size.width, image.size.height, (CACurrentMediaTime() - started) * 1000);
            publish(image, key, ASMSpotiRArtworkQualityExact);
        });
    }];
    [asm_spotipw_fetch resume];
}

// Brings the playing track's picture up to date with the player's state, and fetches a picture newly
// wanted. Called on every state report and before any view read is believed, whichever comes first.
static void followPlayer(void) {
    SPTPlayerTrack *track = ASMSpotiPlayerState().track;
    NSString *uri = ASMSpotiURIString(track.URI);
    if (!uri) return;
    // The same track is looked at again only while its metadata has named no picture yet.
    if ([uri isEqualToString:asm_spotipw_wantedURI] && ![asm_spotipw_wantedKey hasPrefix:@"track:"]) return;
    asm_spotipw_wantedURI = uri;
    NSURL *url = nil;
    // A track whose metadata names no picture is its own key: only the screens can show it then.
    NSString *key = pictureOf(track, &url) ?: [@"track:" stringByAppendingString:uri];
    if ([key isEqualToString:asm_spotipw_wantedKey]) return;
    asm_spotipw_wantedKey = key;
    [asm_spotipw_fetch cancel];
    asm_spotipw_fetch = nil;
    if ([key isEqualToString:asm_spotipw_artworkKey] && asm_spotipw_artworkQuality == ASMSpotiRArtworkQualityExact) return;
    if (url) fetchPicture(key, url, 0);
}

void ASMSpotiRSetNowPlayingArtwork(UIImage *image, NSString *trackURI, ASMSpotiRArtworkQuality quality) {
    if (!image || !trackURI) return;
    followPlayer();
    // Read for a track that is no longer playing.
    if (![trackURI isEqualToString:asm_spotipw_wantedURI]) return;
    NSString *key = asm_spotipw_wantedKey;
    NSString *publishedAs = [asm_spotipw_published objectForKey:image];
    // The screen still shows a picture published for another one.
    if (publishedAs && ![publishedAs isEqualToString:key]) {
        artworkLog(@"%@ still on screen while %@ is wanted, not believed", publishedAs, key);
        return;
    }
    if ([key isEqualToString:asm_spotipw_artworkKey] && (image == asm_spotipw_artwork || quality < asm_spotipw_artworkQuality)) return;
    publish(image, key, MIN(quality, ASMSpotiRArtworkQualityHigh));
}

UIImage *ASMSpotiRNowPlayingArtwork(NSString **trackURI, NSString **identity) {
    if (trackURI) *trackURI = asm_spotipw_artworkURI;
    // A fetched picture is known for what it is; one read off a screen is only what it looked like then,
    // so each of those is a picture of its own and a field redraws it.
    if (identity) {
        *identity = !asm_spotipw_artwork ? nil : asm_spotipw_artworkQuality == ASMSpotiRArtworkQualityExact
            ? [asm_spotipw_artworkKey stringByAppendingString:@"#exact"]
            : [NSString stringWithFormat:@"%@#%lu", asm_spotipw_artworkKey, (unsigned long)asm_spotipw_artworkSerial];
    }
    return asm_spotipw_artwork;
}

// The player's reports, in the order they come.
@interface ASMSpotiRArtworkFollower : NSObject <ASMSpotiPlayerStateObserver>
@end

@implementation ASMSpotiRArtworkFollower
- (void)playerStateDidChange:(SPTPlayerState *)state {
    followPlayer();
}
@end

static ASMSpotiRArtworkFollower *asm_spotipw_follower;

static char kBarCardKey, kBarImageKey;
static __weak UIView *asm_spotipw_barView;

static void publishBarArtwork(void) {
    UIView *card = ASMSpotiRFindByIdentifier(asm_spotipw_barView, @"SPTNowPlayingBar", &kBarCardKey);
    UIView *holder = ASMSpotiRFindByIdentifier(card, @"Encore.ImageView", &kBarImageKey);
    UIImageView *cover = nil;
    for (UIView *sub in holder.subviews) {
        if ([sub isKindOfClass:UIImageView.class]) cover = (UIImageView *)sub;
    }
    UIImage *image = cover.image;
    NSString *uri = ASMSpotiURIString(ASMSpotiPlayerState().track.URI);
    if (!image || !uri) return;
    ASMSpotiRSetNowPlayingArtwork(image, uri, ASMSpotiRArtworkQualityLow);
}

// The bar sets its picture when the image has loaded, which lays nothing out, so a track change looks
// again a few times while the picture comes in. One that loads later still is the fetch's to bring.
@interface ASMSpotiRBarArtworkWatcher : NSObject <ASMSpotiPlayerStateObserver>
@end

@implementation ASMSpotiRBarArtworkWatcher {
    NSString *_track;
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    NSString *track = ASMSpotiURIString(state.track.URI);
    if (!track || [track isEqualToString:_track]) return;
    _track = track;
    for (NSNumber *delay in @[@0, @0.3, @1, @2.5]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ publishBarArtwork(); });
    }
}

@end

static ASMSpotiRBarArtworkWatcher *asm_spotipw_barWatcher;

%group ASMSpotiRBarArtworkHooks
%hook _TtC18NowPlaying_BarImpl27NowPlayingBarViewController
- (void)viewDidLayoutSubviews {
    %orig;
    asm_spotipw_barView = ((UIViewController *)self).viewIfLoaded;
    publishBarArtwork();
}
%end
%end

#pragma mark - the player's open and close

BOOL ASMSpotiRPlayerIsTransitioning(void) {
    return ASMSpotiPlayerTransitionEnds() > 0;
}

@interface ASMSpotiRTransitionObservation : NSObject
@property (nonatomic, strong) NSArray *tokens;
@end

@implementation ASMSpotiRTransitionObservation
- (void)dealloc {
    for (id token in self.tokens) [NSNotificationCenter.defaultCenter removeObserver:token];
}
@end

static char kTransitionKey;

void ASMSpotiRObservePlayerTransition(id owner, void (^began)(id owner), void (^ended)(id owner)) {
    if (!owner) return;
    __weak id weakOwner = owner;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    NSMutableArray *tokens = [NSMutableArray array];
    if (began) {
        [tokens addObject:[center addObserverForName:ASMSpotiPlayerTransitionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            id strongOwner = weakOwner;
            if (strongOwner) began(strongOwner);
        }]];
    }
    if (ended) {
        [tokens addObject:[center addObserverForName:ASMSpotiPlayerTransitionEndedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            id strongOwner = weakOwner;
            if (strongOwner) ended(strongOwner);
        }]];
    }
    ASMSpotiRTransitionObservation *observation = [ASMSpotiRTransitionObservation new];
    observation.tokens = tokens;
    NSMutableArray *kept = objc_getAssociatedObject(owner, &kTransitionKey);
    if (!kept) {
        kept = [NSMutableArray array];
        objc_setAssociatedObject(owner, &kTransitionKey, kept, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [kept addObject:observation];
}

%ctor {
    if (!(ASMSpotiRedesignedUI())) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMSpotiRedesignedUI()) return;
    // By pointer: two images of one picture are still two reads.
    asm_spotipw_published = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
                                             valueOptions:NSPointerFunctionsStrongMemory capacity:16];
    // Ahead of the watchers, so the picture a track wants is known before any screen is read for it.
    asm_spotipw_follower = [ASMSpotiRArtworkFollower new];
    ASMSpotiAddPlayerStateObserver(asm_spotipw_follower);
    asm_spotipw_barWatcher = [ASMSpotiRBarArtworkWatcher new];
    ASMSpotiAddPlayerStateObserver(asm_spotipw_barWatcher);
    %init(ASMSpotiRBarArtworkHooks);
    ASMSpotiRequireClasses(@[@"_TtC18NowPlaying_BarImpl27NowPlayingBarViewController"]);
}
