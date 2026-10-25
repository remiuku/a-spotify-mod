// The redesign's design tokens: every redesigned screen takes its colours, type, spacing, radii and
// motion from here, so the screens read as one app and nothing is tuned per screen by hand.
//
// Colours are white over the artwork field (ASMSpotiRField.h), whose colour is kept dark enough that
// ASMSpotiRPrimary and ASMSpotiRSecondary both pass WCAG AA on it. Type is the system font (SF Pro) sized by the
// text style and capped, since Spotify's pages lay out for a fixed header height. Motion is springs,
// critically damped for layout and a little bounce for press feedback; under Reduce Motion both
// become instant, while crossfades stay, a fade not being motion.
//
// Threading: the constants and the colours are safe anywhere; fonts, ASMSpotiRAnimate and the
// accessibility reads are main thread only.
#import <UIKit/UIKit.h>

extern const CGFloat ASMSpotiRSideMargin;      // 16, the page's side margin
extern const CGFloat ASMSpotiRGrid;            // 8, every gap is a multiple of it
extern const CGFloat ASMSpotiRRadiusArtwork;   // 12, the player's cover
extern const CGFloat ASMSpotiRRadiusCard;      // 16, a content card
extern const CGFloat ASMSpotiRRadiusCover;     // 8, a release cover in a list
extern const CGFloat ASMSpotiRRadiusThumb;     // 6, a row's thumbnail up to 64pt
extern const CGFloat ASMSpotiRGlassCircleSize; // 44, a round glass behind a top bar button
extern const CGFloat ASMSpotiRActionHeight;    // 48, a button of the action row under a hero
extern const CGFloat ASMSpotiRActionSpacing;   // 12, between the buttons of an action row
extern const CGFloat ASMSpotiRGlassSpacing;    // 16, how near two glass shapes merge in one container
extern const NSTimeInterval ASMSpotiRCrossfade;   // 0.35, a new image or field colour fading in

UIColor *ASMSpotiRPrimary(void);      // white
UIColor *ASMSpotiRSecondary(void);    // white 65%, 80% with Increase Contrast
UIColor *ASMSpotiRTertiary(void);     // white 40%, 60% with Increase Contrast
UIColor *ASMSpotiRAccent(void);       // the accent colour of Appearance, else Spotify's green
UIColor *ASMSpotiRNeutralField(void); // #121212, the field before a colour arrives; ASMSpotiRAmoled.x turns it black
// Where glass cannot be (Reduce Transparency), the shape it would have had: white 16% over the field.
UIColor *ASMSpotiRSolidGlassFill(void);
// A content surface on the field (a card), a step lighter than the field it sits on.
UIColor *ASMSpotiRElevated(UIColor *field);
// The line between two rows of a list, drawn a pixel thick from the text's leading edge: white 12%, 20% with
// Increase Contrast. Never a border around anything -- the redesign's surfaces are told apart by their fill.
UIColor *ASMSpotiRHairline(void);

// The system font at the size `style` has for the current content size category, but never larger
// than it has at `largest`, in `weight`. Callers re-ask on traitCollectionDidChange:.
UIFont *ASMSpotiRFont(UIFontTextStyle style, UIFontWeight weight, UIContentSizeCategory largest);
// The same font with digits of one width, so a time or a count does not twitch as it changes.
UIFont *ASMSpotiRMonospacedDigitsFont(UIFont *font);

BOOL ASMSpotiRReduceMotion(void);
BOOL ASMSpotiRReduceTransparency(void);
BOOL ASMSpotiRIncreaseContrast(void);

typedef NS_ENUM(NSInteger, ASMSpotiRMotion) {
    ASMSpotiRMotionLayout,   // a spring with no overshoot, for anything moving or resizing
    ASMSpotiRMotionPress,    // a spring with a little bounce, for press feedback
    ASMSpotiRMotionFade,     // an ease in and out over ASMSpotiRCrossfade, kept under Reduce Motion
};
// Runs `animations` with the motion's timing, or at once under Reduce Motion (except a fade), and
// always calls `completion`. Only transform, alpha and colour belong in it while a page scrolls.
void ASMSpotiRAnimate(ASMSpotiRMotion motion, void (^animations)(void), void (^completion)(BOOL finished));
