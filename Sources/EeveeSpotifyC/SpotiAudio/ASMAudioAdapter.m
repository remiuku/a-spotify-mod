#import "ASMSpotiSupport.h"
#import "JamesDSP.h"

// Names are separate from the public wrapper header to avoid duplicate typedefs.
typedef struct { double min, max, fallback, step; } ASMDSPRange;
ASMDSPRange ASMDSPRangeFor(NSString *key) {
    SGDSPRange range = SGDSPRangeFor(key);
    return (ASMDSPRange){range.min, range.max, range.fallback, range.step};
}
NSArray<NSString *> *ASMDSPFiles(NSInteger kind) { return SGDSPLibraryFiles((SGDSPFileKind)kind); }
NSString *ASMDSPImport(NSInteger kind, NSURL *url, NSError **error) { return SGDSPImportFile((SGDSPFileKind)kind, url, error); }
BOOL ASMDSPDelete(NSInteger kind, NSString *name) { return SGDSPDeleteFile((SGDSPFileKind)kind, name); }

extern void ASMInstallSpeedPitch(void);
extern void ASMInstallJamesDSP(void);
__attribute__((constructor)) static void ASMInstallAudio(void) {
    @autoreleasepool {
        // Install in a fixed order so both replacements call their predecessor.
        ASMInstallSpeedPitch();
        ASMInstallJamesDSP();
        // Guest images may become visible after injected-library constructors.
        // Each installer retries only missing hooks and leaves the clock/chain intact.
        dispatch_async(dispatch_get_main_queue(), ^{ ASMInstallSpeedPitch(); ASMInstallJamesDSP(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{ ASMInstallSpeedPitch(); ASMInstallJamesDSP(); });
    }
}
