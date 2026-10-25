// Private UIKit the SDK does not declare.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIView (ASMVitrinePrivate)
- (NSString *)recursiveDescription;
@end

@interface UIViewController (ASMVitrinePrivate)
- (NSString *)_printHierarchy;
@end
