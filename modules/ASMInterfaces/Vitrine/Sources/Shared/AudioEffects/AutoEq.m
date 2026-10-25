// AutoEq's headphone corrections, read straight from its public repository: github.com/jaakkopasanen/AutoEq,
// MIT License, Copyright (c) 2018-2022 Jaakko Pasanen. Nothing of it ships in the mod; results/INDEX.md and
// the chosen headphone's GraphicEQ file are downloaded when asked for.
//
// INDEX.md, as of October 2026, is a heading and a note, then one line per result:
//     - [1MORE Quad Driver](./crinacle/711%20in-ear/1MORE%20Quad%20Driver) by crinacle on 711
// and the folder holds "<folder's last part> GraphicEQ.txt", one "GraphicEQ: 20 -0.2; 21 -0.2; ..." line.
// The file is named after the folder, not the name in brackets: the name can carry a target the folder
// does not.
#import "Core/ASMVitrineLog.h"
#import "AudioEffects.h"
#import "AudioEffectsPresets.h"

static NSString *const kResults = @"https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/";
static const NSTimeInterval kIndexLife = 30 * 24 * 3600;

@implementation ASMVitrineAutoEqHeadphone
@end

NSArray<ASMVitrineAutoEqHeadphone *> *ASMVitrineAutoEqParseIndex(NSString *markdown) {
    NSMutableArray<ASMVitrineAutoEqHeadphone *> *headphones = [NSMutableArray array];
    [markdown enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        if (![line hasPrefix:@"- ["]) return;
        // The last "](./" and the last ") by ": names hold brackets and folders parentheses.
        NSRange link = [line rangeOfString:@"](./" options:NSBackwardsSearch];
        NSRange by = [line rangeOfString:@") by " options:NSBackwardsSearch];
        if (link.location == NSNotFound || by.location == NSNotFound || by.location <= NSMaxRange(link)) return;
        ASMVitrineAutoEqHeadphone *headphone = [ASMVitrineAutoEqHeadphone new];
        headphone.name = [line substringWithRange:NSMakeRange(3, link.location - 3)];
        headphone.path = [line substringWithRange:NSMakeRange(NSMaxRange(link), by.location - NSMaxRange(link))];
        headphone.source = [line substringFromIndex:NSMaxRange(by)];
        if (headphone.name.length && headphone.path.length) [headphones addObject:headphone];
    }];
    return headphones;
}

// Decoded and encoded again: INDEX.md leaves some characters raw ("$", "&", parentheses) that a URL may not.
NSURL *ASMVitrineAutoEqGraphicEqURL(NSString *path) {
    NSString *folder = path.stringByRemovingPercentEncoding ?: path;
    NSString *file = [NSString stringWithFormat:@"%@/%@ GraphicEQ.txt", folder, folder.lastPathComponent];
    NSString *encoded = [file stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    return encoded ? [NSURL URLWithString:[kResults stringByAppendingString:encoded]] : nil;
}

NSString *ASMVitrineAutoEqNameOf(NSString *path) {
    NSString *folder = path.stringByRemovingPercentEncoding ?: path;
    return folder.lastPathComponent;
}

NSArray<ASMVitrineAutoEqHeadphone *> *ASMVitrineAutoEqSearch(NSArray<ASMVitrineAutoEqHeadphone *> *all, NSString *query) {
    NSStringCompareOptions loose = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    NSArray<NSString *> *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    words = [words filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    if (!words.count) return all;
    NSMutableArray<ASMVitrineAutoEqHeadphone *> *found = [NSMutableArray array];
    for (ASMVitrineAutoEqHeadphone *headphone in all) {
        NSString *text = [NSString stringWithFormat:@"%@ %@", headphone.name, headphone.source];
        BOOL match = YES;
        for (NSString *word in words) match = match && [text rangeOfString:word options:loose].location != NSNotFound;
        if (match) [found addObject:headphone];
    }
    return found;
}

#pragma mark - downloads

static NSURL *cachedIndex(void) {
    NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *folder = [caches URLByAppendingPathComponent:@"Vitrine/AutoEq" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return [folder URLByAppendingPathComponent:@"INDEX.md"];
}

// The body of a 200 answer as text, or nil and why not. `done` on URLSession's queue, not the main one.
static void fetchText(NSURL *url, void (^done)(NSString *text, NSString *error)) {
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        NSString *text = status == 200 && data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSString *why = text ? nil : error ? error.localizedDescription : [NSString stringWithFormat:@"GitHub answered %ld", (long)status];
        if (why) ASMVitrineLog(@"autoeq: %@ failed (%@)", url.path, why);
        done(text, why);
    }] resume];
}

