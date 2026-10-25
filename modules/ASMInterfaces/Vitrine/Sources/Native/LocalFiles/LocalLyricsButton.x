// A lyrics button on the player's footer for a local file with an LRC file linked to it (LocalLyrics.h).
//
// NowPlaying_ModesImpl's units are child controllers whose views hold one row each (Native/Player/
// Player.x); the footer's is FooterElementsUnit (-viewDidLoad, objc-methods). The button is the mod's
// own view on the unit's view, not one of the row's, so it is free to hide. It sits a fifth of the way
// in from the leading edge, mirrored for a right-to-left language by the leading and trailing anchors.
//
// The track's metadata also says has_lyrics "true" for such a file, so the player builds its lyrics
// affordance. Spotify's Now Playing lyrics service (Lyrics_NPVElementsKitImpl.NPVElementsKitServiceImpl)
// is not told the same: its hasLyrics is a Swift protocol requirement with no Objective-C method on the
// class or its protocols in the binary, so Swift reaches it through its witness table and a method added
// for a hook would never be called.
#import "Core/ASMVitrineCore.h"
#import "Headers/SPTPlayer.h"
#import "Shared/LocalFiles/LocalFiles.h"
#import "Shared/LocalFiles/LocalLyrics.h"
#import "Shared/Player/PlayerState.h"
#import "LocalLyrics.h"

static NSHashTable<UIButton *> *asm_vitrine_buttons;

static BOOL playingLinked(void) {
    return ASMVitrineImportedLRCLinkedTo(ASMVitrineURIString(ASMVitrinePlayerState().track.URI)) != nil;
}

static void showButtons(void) {
    BOOL linked = playingLinked();
    for (UIButton *button in asm_vitrine_buttons) button.hidden = !linked;
}

@interface ASMVitrineLocalLyricsButtons : NSObject <ASMVitrinePlayerStateObserver>
@end

@implementation ASMVitrineLocalLyricsButtons
- (void)playerStateDidChange:(SPTPlayerState *)state {
    showButtons();
}
@end

static void addButton(UIViewController *unit) {
    UIView *host = unit.view;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:@"quote.bubble" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular]]
            forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.accessibilityLabel = @"Lyrics";
    button.translatesAutoresizingMaskIntoConstraints = NO;
    __weak UIViewController *weakUnit = unit;
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        [weakUnit presentViewController:ASMVitrineLocalLyricsPage() animated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:button];

    UILayoutGuide *fifth = [UILayoutGuide new];
    [host addLayoutGuide:fifth];
    [NSLayoutConstraint activateConstraints:@[
        [fifth.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
        [fifth.widthAnchor constraintEqualToAnchor:host.widthAnchor multiplier:0.2],
        [fifth.topAnchor constraintEqualToAnchor:host.topAnchor],
        [fifth.heightAnchor constraintEqualToConstant:0],
        [button.centerXAnchor constraintEqualToAnchor:fifth.trailingAnchor],
        [button.centerYAnchor constraintEqualToAnchor:host.centerYAnchor],
        [button.widthAnchor constraintEqualToConstant:44],
        [button.heightAnchor constraintEqualToConstant:44],
    ]];
    [asm_vitrine_buttons addObject:button];
    button.hidden = !playingLinked();
}

%hook _TtC20NowPlaying_ModesImpl18FooterElementsUnit
- (void)viewDidLoad {
    %orig;
    addButton((UIViewController *)self);
}
%end

// Read for every track in every list many times a second: a prefix check for any other track.
%hook SPTPlayerTrack
- (NSDictionary *)metadata {
    NSDictionary *metadata = %orig;
    NSString *uri = ASMVitrineURIString(self.URI);
    if (!ASMVitrineLocalFileIs(uri) || [@"true" isEqual:metadata[@"has_lyrics"]] || !ASMVitrineImportedLRCLinkedTo(uri)) return metadata;
    NSMutableDictionary *linked = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
    linked[@"has_lyrics"] = @"true";
    return linked;
}
%end

%ctor {
    if (!(NO)) return; // ASM: one UI owner; host owns shared effects.

    if (!ASMVitrineNativeUI()) return;
    %init;
    asm_vitrine_buttons = [NSHashTable weakObjectsHashTable];
    static ASMVitrineLocalLyricsButtons *observer;
    observer = [ASMVitrineLocalLyricsButtons new];
    ASMVitrineAddPlayerStateObserver(observer);
    // An import for the track playing, or the delete of its file, changes the button with no new track.
    [NSNotificationCenter.defaultCenter addObserverForName:ASMVitrineImportedLRCDidChangeNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { showButtons(); }];
    ASMVitrineRequireClasses(@[@"_TtC20NowPlaying_ModesImpl18FooterElementsUnit", @"SPTPlayerTrack"]);
}
