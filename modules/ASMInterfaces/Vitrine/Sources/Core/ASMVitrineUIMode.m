#import <UIKit/UIKit.h>
#import "ASMVitrineUIMode.h"
BOOL ASMVitrineRedesignAvailable(void) { if (@available(iOS 26.0, *)) return YES; return NO; }
BOOL ASMVitrineRedesignedUIStored(void) {
    return ASMVitrineRedesignAvailable() && [NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.mode"].length &&
        [[NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.mode"] isEqualToString:@"vitrine"];
}
BOOL ASMVitrineRedesignedUI(void) { static BOOL selected; static dispatch_once_t once; dispatch_once(&once, ^{ selected = ASMVitrineRedesignAvailable() && [[NSUserDefaults.standardUserDefaults stringForKey:@"asm.interface.launchMode"] isEqualToString:@"vitrine"]; }); return selected; }
BOOL ASMVitrineNativeUI(void) { return NO; }
BOOL ASMVitrineRedesignFellBack(void) { return NO; }
