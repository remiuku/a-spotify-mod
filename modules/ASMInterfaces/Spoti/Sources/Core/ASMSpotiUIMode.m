#import <UIKit/UIKit.h>
#import "ASMSpotiUIMode.h"
BOOL ASMSpotiRedesignAvailable(void) { if (@available(iOS 26.0, *)) return YES; return NO; }
BOOL ASMSpotiRedesignedUIStored(void) {
    return ASMSpotiRedesignAvailable() && [NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.mode"].length &&
        [[NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.mode"] isEqualToString:@"spotipw"];
}
BOOL ASMSpotiRedesignedUI(void) { static BOOL selected; static dispatch_once_t once; dispatch_once(&once, ^{ selected = ASMSpotiRedesignAvailable() && [[NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.launchMode"] isEqualToString:@"spotipw"]; }); return selected; }
BOOL ASMSpotiNativeUI(void) { return NO; }
BOOL ASMSpotiRedesignFellBack(void) { return NO; }
