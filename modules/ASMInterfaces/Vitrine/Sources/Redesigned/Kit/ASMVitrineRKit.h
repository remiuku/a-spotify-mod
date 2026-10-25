// The Redesign Kit: what every part of the redesign (Redesigned/<Part>/) builds on, so the screens share
// one look and nothing is hand-rolled per screen. A screen imports this and Core/ASMVitrineCore.h.
//
//     ASMVitrineRedesign.h   Redesigned UI, the one switch, and the flags the redesigned screens force
//     ASMVitrineRTokens.h    colors, type, spacing, radii, motion, the accessibility settings
//     ASMVitrineRPalette.h   the artwork's edge color, the field color and the pre-blurred bitmaps
//     ASMVitrineRField.h     the artwork field behind a page
//     ASMVitrineRFlow.h      the player's moving field of the artwork's colors
//     ASMVitrineRGlass.h     glass inside Spotify's round controls
//     ASMVitrineRGlyph.h     bare glyph overlays and glyph buttons
//     ASMVitrineRActionRow.h the Play capsule and the stand-in button of a page's action row
//     ASMVitrineRDownload.h  Spotify's download state, read, and the glyph drawn for it
//     ASMVitrineRHeaderInfo.h a page header's title, creator, length, row and description, the Music app's
//     ASMVitrineRRestyle.h   keeping Spotify's views restyled: suppress, digits, lookups, shadows, firing
//                    controls, taking a list cell's paint off the field
//     ASMVitrineRBridges.h   player state, now playing artwork, the player's open and close
//     ASMVitrineRRepaint.h   the areas the redesign keeps transparent when Spotify repaints them
//     ASMVitrineRAccent.h    the redesign's accent color; its AMOLED black is ASMVitrineRAmoled.x, always on
//     Settings/ASMVitrineMarquee.h  a title that glides when it is too long, every layer's, imported here for the screens
//
// Every hook file of the redesign starts its %ctor with `if (!ASMVitrineRedesignedUI()) return;` and every one
// of Native/ with `if (!ASMVitrineNativeUI()) return;` (Core/ASMVitrineUIMode.h), so the two looks never run together.
#import "ASMVitrineRedesign.h"
#import "ASMVitrineRTokens.h"
#import "ASMVitrineRPalette.h"
#import "ASMVitrineRField.h"
#import "ASMVitrineRFlow.h"
#import "ASMVitrineRGlass.h"
#import "ASMVitrineRGlyph.h"
#import "ASMVitrineRActionRow.h"
#import "ASMVitrineRDownload.h"
#import "ASMVitrineRHeaderInfo.h"
#import "ASMVitrineRRestyle.h"
#import "ASMVitrineRBridges.h"
#import "ASMVitrineRRepaint.h"
#import "ASMVitrineRAccent.h"
#import "Settings/ASMVitrineMarquee.h"
