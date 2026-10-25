// One font for the whole app (Fonts.x), chosen on the Appearance page under either look, and a font file
// of the user's own as one of the choices (FontImport.m).
#import <UIKit/UIKit.h>

#define ASMVitrineKeyAppFont @"asm.interface.vitrine.font"
// The imported family: its files' names in Application Support/Vitrine/Font, and the family name read from them.
// ASMVitrineKeyAppFontFile is the single file of an import from before families, moved to the list on first use.
#define ASMVitrineKeyAppFontFiles @"asm.interface.vitrine.font.files"
#define ASMVitrineKeyAppFontName @"asm.interface.vitrine.font.name"
#define ASMVitrineKeyAppFontFile @"asm.interface.vitrine.font.file"
// The family chosen under More fonts, by its name ("Avenir Next").
#define ASMVitrineKeyAppFontFamily @"asm.interface.vitrine.font.family"

typedef NS_ENUM(NSInteger, ASMVitrineAppFont) {
    ASMVitrineAppFontSpotify,   // Spotify's own, untouched
    ASMVitrineAppFontSystem,    // San Francisco
    ASMVitrineAppFontRounded,   // SF Rounded
    ASMVitrineAppFontSerif,     // New York
    ASMVitrineAppFontMono,      // SF Mono
    ASMVitrineAppFontCustom,    // the family imported from Files
    ASMVitrineAppFontFamily,    // a family iOS carries, named by ASMVitrineKeyAppFontFamily
};

ASMVitrineAppFont ASMVitrineAppFontChosen(void);
NSArray<NSString *> *ASMVitrineAppFontNames(void);   // the five built in, by ASMVitrineAppFont
NSArray<NSString *> *ASMVitrineAppFontFamilies(void);   // More fonts: the families this iPhone has of a fixed few
// Registers the imported files with Core Text for this process and answers the family name, or nil when no
// file is left or Core Text will not take them.
NSString *ASMVitrineRegisterCustomFont(void);
// The family name the faces share, or nil when they differ, one has none, or there are none.
NSString *ASMVitrineFontSingleFamily(NSArray<NSString *> *names);

@class ASMVitrineModRow;
NSArray<ASMVitrineModRow *> *ASMVitrineAppFontRows(void);   // the Font row, opening the page of choices
