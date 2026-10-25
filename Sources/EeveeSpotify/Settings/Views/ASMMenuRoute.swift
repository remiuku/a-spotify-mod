import Foundation

/// Placement only; feature pages retain their existing preferences and controls.
enum ASMMenuRoute: String, CaseIterable, Identifiable {
    case root, lyrics, sound, look, advanced, about, presets, theme, covers, layout
    case player, nowPlayingBar = "now_playing_bar", tabs, home, playlist, artist
    case background, glass, appIcon = "app_icon", patching, features, flags, experiments, privacy
    case troubleshooting, reset, sponsorBlock = "sponsorblock"
    case mildDisplay = "lyric_display", mildSources = "lyric_sources", funLyrics = "fun_lyrics", lyricColours = "lyric_colours"
    case interface, viewers
    var id: String { rawValue }
    var titleKey: String { "asm_menu_" + rawValue }
    var subtitleKey: String { titleKey + "_subtitle" }
    var children: [Self] {
        switch self {
        case .root: return [.lyrics, .sound, .look, .advanced, .about]
        case .lyrics: return [.viewers, .funLyrics, .mildDisplay, .mildSources, .lyricColours]
        case .sound: return [.sponsorBlock]
        case .look: return [.interface, .presets, .theme, .covers, .layout]
        case .theme: return [.background, .glass, .appIcon]
        case .layout: return [.player, .nowPlayingBar, .tabs, .home, .playlist, .artist]
        case .advanced: return [.patching, .features, .flags, .experiments, .privacy, .troubleshooting, .reset]
        default: return []
        }
    }
    var symbol: String {
        switch self {
        case .root, .advanced: return "gearshape.fill"
        case .lyrics, .lyricColours, .viewers: return "quote.bubble.fill"
        case .interface: return "rectangle.3.group.fill"
        case .sound: return "waveform"
        case .look, .theme: return "paintpalette.fill"
        case .about: return "books.vertical.fill"
        case .presets: return "square.stack.3d.up.fill"
        case .covers: return "photo.on.rectangle.angled"
        case .layout: return "rectangle.3.group.fill"
        case .player: return "play.rectangle.fill"
        case .nowPlayingBar: return "rectangle.bottomthird.inset.filled"
        case .tabs: return "square.grid.2x2.fill"
        case .home: return "house.fill"
        case .playlist: return "music.note.list"
        case .artist: return "music.mic"
        case .background: return "circle.lefthalf.filled"
        case .glass: return "drop.fill"
        case .appIcon: return "app.badge.fill"
        case .patching: return "hammer.fill"
        case .features: return "switch.2"
        case .flags: return "flag.fill"
        case .experiments: return "sparkle"
        case .privacy: return "hand.raised.fill"
        case .troubleshooting: return "stethoscope"
        case .reset: return "arrow.counterclockwise"
        case .sponsorBlock: return "forward.end.fill"
        case .mildDisplay: return "textformat.size"
        case .mildSources: return "arrow.triangle.merge"
        case .funLyrics: return "sparkles"
        }
    }
}
