// Which of the two looks runs: Spotify's own screens with the mod's tweaks on them (Native/), or the
// redesign (Redesigned/), picked by Redesigned UI at the top of Mod Settings. What does not draw on Spotify's
// screens (Shared/) runs under both. The switch is read once, the first time anything asks, so the
// hooks, the flags and the pages see one answer for the whole launch and a change waits for the restart.
//
// Every hook file of Native/ starts its %ctor with `if (!ASMVitrineNativeUI()) return;`, every one of
// Redesigned/ with `if (!ASMVitrineRedesignedUI()) return;`: the two never run together, which is what lets
// each hook the same Spotify class in its own way.
// Threading: safe from any thread.
#import <Foundation/Foundation.h>

#define ASMVitrineKeyRedesign @"asm.interface.vitrine.redesign"

// The redesign is Liquid Glass, and Liquid Glass is UIGlassEffect, which the system renders and which
// no older OS can be given. Below iOS 26 the glass calls in Core/ASMVitrineGlass.m and Redesigned/Kit/ASMVitrineRGlass.m
// fall back to a blur, and the redesign runs untested against an older UIKit (issue #37, iOS 17: a
// scene-update watchdog hang). So below 26 it runs only after a warning has been accepted, which stores
// ASMVitrineKeyRedesignUntested (App/Pages.m's ASMVitrineSetRedesignedUI does it), and only while it starts: a launch
// whose main queue neither ran for 15 s nor saw Spotify leave the front is followed by one in the native
// look, with both switches off and ASMVitrineRedesignFellBack() answering YES for the App layer to say so.
#define ASMVitrineKeyRedesignUntested @"asm.interface.vitrine.redesign.untested"

// Whether this OS has the redesign's material: iOS 26 and up.
BOOL ASMVitrineRedesignAvailable(void);
// The redesign was on below iOS 26, and the last launch with it did not get going: this one is native.
BOOL ASMVitrineRedesignFellBack(void);

BOOL ASMVitrineRedesignedUI(void);
BOOL ASMVitrineNativeUI(void);
// The stored switch rather than the launch's (below iOS 26, with the warning accepted), for settings pages opened after it was flipped: they
// show what the restart will bring.
BOOL ASMVitrineRedesignedUIStored(void);
