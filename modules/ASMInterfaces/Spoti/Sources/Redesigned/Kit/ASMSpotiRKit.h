// The Redesign Kit: what every part of the redesign (Redesigned/<Part>/) builds on, so the screens share
// one look and nothing is hand-rolled per screen. A screen imports this and Core/ASMSpotiCore.h.
//
//     ASMSpotiRedesign.h   Redesigned UI, the one switch, and the flags the redesigned screens force
//     ASMSpotiRTokens.h    colours, type, spacing, radii, motion, the accessibility settings
//     ASMSpotiRPalette.h   the artwork's edge colour, the field colour and the pre-blurred bitmaps
//     ASMSpotiRField.h     the artwork field behind a page
//     ASMSpotiRFlow.h      the player's moving field of the artwork's colours
//     ASMSpotiRGlass.h     glass inside Spotify's round controls
//     ASMSpotiRGlyph.h     bare glyph overlays and glyph buttons
//     ASMSpotiRActionRow.h the Play capsule and the stand-in button of a page's action row
//     ASMSpotiRDownload.h  Spotify's download state, read, and the glyph drawn for it
//     ASMSpotiRHeaderInfo.h a page header's title, creator, length, row and description, the Music app's
//     ASMSpotiRRestyle.h   keeping Spotify's views restyled: suppress, digits, lookups, shadows, firing
//                    controls, taking a list cell's paint off the field
//     ASMSpotiRBridges.h   player state, now playing artwork, the player's open and close
//     ASMSpotiRRepaint.h   the areas the redesign keeps transparent when Spotify repaints them
//     ASMSpotiRAccent.h    the redesign's accent colour; its AMOLED black is ASMSpotiRAmoled.x, always on
//
// Every hook file of the redesign starts its %ctor with `if (!ASMSpotiRedesignedUI()) return;` and every one
// of Native/ with `if (!ASMSpotiNativeUI()) return;` (Core/ASMSpotiUIMode.h), so the two looks never run together.
#import "ASMSpotiRedesign.h"
#import "ASMSpotiRTokens.h"
#import "ASMSpotiRPalette.h"
#import "ASMSpotiRField.h"
#import "ASMSpotiRFlow.h"
#import "ASMSpotiRGlass.h"
#import "ASMSpotiRGlyph.h"
#import "ASMSpotiRActionRow.h"
#import "ASMSpotiRDownload.h"
#import "ASMSpotiRHeaderInfo.h"
#import "ASMSpotiRRestyle.h"
#import "ASMSpotiRBridges.h"
#import "ASMSpotiRRepaint.h"
#import "ASMSpotiRAccent.h"
