#pragma once
#import <UIKit/UIKit.h>
void ASMLockScreenInstall(void);
void ASMLockScreenPublish(NSDictionary *extras, NSString *title, NSString *artist);
NSDictionary *ASMLockScreenAnimated(NSURL *file, UIImage *preview, NSString *identifier);
BOOL ASMLockScreenAnimationAvailable(void);
