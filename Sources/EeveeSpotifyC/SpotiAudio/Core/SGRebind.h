// Adapted from spoti.pw v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a. GPL-3.0.
// See THIRD_PARTY_SPOTI_PW.md for authors, origins and local changes.
// Hooks a C function Spotify's executable imports, by pointing the executable's own import slot for it
// (its __got, or __la_symbol_ptr in an older build) at a replacement. Only calls Spotify's own code
// makes go through the new function; the system's frameworks keep calling the original. This is the
// fishhook technique, kept to Spotify's executable (including a LiveContainer MH_DYLIB guest), for the few places no Objective-C method stands
// between Spotify and a system call (the audio output unit Music Haptics listens to).
//
// Call from the constructor or main-thread startup retries. Publish the original
// function before installing its replacement, and keep successful hooks intact.
#import <Foundation/Foundation.h>

// Returns YES when at least one slot named `symbol` (without the leading underscore) was repointed.
// `original` receives what the first slot held, which is what the replacement calls on.
BOOL SGRebindImport(const char *symbol, void *replacement, void **original);
