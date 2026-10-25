#import "ArtistBlock.h"
#import "Headers/SPTPlayer.h"

NSString *const ASMSpotiArtistURI = @"uri";
NSString *const ASMSpotiArtistName = @"name";

static const NSInteger kMaxCredits = 32;

NSArray<NSDictionary *> *ASMSpotiBlockedArtists(void) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:ASMSpotiKeyArtistBlockList];
    return list ?: @[];
}

static void save(NSArray<NSDictionary *> *list) {
    [NSUserDefaults.standardUserDefaults setObject:list forKey:ASMSpotiKeyArtistBlockList];
}

BOOL ASMSpotiArtistBlocked(NSString *uri) {
    if (!uri.length) return NO;
    for (NSDictionary *artist in ASMSpotiBlockedArtists()) {
        if ([artist[ASMSpotiArtistURI] isEqualToString:uri]) return YES;
    }
    return NO;
}

void ASMSpotiBlockArtist(NSDictionary *artist) {
    if (ASMSpotiArtistBlocked(artist[ASMSpotiArtistURI])) return;
    save([ASMSpotiBlockedArtists() arrayByAddingObject:artist]);
}

void ASMSpotiUnblockArtist(NSString *uri) {
    NSPredicate *other = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *artist, NSDictionary *bindings) {
        return ![artist[ASMSpotiArtistURI] isEqualToString:uri];
    }];
    save([ASMSpotiBlockedArtists() filteredArrayUsingPredicate:other]);
}

static NSString *uriString(id value) {
    if ([value isKindOfClass:NSURL.class]) return ((NSURL *)value).absoluteString;
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static void addArtist(NSMutableArray<NSDictionary *> *artists, NSString *uri, NSString *name) {
    if (![uri hasPrefix:@"spotify:artist:"]) return;
    for (NSDictionary *artist in artists) {
        if ([artist[ASMSpotiArtistURI] isEqualToString:uri]) return;
    }
    [artists addObject:@{ASMSpotiArtistURI: uri, ASMSpotiArtistName: name.length ? name : uri}];
}

static NSString *nameString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

NSArray<NSDictionary *> *ASMSpotiArtistsOfTrack(id object) {
    if (![object respondsToSelector:@selector(artistURI)] || ![object respondsToSelector:@selector(metadata)]) return @[];
    SPTPlayerTrack *track = object;
    NSDictionary *metadata = [track.metadata isKindOfClass:NSDictionary.class] ? track.metadata : nil;
    NSMutableArray<NSDictionary *> *artists = [NSMutableArray array];
    addArtist(artists, uriString(track.artistURI), nameString(track.artistName));
    addArtist(artists, uriString(metadata[@"artist_uri"]), nameString(metadata[@"artist_name"]));
    for (NSInteger i = 1; i < kMaxCredits; i++) {
        NSString *uri = uriString(metadata[[NSString stringWithFormat:@"artist_uri:%ld", (long)i]]);
        if (!uri) break;
        addArtist(artists, uri, nameString(metadata[[NSString stringWithFormat:@"artist_name:%ld", (long)i]]));
    }
    return artists;
}
