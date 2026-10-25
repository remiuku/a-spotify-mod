#pragma once
#import <UIKit/UIKit.h>
#import "ASMWhimsyText.h"

BOOL ASMWhimsyIsEnabled(void);
void ASMWhimsyInitialize(void);
void ASMWhimsySetEnabled(BOOL enabled);
NSString * _Nullable ASMWhimsyDisplayText(NSString * _Nullable text);
// Keep timed fragments free of per-letter/syllable suffixes and stutters.
NSString * _Nullable ASMWhimsyDisplayLyricText(NSString * _Nullable text);
UIImage * _Nullable ASMWhimsyDisplayImage(UIImage * _Nullable image);
