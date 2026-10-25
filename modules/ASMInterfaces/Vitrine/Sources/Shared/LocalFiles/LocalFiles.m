// LocalFiles.h says what is kept and why the file is not written.
//
// Threading: the edits are read on whatever thread Spotify reads a track's metadata on, so the table is
// swapped whole under a lock; they are written on the main thread.
#import <os/lock.h>
#import "Core/ASMVitrineCore.h"
#import "LocalFiles.h"

static NSString *const kLocalPrefix = @"spotify:local:";
// A cover is kept no larger than this on its longer side; the player draws it at under half that.
static const CGFloat kCoverSide = 1200;

NSNotificationName const ASMVitrineLocalFileEditsDidChangeNotification = @"asm.interface.vitrine.localFiles.editsDidChange";

static NSDictionary<NSString *, NSDictionary *> *asm_vitrine_edits;
static os_unfair_lock asm_vitrine_lock = OS_UNFAIR_LOCK_INIT;

BOOL ASMVitrineLocalFileIs(NSString *uri) {
    return [uri isKindOfClass:NSString.class] && [uri hasPrefix:kLocalPrefix];
}

static NSDictionary<NSString *, NSDictionary *> *allEdits(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        id stored = [NSUserDefaults.standardUserDefaults dictionaryForKey:ASMVitrineKeyLocalFileEdits];
        os_unfair_lock_lock(&asm_vitrine_lock);
        asm_vitrine_edits = [stored isKindOfClass:NSDictionary.class] ? stored : @{};
        os_unfair_lock_unlock(&asm_vitrine_lock);
    });
    os_unfair_lock_lock(&asm_vitrine_lock);
    NSDictionary *edits = asm_vitrine_edits;
    os_unfair_lock_unlock(&asm_vitrine_lock);
    return edits;
}

static void storeEdits(NSDictionary<NSString *, NSDictionary *> *edits) {
    os_unfair_lock_lock(&asm_vitrine_lock);
    asm_vitrine_edits = [edits copy];
    os_unfair_lock_unlock(&asm_vitrine_lock);
    if (edits.count) [NSUserDefaults.standardUserDefaults setObject:edits forKey:ASMVitrineKeyLocalFileEdits];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:ASMVitrineKeyLocalFileEdits];
}

NSDictionary<NSString *, id> *ASMVitrineLocalFileEditFor(NSString *uri) {
    if (!ASMVitrineLocalFileIs(uri)) return nil;
    id edit = allEdits()[uri];
    return [edit isKindOfClass:NSDictionary.class] ? edit : nil;
}

NSString *ASMVitrineLocalFileLyricsKey(NSString *uri) {
    if (!ASMVitrineLocalFileIs(uri)) return nil;
    id number = ASMVitrineLocalFileEditFor(uri)[@"number"];
    return number ? [NSString stringWithFormat:@"%@#%@", uri, number] : uri;
}

#pragma mark - the URI's own names

// Form encoded: "+" is a space and the rest percent escapes, so a part never holds a raw ":".
static NSString *decoded(NSString *part) {
    NSString *spaced = [part stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    return spaced.stringByRemovingPercentEncoding ?: spaced;
}

NSDictionary<NSString *, id> *ASMVitrineLocalFileTags(NSString *uri) {
    if (!ASMVitrineLocalFileIs(uri)) return nil;
    NSArray<NSString *> *parts = [[uri substringFromIndex:kLocalPrefix.length] componentsSeparatedByString:@":"];
    if (parts.count != 4) return nil;
    NSMutableDictionary<NSString *, id> *tags = [NSMutableDictionary dictionary];
    NSString *artist = decoded(parts[0]), *album = decoded(parts[1]), *title = decoded(parts[2]);
    if (title.length) tags[@"title"] = title;
    if (artist.length) tags[@"artist"] = artist;
    if (album.length) tags[@"album"] = album;
    // A lyrics key carries "#<number>" after the seconds, which integerValue stops at.
    tags[@"seconds"] = @(MAX(parts[3].integerValue, 0));
    return tags;
}

NSDictionary<NSString *, id> *ASMVitrineLocalFileInfo(NSString *uri) {
    NSDictionary *tags = ASMVitrineLocalFileTags(uri);
    if (!tags) return nil;
    NSRange mark = [uri rangeOfString:@"#" options:NSBackwardsSearch];
    NSDictionary *edit = ASMVitrineLocalFileEditFor(mark.location == NSNotFound ? uri : [uri substringToIndex:mark.location]);
    if (!edit) return tags;
    NSMutableDictionary<NSString *, id> *info = [tags mutableCopy];
    for (NSString *field in @[@"title", @"artist", @"album"]) {
        if ([edit[field] length]) info[field] = edit[field];
    }
    return info;
}

#pragma mark - storing an edit

NSString *ASMVitrineLocalFileCoversDirectory(void) {
    static NSString *directory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Application Support rather than Documents: Spotify scans Documents for music, and the Files app shows it.
        NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        directory = [support stringByAppendingPathComponent:@"Vitrine/Local file covers"];
    });
    return directory;
}

