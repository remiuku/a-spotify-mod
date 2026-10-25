#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <math.h>
#import <string.h>
#import "Tweak.h"

BOOL EeveeKaraokeSeekToSeconds(id player, double seconds) {
    if (!player || !isfinite(seconds) || seconds < 0) return NO;
    SEL selector = NSSelectorFromString(@"seekTo:");
    if (![player respondsToSelector:selector]) return NO;

    // Confirmed on Spotify 9.1.88: -[SPTEsperantoPlayer seekTo:] is @24@0:8d16.
    // A generic performSelector: would pass an object where this ABI requires a double.
    NSMethodSignature *signature = [player methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 3 ||
        strcmp([signature getArgumentTypeAtIndex:2], @encode(double)) != 0 ||
        strcmp(signature.methodReturnType, @encode(id)) != 0) return NO;

    @try {
        typedef id (*SeekToSeconds)(id, SEL, double);
        ((SeekToSeconds)objc_msgSend)(player, selector, seconds);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"[Karaoke] player rejected line seek: %@", exception.name);
        return NO;
    }
}
