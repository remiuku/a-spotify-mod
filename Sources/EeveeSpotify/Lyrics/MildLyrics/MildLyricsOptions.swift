import Foundation

enum MildLyricsSettingsPage: CaseIterable {
    case display, playful, sources
    var sections: [String] {
        switch self {
        case .display: return MildLyricsOptions.sections.filter { $0 != "Playful effects" }
        case .playful: return ["Playful effects"]
        case .sources: return []
        }
    }
    var titleKey: String {
        switch self {
        case .display: return "asm_menu_lyric_display"
        case .playful: return "asm_menu_fun_lyrics"
        case .sources: return "asm_menu_lyric_sources"
        }
    }
}

// Native controls inspired by gcoolL/mild-lyrics (AGPL-3.0); see THIRD_PARTY_MILD_LYRICS.md.
struct MildLyricsOptions: Codable, Equatable {
    var numbers: [String: Double] = [:]
    var choices: [String: String] = [:]
    var flags: [String: Bool] = [:]
    var sourceOrder = ["spicy", "apple", "amll", "unison", "netease", "kugou", "qq", "kuwo", "lrcmodel", "lrclib", "mxm", "genius"]
    var disabledSources: Set<String> = []
    var excludedUploaders = ""
    var preferredUploaders = ""
    var sourceSelectionData: Data {
        // Sets need explicit sorting for a stable identity across relaunches.
        // Appearance and playful effects never invalidate saved lyric content.
        let values: [String: Any] = ["order": orderedSources, "disabled": disabledSources.sorted(),
            "excluded": excludedUploaders, "preferred": preferredUploaders, "blend": choice("blend"), "uncensor": flag("uncensor")]
        return (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])) ?? Data()
    }

    func number(_ key: String) -> Double {
        guard let spec = Self.sliders.first(where: { $0.id == key }) else { return 0 }
        let value = numbers[key] ?? spec.initial
        return value.isFinite ? min(spec.max, max(spec.min, value)) : spec.initial
    }
    func choice(_ key: String) -> String {
        guard let spec = Self.pickers.first(where: { $0.id == key }) else { return "" }
        let value = choices[key] ?? spec.values[0]
        return spec.values.contains(value) ? value : spec.values[0]
    }
    func flag(_ key: String) -> Bool { flags[key] ?? Self.toggles.first(where: { $0.id == key })?.initial ?? false }
    var orderedSources: [String] {
        var seen: Set<String> = []
        return (sourceOrder + Self.sources.map { $0.0 }).filter { Self.sourceName($0) != nil && seen.insert($0).inserted }
    }
    static func sourceName(_ id: String) -> String? { sources.first { $0.0 == id }?.1 }
    static let sources = [("spicy", "Spicy Lyrics"), ("apple", "Apple / lrc.red"), ("amll", "AMLL TTML DB"),
                          ("unison", "Unison"), ("netease", "NetEase"), ("kugou", "Kugou"), ("qq", "QQ Music"),
                          ("kuwo", "Kuwo"), ("lrcmodel", "lrc.red model sync"), ("lrclib", "LRCLIB"), ("mxm", "Musixmatch"), ("genius", "Genius")]
    struct SliderSpec: Identifiable {
        let id: String, label: String, section: String
        let min: Double, max: Double, step: Double, initial: Double
    }
    struct PickerSpec: Identifiable { let id: String, label: String, section: String; let values: [String] }
    struct ToggleSpec: Identifiable { let id: String, label: String, section: String; let initial: Bool }
    static let sections = ["Text", "Motion", "Background", "Timing", "Playful effects"]
    static let sliders: [SliderSpec] = [
        .init(id: "font_scale", label: "Text size", section: "Text", min: 0.6, max: 1.9, step: 0.05, initial: 1),
        .init(id: "line_spacing", label: "Line spacing", section: "Text", min: 0.6, max: 2.5, step: 0.1, initial: 1),
        .init(id: "focus", label: "Focus lines (0 = all)", section: "Text", min: 0, max: 8, step: 1, initial: 0),
        .init(id: "pop", label: "Word pop", section: "Motion", min: 0, max: 3, step: 0.25, initial: 1),
        .init(id: "rise", label: "Word rise", section: "Motion", min: 0, max: 4, step: 0.25, initial: 1),
        .init(id: "line_drop", label: "Line drop", section: "Motion", min: 0, max: 3, step: 0.25, initial: 0),
        .init(id: "pop_min", label: "Pop only past (seconds)", section: "Motion", min: 0, max: 2, step: 0.05, initial: 0),
        .init(id: "pop_linger", label: "Pop linger (seconds)", section: "Motion", min: 0, max: 1, step: 0.1, initial: 0),
        .init(id: "edge", label: "Fill softness", section: "Motion", min: 0, max: 4, step: 0.25, initial: 1),
        .init(id: "glow_scale", label: "Glow", section: "Motion", min: 0, max: 2, step: 0.1, initial: 1),
        .init(id: "word_glow", label: "Glow every word", section: "Motion", min: 0, max: 2, step: 0.1, initial: 0),
        .init(id: "pop_glow", label: "Glow long words", section: "Motion", min: 0, max: 2, step: 0.1, initial: 1),
        .init(id: "blur_scale", label: "Depth blur", section: "Motion", min: 0, max: 2, step: 0.1, initial: 1),
        .init(id: "scroll_lead", label: "Scroll lead (seconds)", section: "Motion", min: 0, max: 1.5, step: 0.05, initial: 0),
        .init(id: "focus_height", label: "Focus height", section: "Motion", min: 0.25, max: 0.85, step: 0.05, initial: 0.4),
        .init(id: "fps", label: "Refresh limit", section: "Motion", min: 15, max: 60, step: 15, initial: 30),
        .init(id: "bg_dim", label: "Background dimming", section: "Background", min: 0, max: 1, step: 0.05, initial: 0.15),
        .init(id: "bg_motion", label: "Mesh motion", section: "Background", min: 0, max: 2, step: 0.1, initial: 1),
        .init(id: "offset", label: "Lyrics advance (seconds)", section: "Timing", min: -2, max: 2, step: 0.05, initial: 0),
        .init(id: "interlude_gap", label: "Minimum interlude (seconds)", section: "Timing", min: 0, max: 12, step: 0.5, initial: 3),
        .init(id: "merge_splits", label: "Merge adjacent syllables (ms)", section: "Timing", min: 0, max: 120, step: 10, initial: 0),
        .init(id: "spin", label: "Word spin (turns)", section: "Playful effects", min: 0, max: 4, step: 0.25, initial: 0),
        .init(id: "zero_g", label: "No gravity", section: "Playful effects", min: 0, max: 3, step: 0.25, initial: 0),
        .init(id: "float_up", label: "Float away", section: "Playful effects", min: 0, max: 3, step: 0.25, initial: 0),
        .init(id: "jelly", label: "Jelly lines", section: "Playful effects", min: 0, max: 3, step: 0.25, initial: 0)
    ]
    static let pickers: [PickerSpec] = [
        .init(id: "renderer", label: "Lyric style", section: "Text", values: ["spicy", "flow", "snap", "amll", "spotlight", "karaoke", "word", "cards"]),
        .init(id: "sung_mode", label: "Sung colour", section: "Text", values: ["white", "album tint"]),
        .init(id: "duet_colour", label: "Duet colour", section: "Text", values: ["white", "album tint"]),
        .init(id: "font_name", label: "Font", section: "Text", values: ["system", "rounded", "serif", "monospaced"]),
        .init(id: "roman", label: "Romanisation", section: "Text", values: ["off", "instead", "under"]),
        .init(id: "glow_tint", label: "Glow colour", section: "Motion", values: ["word", "white"]),
        .init(id: "background", label: "Background", section: "Background", values: ["art", "mesh", "solid", "clear"]),
        .init(id: "blend", label: "Blend word timing", section: "Sources", values: ["off"] + MildLyricsBlend.definitions.map(\.id))
    ]
    static let toggles: [ToggleSpec] = [
        .init(id: "enabled", label: "Use Mild controls in Sweet Lyrics", section: "Text", initial: false),
        .init(id: "fold_adlibs", label: "Fold backing vocals", section: "Text", initial: false),
        .init(id: "credits_top", label: "Songwriter credits on top", section: "Text", initial: false),
        .init(id: "hide_gaps", label: "Hide interlude dots", section: "Motion", initial: false),
        .init(id: "battery", label: "Reduce refresh in low power mode", section: "Motion", initial: true),
        .init(id: "uncensor", label: "Uncensor from base lyrics", section: "Sources", initial: true)
    ]
}

extension UserDefaults {
    @UserDefault(key: "mildLyricsOptions", defaultValue: MildLyricsOptions())
    static var mildLyricsOptions: MildLyricsOptions
}