NSString *ASMVitrineLocalFileCoverPath(NSDictionary<NSString *, id> *edit) {
    NSString *name = edit[@"cover"];
    return [name isKindOfClass:NSString.class] && name.length ? [ASMVitrineLocalFileCoversDirectory() stringByAppendingPathComponent:name] : nil;
}

static NSString *const kImagePrefix = @"spotify:localfileimage:";

NSString *ASMVitrineLocalFileCoverURL(NSString *path) {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *set = [NSCharacterSet.URLPathAllowedCharacterSet mutableCopy];
        // -[NSURL spotifyURIComponents] splits the address on ":"; "/" goes too, so the path is one plain part.
        [set removeCharactersInString:@":/"];
        allowed = set;
    });
    NSString *escaped = [path stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    return escaped ? [kImagePrefix stringByAppendingString:escaped] : nil;
}

NSString *ASMVitrineLocalFileCoverInURL(NSString *url) {
    if (![url isKindOfClass:NSString.class] || ![url hasPrefix:kImagePrefix]) return nil;
    NSString *path = [url substringFromIndex:kImagePrefix.length].stringByRemovingPercentEncoding;
    NSString *directory = [ASMVitrineLocalFileCoversDirectory() stringByAppendingString:@"/"];
    // Only a file of the covers' own, by its name alone, so no address reaches anything else.
    if (![path hasPrefix:directory] || [path substringFromIndex:directory.length].pathComponents.count != 1) return nil;
    return path;
}

static NSString *writeCover(UIImage *image) {
    CGFloat scale = MIN(1, kCoverSide / MAX(image.size.width, image.size.height));
    CGSize size = CGSizeMake(round(image.size.width * scale), round(image.size.height * scale));
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    format.opaque = YES;
    UIImage *drawn = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:(CGRect){CGPointZero, size}];
    }];
    NSData *data = UIImageJPEGRepresentation(drawn, 0.9);
    NSString *name = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"jpg"];
    NSError *error = nil;
    [NSFileManager.defaultManager createDirectoryAtPath:ASMVitrineLocalFileCoversDirectory() withIntermediateDirectories:YES attributes:nil error:&error];
    if (!data || ![data writeToFile:[ASMVitrineLocalFileCoversDirectory() stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:&error]) {
        ASMVitrineLog(@"local files: the cover was not written: %@", error);
        return nil;
    }
    return name;
}

static void changed(NSString *uri) {
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineLocalFileEditsDidChangeNotification object:uri];
}

void ASMVitrineLocalFileSaveEdit(NSString *uri, NSDictionary<NSString *, NSString *> *names, UIImage *cover, BOOL keepCover) {
    if (!ASMVitrineLocalFileIs(uri)) return;
    NSDictionary *tags = ASMVitrineLocalFileTags(uri), *old = ASMVitrineLocalFileEditFor(uri);
    NSMutableDictionary<NSString *, id> *edit = [NSMutableDictionary dictionary];
    for (NSString *field in @[@"title", @"artist", @"album"]) {
        NSString *name = [names[field] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length && ![name isEqualToString:tags[field]]) edit[field] = name;
    }
    NSString *oldCover = ASMVitrineLocalFileCoverPath(old);
    NSString *newCover = cover ? writeCover(cover) : nil;
    if (newCover) edit[@"cover"] = newCover;
    else if (keepCover && oldCover) edit[@"cover"] = old[@"cover"];
    if (oldCover && ![edit[@"cover"] isEqual:old[@"cover"]]) [NSFileManager.defaultManager removeItemAtPath:oldCover error:nil];

    // The lyrics key changes with the names only: a cover alone leaves the lyrics where they are, and the
    // file's own names go back to the bare URI, whose lyrics may still be kept.
    BOOL named = NO, renamed = NO;
    for (NSString *field in @[@"title", @"artist", @"album"]) {
        named = named || edit[field];
        renamed = renamed || !(edit[field] == old[field] || [edit[field] isEqual:old[field]]);
    }
    // Milliseconds, so no two renames of a track share a lyrics key, a reset in between or not.
    if (named) edit[@"number"] = renamed || !old[@"number"] ? @((long long)(NSDate.date.timeIntervalSince1970 * 1000)) : old[@"number"];

    NSMutableDictionary *edits = [allEdits() mutableCopy];
    if (edit.count) {
        edits[uri] = edit;
    } else {
        [edits removeObjectForKey:uri];
    }
    storeEdits(edits);
    ASMVitrineLog(@"local files: %@ %@", uri, edit.count ? [NSString stringWithFormat:@"edited: %@", edit] : @"back to its own tags");
    changed(uri);
}
