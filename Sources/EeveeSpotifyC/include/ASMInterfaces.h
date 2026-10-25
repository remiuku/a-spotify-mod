#pragma once
#import <UIKit/UIKit.h>
BOOL ASMInterfacesLoad(void);
BOOL ASMInterfaceLoaded(NSString *mode);
UIView *ASMInterfaceLyricsView(NSString *mode);
UIViewController *ASMInterfaceSettingsPage(NSString *mode, NSString *page);
BOOL ASMOpenSpotifyLyrics(void);
NSDictionary<NSString *, id> *ASMInterfaceForcedFlags(NSString *mode);

void ASMInterfaceCloseInlineLyrics(NSString *mode);
