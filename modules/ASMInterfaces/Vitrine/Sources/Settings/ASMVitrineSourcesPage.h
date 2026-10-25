// A page that orders sources, the lyrics' and the animated artwork's: drag them into the order they are
// asked; the ones below the line are off, and a tap moves one across.
#import <UIKit/UIKit.h>

@interface ASMVitrineSource : NSObject
@property (nonatomic, copy) NSString *key, *name, *detail;
+ (instancetype)sourceWithKey:(NSString *)key name:(NSString *)name detail:(NSString *)detail;
@end

// `all` is every source in the order the ones that are off are listed in; `order` and `setOrder` read and
// keep the keys that are on, in the order they are asked.
UIViewController *ASMVitrineSourcesPageMake(NSString *title, NSString *note, NSArray<ASMVitrineSource *> *all,
                                    NSArray<NSString *> *(^order)(void), void (^setOrder)(NSArray<NSString *> *keys));
