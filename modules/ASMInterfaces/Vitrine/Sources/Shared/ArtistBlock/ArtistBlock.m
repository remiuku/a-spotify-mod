#import "ArtistBlock.h"
#import "Headers/SPTPlayer.h"

NSString *const ASMVitrineArtistURI = @"uri";
NSString *const ASMVitrineArtistName = @"name";

static const NSInteger kMaxCredits = 32;

NSArray<NSDictionary *> *ASMVitrineBlockedArtists(void) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:ASMVitrineKeyArtistBlockList];
    return list ?: @[];
}

static void save(NSArray<NSDictionary *> *list) {
    [NSUserDefaults.standardUserDefaults setObject:list forKey:ASMVitrineKeyArtistBlockList];
}

BOOL ASMVitrineArtistBlocked(NSString *uri) {
    if (!uri.length) return NO;
    for (NSDictionary *artist in ASMVitrineBlockedArtists()) {
        if ([artist[ASMVitrineArtistURI] isEqualToString:uri]) return YES;
    }
    return NO;
}

void ASMVitrineBlockArtist(NSDictionary *artist) {
    if (ASMVitrineArtistBlocked(artist[ASMVitrineArtistURI])) return;
    save([ASMVitrineBlockedArtists() arrayByAddingObject:artist]);
}

void ASMVitrineUnblockArtist(NSString *uri) {
    NSPredicate *other = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *artist, NSDictionary *bindings) {
        return ![artist[ASMVitrineArtistURI] isEqualToString:uri];
    }];
    save([ASMVitrineBlockedArtists() filteredArrayUsingPredicate:other]);
}

static NSString *uriString(id value) {
    if ([value isKindOfClass:NSURL.class]) return ((NSURL *)value).absoluteString;
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static void addArtist(NSMutableArray<NSDictionary *> *artists, NSString *uri, NSString *name) {
    if (![uri hasPrefix:@"spotify:artist:"]) return;
    for (NSDictionary *artist in artists) {
        if ([artist[ASMVitrineArtistURI] isEqualToString:uri]) return;
    }
    [artists addObject:@{ASMVitrineArtistURI: uri, ASMVitrineArtistName: name.length ? name : uri}];
}

static NSString *nameString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

NSArray<NSDictionary *> *ASMVitrineArtistsOfTrack(id object) {
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