void ASMVitrineAutoEqLoadIndex(BOOL refresh, void (^done)(NSArray<ASMVitrineAutoEqHeadphone *> *, NSString *)) {
    NSURL *cache = cachedIndex();
    NSDate *saved = [NSFileManager.defaultManager attributesOfItemAtPath:cache.path error:nil].fileModificationDate;
    void (^fromCache)(NSString *) = ^(NSString *why) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSString *text = [NSString stringWithContentsOfURL:cache encoding:NSUTF8StringEncoding error:nil];
            NSArray<ASMVitrineAutoEqHeadphone *> *headphones = text ? ASMVitrineAutoEqParseIndex(text) : nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                // A failed refresh still says so over the saved list.
                done(headphones.count ? headphones : nil, why ?: (headphones.count ? nil : @"The saved list could not be read"));
            });
        });
    };
    if (saved && !refresh && -saved.timeIntervalSinceNow < kIndexLife) {
        fromCache(nil);
        return;
    }
    // Its 8850 lines are read and saved off the main thread, which has only the answer.
    fetchText([NSURL URLWithString:[kResults stringByAppendingString:@"INDEX.md"]], ^(NSString *text, NSString *error) {
        // A page that answers but holds no headphones is not kept over a good copy.
        NSArray<ASMVitrineAutoEqHeadphone *> *headphones = text ? ASMVitrineAutoEqParseIndex(text) : nil;
        if (!headphones.count) {
            fromCache(error ?: @"AutoEq's list has no headphones in it");
            return;
        }
        [text writeToURL:cache atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{ done(headphones, nil); });
    });
}

#pragma mark - a correction per output

static NSString *asm_vitrine_outputUID, *asm_vitrine_outputName;

static NSDictionary<NSString *, NSDictionary *> *outputs(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:ASMVitrineKeyDSPOutputs];
    return [value isKindOfClass:NSDictionary.class] ? value : @{};
}

static void setOutput(NSString *uid, NSDictionary *entry) {
    NSMutableDictionary *all = [outputs() mutableCopy];
    all[uid] = entry;
    [NSUserDefaults.standardUserDefaults setObject:all forKey:ASMVitrineKeyDSPOutputs];
}

static NSString *followed(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:ASMVitrineKeyDSPOutputFollowed] ?: @"";
}

static void setFollowed(NSString *uid) {
    [NSUserDefaults.standardUserDefaults setObject:uid ?: @"" forKey:ASMVitrineKeyDSPOutputFollowed];
}

static void changed(void) {
    [NSNotificationCenter.defaultCenter postNotificationName:ASMVitrineAutoEqOutputsChangedNotification object:nil];
}

// A headphone's correction is what the Graphic EQ plays, rather than nothing or the user's own curve.
static BOOL correctionInUse(void) {
    return ASMVitrineDSPSwitch(ASMVitrineKeyDSPGraphicEq) && ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone).length;
}

static void takeOff(void) {
    if (!correctionInUse()) return;
    ASMVitrineDSPSetString(ASMVitrineKeyDSPGraphicEqHeadphone, @"");
    ASMVitrineDSPSetSwitch(ASMVitrineKeyDSPGraphicEq, NO);
}

// The output playing now remembers what the Graphic EQ plays, when it is remembered.
static void rememberPick(void) {
    if (!asm_vitrine_outputUID.length || !outputs()[asm_vitrine_outputUID]) return;
    BOOL on = correctionInUse();
    setOutput(asm_vitrine_outputUID, @{@"name": asm_vitrine_outputName ?: asm_vitrine_outputUID, @"path": on ? ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone) : @"",
                              @"nodes": on ? ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqNodes) : @""});
    setFollowed(asm_vitrine_outputUID);
    changed();
}

BOOL ASMVitrineAutoEqApplyText(NSString *path, NSString *text) {
    NSString *line = ASMVitrineDSPGraphicEqLine(text);
    if (!line || !path.length) return NO;
    ASMVitrineDSPSetString(ASMVitrineKeyDSPGraphicEqNodes, line);
    ASMVitrineDSPSetString(ASMVitrineKeyDSPGraphicEqHeadphone, path);
    ASMVitrineDSPSetSwitch(ASMVitrineKeyDSPGraphicEq, YES);
    // The correction is meant to be heard: the master switch, off until asked for, comes on with it.
    if (!ASMVitrineDSPSwitch(ASMVitrineKeyDSP)) ASMVitrineDSPSetSwitch(ASMVitrineKeyDSP, YES);
    rememberPick();
    return YES;
}

