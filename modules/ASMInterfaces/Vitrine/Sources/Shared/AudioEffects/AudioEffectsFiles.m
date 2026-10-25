// The audio effects' file libraries: Documents/Vitrine/Audio effects/<Convolver|DDC|Liveprog>, where the
// file effects find their files by name. Documents, which the app's backups keep. Every file in them is
// one the user imported.
//
// Threading: any thread (the engine's queue reads the paths too); a library is made once.
#import <os/lock.h>
#import "Core/ASMVitrineCore.h"
#import "AudioEffects.h"
#import "AudioEffectsApply.h"

static NSString *const ASMVitrineDSPFileErrorDomain = @"asm.interface.vitrine.dsp.files";

static NSString *libraryName(ASMVitrineDSPFileKind kind) {
    switch (kind) {
    case ASMVitrineDSPFileImpulseResponse: return @"Convolver";
    case ASMVitrineDSPFileDDC: return @"DDC";
    case ASMVitrineDSPFileLiveprog: return @"Liveprog";
    }
    return @"Other";
}

// The key naming the file an effect uses, and its switch, for a library.
static NSString *fileKey(ASMVitrineDSPFileKind kind) {
    switch (kind) {
    case ASMVitrineDSPFileImpulseResponse: return ASMVitrineKeyDSPConvolverFile;
    case ASMVitrineDSPFileDDC: return ASMVitrineKeyDSPDDCFile;
    case ASMVitrineDSPFileLiveprog: return ASMVitrineKeyDSPLiveprogFile;
    }
    return nil;
}

NSArray<NSString *> *ASMVitrineDSPFileExtensions(ASMVitrineDSPFileKind kind) {
    switch (kind) {
    case ASMVitrineDSPFileImpulseResponse: return @[@"wav", @"flac", @"irs"];
    case ASMVitrineDSPFileDDC: return @[@"vdc"];
    case ASMVitrineDSPFileLiveprog: return @[@"eel"];
    }
    return @[];
}

// Files imported into the library's earlier home move over once; the ones the old engine installed itself stay.
static void adoptEarlierLibrary(ASMVitrineDSPFileKind kind, NSString *documents, NSString *directory) {
    static NSSet<NSString *> *installedByEngine;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        installedByEngine = [NSSet setWithArray:@[
            @"Butterworth.vdc", @"FrontRearContrast.vdc", @"mh750.vdc", @"3bandSplitting.eel", @"8bandSplitting.eel",
            @"Joe0Bloggs DRX10K compander-HR.eel", @"audioGlitchGenerator.eel", @"autoWideness.eel",
            @"autopeakfilter.eel", @"butterworth3Band.eel", @"butterworth8Band.eel", @"dc_remove.eel", @"decimate.eel",
            @"delayChorus.eel", @"depthsurround.eel", @"downmixer.eel", @"fftConvolution2x4x2.eel",
            @"fftConvolutionHRTF.eel", @"firFilter.eel", @"firlsProc.eel", @"fractionalDelayline.eel",
            @"gainControl.eel", @"hadamVerb.eel", @"highpass.eel", @"lofiDistortionMangler.eel", @"lowpass.eel",
            @"metallic-reverb.eel", @"msCentreBoost.eel", @"phaseshifter.eel", @"pitchDownshift.eel",
            @"polyphaseFilterbank.eel", @"polyphaseFilterbankEqualization.eel", @"stereoFieldManipulator.eel",
            @"stereoPhaseInvert.eel", @"stereowide.eel", @"stftCentreBoost.eel", @"stftCentreCut.eel",
            @"stftDenoise.eel", @"stftFilter.eel", @"swapChannels.eel", @"timeAdjustment.eel",
            @"viper_dynamicbass.eel", @"viper_dynamicbass_preset.eel"
        ]];
    });
    NSFileManager *files = NSFileManager.defaultManager;
    NSUInteger moved = 0;
    for (NSString *home in @[@"spoti.pw/JamesDSP", @"spoti.pw/Audio effects"]) {
        NSString *earlier = [[documents stringByAppendingPathComponent:home] stringByAppendingPathComponent:libraryName(kind)];
        for (NSString *name in [files contentsOfDirectoryAtPath:earlier error:nil]) {
            if ([name hasPrefix:@"."] || [installedByEngine containsObject:name]) continue;
            NSString *from = [earlier stringByAppendingPathComponent:name];
            BOOL isDirectory = NO;
            if (![files fileExistsAtPath:from isDirectory:&isDirectory] || isDirectory) continue;
            if ([files moveItemAtPath:from toPath:[directory stringByAppendingPathComponent:name] error:nil]) moved++;
        }
    }
    if (moved) ASMVitrineLog(@"dsp: %lu files moved into the %@ library", (unsigned long)moved, libraryName(kind));
}

