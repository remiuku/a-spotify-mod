// Labs: Spotify's flags for features it built and did not ship; every row forces one flag.
#import "Settings/ASMSpotiModPage.h"
#import "Flags.h"

static UIViewController *martiniPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"AI Chat (Martini)" intro:ASMSpotiRestartNote sections:@[
        ASMSpotiSection(@"On Home", @[
            ASMSpotiFlagRow(@"Chat entry point", @"ios-home-evopage-impl.interactive_entrypoint_enabled"),
            ASMSpotiFlagRow(@"Martini behind it", @"ios-home-evopage-impl.interactive_entrypoint_martini_enabled"),
            ASMSpotiFlagRow(@"Floating chat", @"ios-home-evopage-impl.interactive_entrypoint_floating_chat_enabled"),
            ASMSpotiFlagRow(@"Microphone", @"ios-home-evopage-impl.interactive_entrypoint_mic_enabled"),
            ASMSpotiFlagRow(@"Glowing pill", @"ios-home-evopage-impl.interactive_entrypoint_pill_glow_enabled"),
        ]),
        ASMSpotiSection(@"The chat", @[
            ASMSpotiFlagRow(@"Intent pills", @"ios-martini-floatingchat-impl.intent_pills_enabled"),
            ASMSpotiFlagRow(@"Thinking states", @"ios-martini-floatingchat-impl.thinking_states_enabled"),
            ASMSpotiFlagRow(@"Voice recording", @"ios-martini-floatingchat-impl.voice_recording_enabled"),
        ]),
        ASMSpotiSection(@"In the player", @[
            ASMSpotiFlagRow(@"Chat entry point", @"ios-martini-npvcardprovider-impl.floating_chat_entry_point_enabled"),
        ]),
    ] footer:nil];
}

UIViewController *ASMSpotiLabsPage(void) {
    return [[ASMSpotiModPage alloc] initWithTitle:@"Labs" intro:@"Unreleased features; some do nothing on your version. Changes apply after you restart Spotify." sections:@[
        ASMSpotiSection(nil, @[
            ASMSpotiWithSymbol(ASMSpotiPageRow(@"AI Chat (Martini)", ^UIViewController *{ return martiniPage(); }), @"bubble.left.and.bubble.right"),
        ]),
        ASMSpotiSection(@"Library", @[
            ASMSpotiFlagRow(@"Local files from the Files app", @"ios-feature-localfiles.documents_enabled"),
        ]),
        ASMSpotiSection(@"Home screen widget", @[
            ASMSpotiFlagRow(@"Progress bar", @"ios-widgets-widgetremoteconfig-impl.progress_bar_enabled"),
        ]),
        ASMSpotiNotedSection(@"Sleep timer", @[
            ASMSpotiFlagRow(@"Fade out", @"ios-feature-sleeptimer.enable_fade_out"),
            ASMSpotiFlagRow(@"One minute option", @"ios-feature-sleeptimer.enable_one_minute_option"),
            ASMSpotiFlagRow(@"Options sheet", @"ios-feature-sleeptimer.use_options_sheet"),
        ], @"Options sheet is always on in Redesigned UI."),
        ASMSpotiSection(@"Player", @[
            ASMSpotiFlagRow(@"Snake on the cover art", @"ios-feature-cover-art-snake.enabled"),
        ]),
        ASMSpotiSection(@"Podcast comments", @[
            ASMSpotiFlagRow(@"Comments card", @"ios-feature-comments.enable_comments_card"),
            ASMSpotiFlagRow(@"Pinned comments", @"ios-feature-comments.enable_pinned_comments"),
            ASMSpotiFlagRow(@"Several reactions", @"ios-feature-comments.enable_multi_reactions"),
        ]),
    ] footer:nil];
}
