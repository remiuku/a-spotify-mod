// The flags the redesign is built on. A redesigned screen, and the glass design Spotify ships switched
// off (ASMVitrineRGlassDesign.x), register theirs from a %ctor whether or not Redesigned UI is on: the settings
// rows need the list to lock theirs. Only while Redesigned UI was on at launch is anything forced,
// and then over an override from the All flags page too (Core/ASMVitrineFlagForce.h). The switch itself is
// Core/ASMVitrineUIMode.h's.
// Threading: register from a %ctor, before Spotify reads a flag.
#import <Foundation/Foundation.h>

void ASMVitrineRedesignForceFlags(NSString *owner, NSDictionary<NSString *, id> *flags);