void ASMVitrineAutoEqTakeOff(void) {
    takeOff();
    rememberPick();
}

void ASMVitrineAutoEqOutputChanged(NSString *uid, NSString *name) {
    if (!uid.length || [uid isEqualToString:asm_vitrine_outputUID]) return;
    asm_vitrine_outputUID = [uid copy];
    asm_vitrine_outputName = name.length ? [name copy] : asm_vitrine_outputUID;
    NSDictionary *entry = outputs()[uid];
    if (entry) {
        if (![entry[@"name"] isEqual:asm_vitrine_outputName]) {
            NSMutableDictionary *renamed = [entry mutableCopy];
            renamed[@"name"] = asm_vitrine_outputName;
            setOutput(uid, renamed);
        }
        NSString *path = entry[@"path"], *nodes = entry[@"nodes"];
        if (path.length && nodes.length) {
            ASMVitrineDSPSetString(ASMVitrineKeyDSPGraphicEqNodes, nodes);
            ASMVitrineDSPSetString(ASMVitrineKeyDSPGraphicEqHeadphone, path);
            ASMVitrineDSPSetSwitch(ASMVitrineKeyDSPGraphicEq, YES);
            ASMVitrineLog(@"autoeq: %@ connected, its correction %@ on%@", asm_vitrine_outputName, ASMVitrineAutoEqNameOf(path), ASMVitrineDSPSwitch(ASMVitrineKeyDSP) ? @"" : @" (Audio effects are off)");
        } else {
            takeOff();
            ASMVitrineLog(@"autoeq: %@ connected, None remembered for it", asm_vitrine_outputName);
        }
        setFollowed(uid);
    } else if (followed().length) {
        // The correction came on for another output; this one has none.
        if (correctionInUse()) ASMVitrineLog(@"autoeq: %@ connected, with no correction remembered: %@ off", asm_vitrine_outputName, ASMVitrineAutoEqNameOf(ASMVitrineDSPString(ASMVitrineKeyDSPGraphicEqHeadphone)));
        takeOff();
        setFollowed(@"");
    }
    changed();
}

NSString *ASMVitrineAutoEqOutputUID(void) {
    return asm_vitrine_outputUID;
}

NSString *ASMVitrineAutoEqOutputName(void) {
    return asm_vitrine_outputName;
}

void ASMVitrineAutoEqRememberOutput(BOOL remember) {
    if (!asm_vitrine_outputUID.length) return;
    if (!remember) {
        ASMVitrineAutoEqForgetOutput(asm_vitrine_outputUID);
        return;
    }
    setOutput(asm_vitrine_outputUID, @{@"name": asm_vitrine_outputName, @"path": @"", @"nodes": @""});
    rememberPick();
}

BOOL ASMVitrineAutoEqOutputRemembered(NSString *uid) {
    return uid.length && outputs()[uid] != nil;
}

// What plays stays: forgetting an output does not take its correction off now.
void ASMVitrineAutoEqForgetOutput(NSString *uid) {
    if (!uid.length) return;
    NSMutableDictionary *all = [outputs() mutableCopy];
    [all removeObjectForKey:uid];
    [NSUserDefaults.standardUserDefaults setObject:all forKey:ASMVitrineKeyDSPOutputs];
    if ([followed() isEqualToString:uid]) setFollowed(@"");
    changed();
}

NSArray<NSDictionary<NSString *, NSString *> *> *ASMVitrineAutoEqRememberedOutputs(void) {
    NSMutableArray *list = [NSMutableArray array];
    [outputs() enumerateKeysAndObjectsUsingBlock:^(NSString *uid, NSDictionary *entry, BOOL *stop) {
        if (![entry isKindOfClass:NSDictionary.class]) return;
        [list addObject:@{@"uid": uid, @"name": entry[@"name"] ?: uid, @"path": entry[@"path"] ?: @""}];
    }];
    [list sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
    return list;
}

void ASMVitrineAutoEqApply(ASMVitrineAutoEqHeadphone *headphone, void (^done)(NSString *)) {
    NSURL *url = ASMVitrineAutoEqGraphicEqURL(headphone.path);
    if (!url) {
        done(@"Its address could not be made");
        return;
    }
    fetchText(url, ^(NSString *text, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) done(error);
            else done(ASMVitrineAutoEqApplyText(headphone.path, text) ? nil : @"The file is not a GraphicEQ line");
        });
    });
}
