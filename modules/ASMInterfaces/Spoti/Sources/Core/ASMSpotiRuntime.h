// Private UIKit the SDK does not declare.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIView (ASMSpotiPrivate)
- (NSString *)recursiveDescription;
@end

@interface UIViewController (ASMSpotiPrivate)
- (NSString *)_printHierarchy;
@end
