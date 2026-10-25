#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
NSData *_Nullable EeveeMildInflate(NSData *data);
void EeveeMildQRCDecrypt(uint8_t *data, size_t count);

void EeveeSBInvokeSeekDouble(id target, SEL selector, double argument);
BOOL EeveeKaraokeSeekToSeconds(id player, double seconds);
NSString *EeveeJBRootPath(NSString *path);
BOOL EeveeSetMainInfoValue(NSString *key, id value);
UIImage *_Nullable EeveeRenderTemplate(UIView *view);
UIImage *_Nullable EeveeEncoreIconImage(UIView *iconView, BOOL active);
BOOL EeveeFireTap(UIView *root);
BOOL EeveeFireButtonTap(UIControl *control);
int EeveeInstallColorSwaps(BOOL amoled, NSInteger accentRGB);
void EeveeColorSwapStats(long *grey, long *green, long *uiColor);
BOOL EeveePinSetter(id object, SEL setter, id value);
BOOL EeveeInterceptBackground(UIView *view, void (^sink)(UIColor *color));

NS_ASSUME_NONNULL_END
