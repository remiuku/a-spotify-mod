#pragma once
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
static inline Class ASMHost(void) { return NSClassFromString(@"ASMInterfaceHost"); }
static inline id ASMHostObject(NSString *selector) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(selector);
    return host && [host respondsToSelector:sel] ? ((id(*)(id,SEL))objc_msgSend)(host,sel) : nil;
}
static inline id ASMHostWith(NSString *selector, id argument) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(selector);
    return host && [host respondsToSelector:sel] ? ((id(*)(id,SEL,id))objc_msgSend)(host,sel,argument) : nil;
}
static inline void ASMHostAction(NSString *selector) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(selector);
    if (host && [host respondsToSelector:sel]) ((void(*)(id,SEL))objc_msgSend)(host,sel);
}
static inline BOOL ASMHostAvailable(void) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(@"customLyricsAvailable");
    return host && [host respondsToSelector:sel] && ((BOOL(*)(id,SEL))objc_msgSend)(host,sel);
}

static inline void ASMHostSend(NSString *selector, id argument) {
    Class host = ASMHost(); SEL sel = NSSelectorFromString(selector);
    if (host && [host respondsToSelector:sel]) ((void(*)(id,SEL,id))objc_msgSend)(host,sel,argument);
}
