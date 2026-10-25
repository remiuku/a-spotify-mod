// Presets and headphones, the two rows under the effects' switch on the Audio effects page.
//
//     AudioEffectsPresets.m       the built-in presets, the user's own, and the GraphicEQ line check
//     AutoEq.m                    AutoEq's index of headphones, cached, and a headphone's GraphicEQ applied
//     AudioEffectsPresetsPage.m   their pages
//
// Main thread, except where a function says otherwise.
#import <Foundation/Foundation.h>

// The user's presets, by name, each the asm.interface.vitrine.dsp.* keys as they were saved. Outside the dsp.
// prefix, so a preset never holds the presets.
#define ASMVitrineKeyDSPUserPresets @"asm.interface.vitrine.audioPresets"

#pragma mark - presets

// A built-in preset sets a few effects over a reset, leaving the Graphic EQ (the headphones' correction) as
// it is: the correction belongs to the headphones, not to the taste. Loading any preset, or applying a
// headphone, turns the effects' master switch on too, so the pick is heard.
NSArray<NSString *> *ASMVitrineDSPBuiltInPresetNames(void);
NSString *ASMVitrineDSPBuiltInPresetDetail(NSInteger index);   // the effects it turns on, for the row's subtitle
void ASMVitrineDSPLoadBuiltInPreset(NSInteger index);

// A user's preset is everything: every asm.interface.vitrine.dsp.* key but the master switch, Graphic EQ included.
NSArray<NSString *> *ASMVitrineDSPUserPresetNames(void);   // sorted
void ASMVitrineDSPSaveUserPreset(NSString *name);          // replaces one of the same name
BOOL ASMVitrineDSPLoadUserPreset(NSString *name);
void ASMVitrineDSPDeleteUserPreset(NSString *name);

// The text as one GraphicEQ line, trimmed and on one line, or nil when it is not one: what the Graphic EQ
// editor saves and what a headphone's file is checked with.
NSString *ASMVitrineDSPGraphicEqLine(NSString *text);

#pragma mark - AutoEq

// One headphone of AutoEq's results (github.com/jaakkopasanen/AutoEq, MIT): the name, who measured it
// ("crinacle on 711"), and its folder under results/ as INDEX.md writes it, percent-encoded.
@interface ASMVitrineAutoEqHeadphone : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *path;
@end

// INDEX.md's "- [Name](./path) by source" lines; anything else is skipped. Any thread.
NSArray<ASMVitrineAutoEqHeadphone *> *ASMVitrineAutoEqParseIndex(NSString *markdown);
// The raw address of the headphone's "<folder> GraphicEQ.txt". Any thread.
NSURL *ASMVitrineAutoEqGraphicEqURL(NSString *path);
// The headphones whose name and source hold every word of the query, case and accents aside.
NSArray<ASMVitrineAutoEqHeadphone *> *ASMVitrineAutoEqSearch(NSArray<ASMVitrineAutoEqHeadphone *> *all, NSString *query);
// The headphone a folder names, for the page's row: its last part, decoded.
NSString *ASMVitrineAutoEqNameOf(NSString *path);

// The index, from Caches/Vitrine/AutoEq unless `refresh` or the copy is a month old, else from GitHub (the
// cached copy still answering when GitHub does not). `done` runs once on the main queue, with the
// headphones, and why GitHub did not answer when it did not.
void ASMVitrineAutoEqLoadIndex(BOOL refresh, void (^done)(NSArray<ASMVitrineAutoEqHeadphone *> *headphones, NSString *error));
// Downloads the headphone's GraphicEQ and applies it; `done` on the main queue with nil or why not.
void ASMVitrineAutoEqApply(ASMVitrineAutoEqHeadphone *headphone, void (^done)(NSString *error));
// The second half of that: the file's text into the Graphic EQ, its switch and the master switch on. NO when
// it is not GraphicEQ. When the output playing now is remembered (below), the pick becomes its correction.
BOOL ASMVitrineAutoEqApplyText(NSString *path, NSString *text);
// None: the headphone's correction off (a curve of the user's own, with no headphone, stays), and None
// remembered for the output playing now when it is remembered.
void ASMVitrineAutoEqTakeOff(void);

#pragma mark - a correction per output

// The corrections remembered per output, by the port's UID: {uid: {name, path, nodes}}, `path` and `nodes`
// empty for None. Outside the dsp. prefix, so presets never hold it. And the UID whose correction the Graphic
// EQ plays because its output connected, empty when none does.
#define ASMVitrineKeyDSPOutputs          @"asm.interface.vitrine.audioOutputs"
#define ASMVitrineKeyDSPOutputFollowed   @"asm.interface.vitrine.audioOutputs.followed"
// Posted on the main thread when the output or what is remembered changes.
#define ASMVitrineAutoEqOutputsChangedNotification @"ASMVitrineAutoEqOutputsChangedNotification"

// Audio went to another output (AVAudioSession's route, its first output; AudioEffects.x calls this at
// launch and on every route change). A remembered output gets its correction, or None. Another output takes
// off a correction that came on for a remembered one; a correction picked with no output remembered, and a
// curve of the user's own, stay. Nothing happens while the UID stays the same. The master switch is left as
// it is: a route change never turns the effects on.
void ASMVitrineAutoEqOutputChanged(NSString *uid, NSString *name);
// The output playing now, nil before the first call.
NSString *ASMVitrineAutoEqOutputUID(void);
NSString *ASMVitrineAutoEqOutputName(void);
// Remembers the correction in use (or None) for the output playing now, or forgets that output.
void ASMVitrineAutoEqRememberOutput(BOOL remember);
BOOL ASMVitrineAutoEqOutputRemembered(NSString *uid);
void ASMVitrineAutoEqForgetOutput(NSString *uid);
// The remembered outputs, sorted by name: {uid, name, path}.
NSArray<NSDictionary<NSString *, NSString *> *> *ASMVitrineAutoEqRememberedOutputs(void);
