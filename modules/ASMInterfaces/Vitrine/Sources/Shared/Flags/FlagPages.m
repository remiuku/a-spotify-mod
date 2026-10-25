// Labs: Spotify's flags for features it built and did not ship; every row forces one flag.
#import "Settings/ASMVitrineModPage.h"
#import "Flags.h"

static UIViewController *martiniPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"AI Chat (Martini)" intro:ASMVitrineRestartNote sections:@[
        ASMVitrineSection(@"On Home", @[
            ASMVitrineFlagRow(@"Chat entry point", @"ios-home-evopage-impl.interactive_entrypoint_enabled"),
            ASMVitrineFlagRow(@"Martini behind it", @"ios-home-evopage-impl.interactive_entrypoint_martini_enabled"),
            ASMVitrineFlagRow(@"Floating chat", @"ios-home-evopage-impl.interactive_entrypoint_floating_chat_enabled"),
            ASMVitrineFlagRow(@"Microphone", @"ios-home-evopage-impl.interactive_entrypoint_mic_enabled"),
            ASMVitrineFlagRow(@"Glowing pill", @"ios-home-evopage-impl.interactive_entrypoint_pill_glow_enabled"),
        ]),
        ASMVitrineSection(@"The chat", @[
            ASMVitrineFlagRow(@"Intent pills", @"ios-martini-floatingchat-impl.intent_pills_enabled"),
            ASMVitrineFlagRow(@"Thinking states", @"ios-martini-floatingchat-impl.thinking_states_enabled"),
            ASMVitrineFlagRow(@"Voice recording", @"ios-martini-floatingchat-impl.voice_recording_enabled"),
        ]),
        ASMVitrineSection(@"In the player", @[
            ASMVitrineFlagRow(@"Chat entry point", @"ios-martini-npvcardprovider-impl.floating_chat_entry_point_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *ASMVitrineLabsPage(void) {
    return [[ASMVitrineModPage alloc] initWithTitle:@"Labs" intro:@"Unreleased features; some do nothing on your version. Changes apply after you restart Spotify." sections:@[
        ASMVitrineSection(nil, @[
            ASMVitrineWithSymbol(ASMVitrinePageRow(@"AI Chat (Martini)", ^UIViewController *{ return martiniPage(); }), @"bubble.left.and.bubble.right"),
        ]),
        ASMVitrineSection(@"Library", @[
            ASMVitrineFlagRow(@"Local files from the Files app", @"ios-feature-localfiles.documents_enabled"),
        ]),
        ASMVitrineSection(@"Home screen widget", @[
            ASMVitrineFlagRow(@"Progress bar", @"ios-widgets-widgetremoteconfig-impl.progress_bar_enabled"),
        ]),
        ASMVitrineNotedSection(@"Sleep timer", @[
            ASMVitrineFlagRow(@"Fade out", @"ios-feature-sleeptimer.enable_fade_out"),
            ASMVitrineFlagRow(@"One minute option", @"ios-feature-sleeptimer.enable_one_minute_option"),
            ASMVitrineFlagRow(@"Options sheet", @"ios-feature-sleeptimer.use_options_sheet"),
        ], @"Options sheet is always on in Redesigned UI."),
        ASMVitrineSection(@"Player", @[
            ASMVitrineFlagRow(@"Snake on the cover art", @"ios-feature-cover-art-snake.enabled"),
        ]),
        ASMVitrineSection(@"Podcast comments", @[
            ASMVitrineFlagRow(@"Comments card", @"ios-feature-comments.enable_comments_card"),
            ASMVitrineFlagRow(@"Pinned comments", @"ios-feature-comments.enable_pinned_comments"),
            ASMVitrineFlagRow(@"Several reactions", @"ios-feature-comments.enable_multi_reactions"),
        ]),
    ] footer:nil];
}
