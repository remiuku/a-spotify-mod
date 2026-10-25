// The Vibrations sections of the Player page, under either look (App/Pages.m puts them there): a card
// per switch, the way the Audio effects page has one per effect, each opening out into its settings while
// its switch is on. Controls has its strength; Music Haptics its strength and what it follows, a choice
// that also says whether the rumble plays, rather than a switch of its own that one choice would leave
// with nothing to do.
#import "Core/ASMSpotiCore.h"
#import "Settings/ASMSpotiModPage.h"
#import "Haptics.h"

static NSString *const kMusicHapticsInfo = @"The iPhone taps along with the drums and rumbles under the bass of whatever Spotify is playing, worked out from the sound as it plays, much like Music Haptics in Apple Music.\n\nIt follows the sound this iPhone plays, through its speaker or headphones, while Spotify is open: iOS plays no haptics for an app in the background, and a song playing on another device through Connect has no sound here to follow.";

static NSArray<NSString *> *followsNames(void) {
    return @[@"Everything", @"Beat", @"Bass"];
}

static NSArray<NSString *> *followsNotes(void) {
    return @[@"A tap on each kick and snare, and a rumble under the bass",
             @"A tap on each kick and snare, no rumble",
             @"A tap on each kick, and a rumble under the bass"];
}

static void strengthRange(NSString *key, NSInteger *minimum, NSInteger *maximum) {
    BOOL music = [key isEqualToString:ASMSpotiKeyMusicStrength];
    *minimum = music ? ASMSpotiMusicStrengthMin : ASMSpotiControlStrengthMin;
    *maximum = music ? ASMSpotiMusicStrengthMax : ASMSpotiControlStrengthMax;
}

double ASMSpotiHapticsStrength(NSString *key) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return MAX(minimum, MIN(maximum, ASMSpotiInt(key, 100))) / 100.0;
}

ASMSpotiMusicFollows ASMSpotiMusicHapticsFollows(void) {
    NSInteger follows = ASMSpotiInt(ASMSpotiKeyMusicFollows, ASMSpotiMusicFollowsEverything);
    return follows >= ASMSpotiMusicFollowsEverything && follows <= ASMSpotiMusicFollowsBass ? (ASMSpotiMusicFollows)follows : ASMSpotiMusicFollowsEverything;
}

// A percentage slider over a strength key, telling `changed` each step it stores.
static ASMSpotiModRow *strengthRow(NSString *key, void (^changed)(void)) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return ASMSpotiSliderRow(@"Strength", nil, minimum, maximum, ASMSpotiStrengthStep,
        ^double { return ASMSpotiHapticsStrength(key) * 100; },
        ^(double value) {
            ASMSpotiSetInt(key, lround(value));
            if (changed) changed();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });
}

NSArray<ASMSpotiModSection *> *ASMSpotiVibrationsSections(void) {
    ASMSpotiModRow *controls = ASMSpotiSwitchRow(@"Controls", nil, ASMSpotiKeyControlHaptics);
    ASMSpotiModRow *controlStrength = strengthRow(ASMSpotiKeyControlStrength, ^{
        // Felt as it is set: a tap at the new strength with each step.
        ASMSpotiPlayFeedback(ASMSpotiFeedbackAdd);
    });
    controlStrength.visible = ^BOOL { return ASMSpotiEnabled(ASMSpotiKeyControlHaptics); };

    ASMSpotiModRow *music = ASMSpotiOptionRow(@"Music Haptics", nil, ASMSpotiKeyMusicHaptics);
    music.info = kMusicHapticsInfo;
    music.changed = ^(BOOL on) { ASMSpotiSetMusicHapticsEnabled(on); };
    BOOL (^musicOn)(void) = ^BOOL { return ASMSpotiFlag(ASMSpotiKeyMusicHaptics, NO); };
    ASMSpotiModRow *musicStrength = strengthRow(ASMSpotiKeyMusicStrength, ^{ ASMSpotiMusicHapticsSettingsChanged(); });
    musicStrength.visible = musicOn;
    ASMSpotiModRow *follows = ASMSpotiChoiceRow(@"Follows", nil, ASMSpotiKeyMusicFollows, followsNames(), ASMSpotiMusicFollowsEverything);
    follows.choiceNotes = followsNotes();
    follows.chosen = ^(NSInteger index) { ASMSpotiMusicHapticsSettingsChanged(); };
    follows.visible = musicOn;

    return @[
        ASMSpotiSection(@"Vibrations", @[ASMSpotiWithSymbol(controls, @"hand.tap"), controlStrength]),
        ASMSpotiSection(nil, @[ASMSpotiWithSymbol(music, @"waveform"), musicStrength, follows]),
    ];
}
