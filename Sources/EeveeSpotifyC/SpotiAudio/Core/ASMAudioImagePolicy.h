#pragma once
#include <string.h>

// LiveContainer loads the guest executable as MH_DYLIB. Never select the host
// merely because it is MH_EXECUTE, or a framework with a similar file name.
static inline int ASMAudioImageRank(const char *image, const char *executable) {
    if (!image) return 0;
    const char *leaf=strrchr(image,'/');
    if (!leaf || strcmp(leaf+1,"Spotify")) return 0;
    if ((size_t)(leaf-image)<4 || memcmp(leaf-4,".app",4)) return 0;
    return executable && !strcmp(image,executable) ? 100 : 80;
}
