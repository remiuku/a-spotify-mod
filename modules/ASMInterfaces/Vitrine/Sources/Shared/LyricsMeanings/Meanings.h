// What the lines mean: Genius's annotations on the song, matched by their text to the lines the
// lyrics view shows, whichever source those came from. Genius's own web endpoints, which take no key.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"

// Whose annotations show, as ASMVitrineLyricsMeaningsLevel; unset is off.
#define ASMVitrineKeyLyricsMeanings @"asm.interface.vitrine.lyricsMeanings"

typedef NS_ENUM(NSInteger, ASMVitrineLyricsMeaningsLevel) {
    ASMVitrineLyricsMeaningsOff = 0,
    ASMVitrineLyricsMeaningsArtist,    // written or verified by the artist
    ASMVitrineLyricsMeaningsEditors,   // and the ones Genius's editors accepted
    ASMVitrineLyricsMeaningsAll,       // and the community's not yet reviewed
};

// Ordered as they are listed, the artist's first.
typedef NS_ENUM(NSUInteger, ASMVitrineLyricsMeaningAuthor) {
    ASMVitrineLyricsMeaningByArtist = 0,
    ASMVitrineLyricsMeaningByEditors,
    ASMVitrineLyricsMeaningByCommunity,
};

@interface ASMVitrineLyricsMeaning : NSObject
@property (nonatomic, copy) NSString *fragment;   // the words it explains, as Genius has them
@property (nonatomic, copy) NSString *body;
@property (nonatomic) ASMVitrineLyricsMeaningAuthor author;
@property (nonatomic, copy) NSString *url;
@end

ASMVitrineLyricsMeaningsLevel ASMVitrineLyricsMeaningsShown(void);
@class ASMVitrineModRow;
ASMVitrineModRow *ASMVitrineLyricsMeaningsRow(void);

// The meanings of the lines by index into `lines`, on the main queue: empty when Genius has none for
// the song or it could not be told apart, never called while the setting is off. Genius is asked once
// per track; the matching is done again for each set of lines.
void ASMVitrineLyricsMeaningsFor(NSString *trackID, NSArray<ASMVitrineKaraokeLine *> *lines,
                         void (^done)(NSDictionary<NSNumber *, NSArray<ASMVitrineLyricsMeaning *> *> *byLine));