NSString *ASMVitrineDSPLibraryDirectory(ASMVitrineDSPFileKind kind) {
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *directory = [[documents stringByAppendingPathComponent:@"Vitrine/Audio effects"] stringByAppendingPathComponent:libraryName(kind)];
    os_unfair_lock_lock(&lock);
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) {
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            ASMVitrineLog(@"dsp: the %@ library could not be made: %@", libraryName(kind), error);
        } else {
            adoptEarlierLibrary(kind, documents, directory);
        }
    }
    os_unfair_lock_unlock(&lock);
    return directory;
}

NSArray<NSString *> *ASMVitrineDSPLibraryFiles(ASMVitrineDSPFileKind kind) {
    NSString *directory = ASMVitrineDSPLibraryDirectory(kind);
    NSArray<NSString *> *extensions = ASMVitrineDSPFileExtensions(kind);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil]) {
        if ([name hasPrefix:@"."] || ![extensions containsObject:name.pathExtension.lowercaseString]) continue;
        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:name] isDirectory:&isDirectory] && !isDirectory) {
            [names addObject:name];
        }
    }
    return [names sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}

static NSError *fileError(NSString *message) {
    return [NSError errorWithDomain:ASMVitrineDSPFileErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

// Whether the bytes look like a file of the kind, before it goes into the library: a WAV (RIFF, RF64) or
// FLAC stream, a DDC file's two rates, a Liveprog script's @sample section.
static BOOL looksLike(ASMVitrineDSPFileKind kind, NSData *data) {
    if (kind == ASMVitrineDSPFileImpulseResponse) {
        if (data.length < 12) return NO;
        const char *bytes = data.bytes;
        return !memcmp(bytes, "RIFF", 4) || !memcmp(bytes, "RF64", 4) || !memcmp(bytes, "fLaC", 4);
    }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
                     ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (kind == ASMVitrineDSPFileDDC) return [text containsString:@"SR_44100"] && [text containsString:@"SR_48000"];
    return [text containsString:@"@sample"];
}

NSString *ASMVitrineDSPImportFile(ASMVitrineDSPFileKind kind, NSURL *url, NSError **error) {
    NSString *name = url.lastPathComponent;
    NSArray<NSString *> *extensions = ASMVitrineDSPFileExtensions(kind);
    NSString *kindName = kind == ASMVitrineDSPFileImpulseResponse ? @"an impulse response" : kind == ASMVitrineDSPFileDDC ? @"a DDC file" : @"a Liveprog script";
    if (!name.length || [name hasPrefix:@"."] || ![extensions containsObject:name.pathExtension.lowercaseString]) {
        if (error) *error = fileError([NSString stringWithFormat:@"%@ is not %@ (.%@)", name ?: @"The file", kindName,
                                       [extensions componentsJoinedByString:@", ."]]);
        return nil;
    }
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&readError];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data) {
        if (error) *error = readError ?: fileError([NSString stringWithFormat:@"%@ could not be read", name]);
        return nil;
    }
    if (!looksLike(kind, data)) {
        if (error) *error = fileError([NSString stringWithFormat:@"%@ is not %@", name, kindName]);
        return nil;
    }
    NSString *path = [ASMVitrineDSPLibraryDirectory(kind) stringByAppendingPathComponent:name];
    NSError *writeError = nil;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
        if (error) *error = writeError;
        return nil;
    }
    ASMVitrineLog(@"dsp: %@ added to the %@ library (%lu bytes)", name, libraryName(kind), (unsigned long)data.length);
    // A file replaced while an effect uses it is read again.
    if ([ASMVitrineDSPString(fileKey(kind)) isEqualToString:name]) ASMVitrineDSPApply(ASMVitrineDSPEffectOf(fileKey(kind)));
    return name;
}

BOOL ASMVitrineDSPDeleteFile(ASMVitrineDSPFileKind kind, NSString *name) {
    if (!name.length || ![name.lastPathComponent isEqualToString:name] || [name hasPrefix:@"."]) return NO;
    NSString *path = [ASMVitrineDSPLibraryDirectory(kind) stringByAppendingPathComponent:name];
    NSError *error = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:path error:&error]) {
        ASMVitrineLog(@"dsp: %@ could not be deleted: %@", name, error);
        return NO;
    }
    ASMVitrineLog(@"dsp: %@ deleted from the %@ library", name, libraryName(kind));
    // The effect using it lets it go (and says the file is gone).
    if ([ASMVitrineDSPString(fileKey(kind)) isEqualToString:name]) ASMVitrineDSPApply(ASMVitrineDSPEffectOf(fileKey(kind)));
    return YES;
}
