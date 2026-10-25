// Player redesign: the ⋯ opens the system menu (Redesigned/ContextMenu): Share, Add to playlist and Add to
// queue in a row at its top, then the player's own items here, then More with the rest of Spotify's rows. The
// player's items take over what Speed and pitch's block is on Spotify's sheet:
//
//     Speed, Pitch & Reverb   opens the sliders in a popover from the ⋯ (ASMVitrinePlayerShowSpeedPitchPanel): speed,
//                             pitch, reverb and Pitch follows speed, as on Spotify's sheet (issue #14)
//     Show Fluid Artwork, Show Animated Artwork, Show Visualizer
//                             a button for each of the two the background is not, while it is one of the
//                             three, named for what it switches to
//
// The item says under its name what is not as Spotify plays it, so the menu reads as a settings summary.
#import "Core/ASMVitrineCore.h"
#import "Redesigned/ContextMenu/ContextMenu.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/SpeedPitch.h"
#import "Player.h"

static __weak UIView *asm_vitrine_moreButton;   // the ⋯ the sliders' panel comes from

static UIImage *symbol(NSString *name) {
    return [UIImage systemImageNamed:name];
}

static NSString *speedText(double speed) {
    NSString *text = [NSString stringWithFormat:@"%.2f", speed];
    while ([text hasSuffix:@"0"]) text = [text substringToIndex:text.length - 1];
    if ([text hasSuffix:@"."]) text = [text substringToIndex:text.length - 1];
    return [text stringByAppendingString:@"×"];
}

static NSString *semitonesText(float semitones) {
    if (semitones == 0) return @"Original";
    return [NSString stringWithFormat:@"%@%.0f %@", semitones > 0 ? @"+" : @"−", fabsf(semitones), fabsf(semitones) == 1 ? @"Semitone" : @"Semitones"];
}

// While pitch follows a speed that is not normal, the speed sets the pitch and the semitones are not played
// (ASMVitrineTimePitch.h), so they stand aside, as on the sheet.
static BOOL pitchFollowing(void) {
    return ASMVitrinePlayerSpeedAllowed() && ASMVitrinePlayerPitchFollowsSpeed() && ASMVitrinePlayerSpeed() != 1;
}

// One item for the three, which says what is not as Spotify plays it, or Normal.
static UIAction *soundMenu(void) {
    NSMutableArray<NSString *> *changed = [NSMutableArray array];
    if (ASMVitrinePlayerSpeedAllowed() && fabs(ASMVitrinePlayerSpeed() - 1) >= 0.01) [changed addObject:speedText(ASMVitrinePlayerSpeed())];
    if (ASMVitrinePlayerPitchAvailable() && !pitchFollowing() && ASMVitrinePlayerPitch() != 0) [changed addObject:semitonesText(ASMVitrinePlayerPitch())];
    if (ASMVitrinePlayerReverb() > 0) [changed addObject:[NSString stringWithFormat:@"Reverb %.0f%%", ASMVitrinePlayerReverb()]];
    UIAction *open = [UIAction actionWithTitle:@"Speed, Pitch & Reverb" image:symbol(@"slider.horizontal.3") identifier:nil
                                       handler:^(UIAction *action) { ASMVitrinePlayerShowSpeedPitchPanel(asm_vitrine_moreButton); }];
    open.subtitle = changed.count ? [changed componentsJoinedByString:@", "] : @"Normal";
    return open;
}

static NSArray<UIMenuElement *> *playerItems(void) {
    NSMutableArray<UIMenuElement *> *items = [NSMutableArray arrayWithObject:soundMenu()];
    if (ASMVitrinePlayerMenuOffersAnimatedArtwork()) {
        // Buttons named for what they do, not checkmarks: the HIG's changeable label for a toggled item.
        NSArray<NSArray *> *backgrounds = @[
            @[@(ASMVitrineRPlayerBackgroundFluid), @"Show Fluid Artwork", @"drop"],
            @[@(ASMVitrineRPlayerBackgroundAnimated), @"Show Animated Artwork", @"play.rectangle.on.rectangle"],
            @[@(ASMVitrineRPlayerBackgroundVisualiser), @"Show Visualizer", @"waveform"],
        ];
        ASMVitrineRPlayerBackgroundKind current = ASMVitrineRPlayerBackground();
        for (NSArray *background in backgrounds) {
            ASMVitrineRPlayerBackgroundKind kind = [background[0] integerValue];
            if (kind == current) continue;
            [items addObject:[UIAction actionWithTitle:background[1] image:symbol(background[2]) identifier:nil
                                               handler:^(UIAction *action) { ASMVitrineRPlayerMenuSetBackground(kind); }]];
        }
    }
    return items;
}

// What the player is playing, from its URI (spotify:track:…, spotify:episode:…, spotify:local:…): a podcast's
// sheet has other rows than a song's.
static NSString *sheetKind(void) {
    NSArray<NSString *> *parts = [ASMVitrineURIString(ASMVitrinePlayerState().track.URI) componentsSeparatedByString:@":"];
    return parts.count > 2 ? parts[1] : @"";
}

void ASMVitrineRPlayerMenuWatch(UIView *button) {
    asm_vitrine_moreButton = button;
    ASMVitrineRSystemMenuWatch(button, ^NSArray<UIMenuElement *> *{ return playerItems(); }, ^NSString *{ return sheetKind(); });
}
