import Foundation

enum ASMLookPreset: String, CaseIterable {
    case personal, spotify, spotipw, vitrine
    var titleKey: String { "asm_style_\(rawValue)" }
    var detailKey: String { titleKey + "_detail" }
    var requiresGlass: Bool { self == .spotipw || self == .vitrine }
}

/// Only appearance belongs here. Audio, lyrics, gestures, account data and
/// feature flags remain shared, including when reading an older saved slot.
enum ASMLookProfiles {
    static let keys = ["eeveeAmoled", "eeveeAccent", "eeveeRoundedArtwork", "eeveeLiquidGlassOptions", "eeveeTabBarOptions",
        "eeveeNowPlayingBarOptions", "eeveePlayerOptions", "eeveePlaylistOptions", "eeveeHomeGradient",
        "eeveeHomeHidden", "eeveeArtistHidden", "asm.artwork.options", "darkPopUps"]
    private static let selectedKey = "asm.look.selected"
    private static func profileKey(_ preset: ASMLookPreset) -> String { "asm.look.style.\(preset.rawValue)" }

    static func selected(store: UserDefaults) -> ASMLookPreset {
        ASMLookPreset(rawValue: store.string(forKey: selectedKey) ?? "") ?? .personal
    }
    static func capture(store: UserDefaults) -> [String: Any] {
        var values: [String: Any] = [:]
        for key in keys { values[key] = store.object(forKey: key) }
        return values
    }
    private static func apply(_ values: [String: Any], store: UserDefaults) {
        for key in keys {
            if let value = values[key] { store.set(value, forKey: key) }
            else { store.removeObject(forKey: key) }
        }
    }
    private static func saveStyle(_ preset: ASMLookPreset, store: UserDefaults) {
        store.set(["version": 1, "values": capture(store: store)], forKey: profileKey(preset))
    }
    private static func savedStyle(_ preset: ASMLookPreset, store: UserDefaults) -> [String: Any]? {
        guard let profile = store.dictionary(forKey: profileKey(preset)), profile["version"] as? Int == 1,
              let values = profile["values"] as? [String: Any] else { return nil }
        return values
    }
    @discardableResult static func select(_ preset: ASMLookPreset, supportsGlass: Bool, store: UserDefaults) -> Bool {
        guard !preset.requiresGlass || supportsGlass else { return false }
        let previous = selected(store: store)
        guard preset != previous else { return false }
        saveStyle(previous, store: store)
        // The personal look is captured before the first switch, including unset values.
        let values = savedStyle(preset, store: store) ?? defaults(for: preset)
        apply(values, store: store)
        store.set(preset.rawValue, forKey: selectedKey)
        return true
    }
    @discardableResult static func resetSelected(store: UserDefaults) -> Bool {
        let preset = selected(store: store)
        guard preset != .personal else { return false }
        apply(defaults(for: preset), store: store)
        saveStyle(preset, store: store)
        return true
    }
    static func save(slot: Int, store: UserDefaults) {
        guard (1...3).contains(slot) else { return }
        store.set(capture(store: store), forKey: "asm.look.\(slot)")
    }
    @discardableResult static func restore(slot: Int, store: UserDefaults) -> Bool {
        guard (1...3).contains(slot), let profile = store.dictionary(forKey: "asm.look.\(slot)") else { return false }
        apply(profile, store: store)
        return true
    }

    /// Local settings recipes, not either upstream's complete replacement UI.
    /// References and the exact source revisions are in APPEARANCE_PRESETS.md.
    static func defaults(for preset: ASMLookPreset) -> [String: Any] {
        guard preset != .personal else { return [:] }
        let glass = preset.requiresGlass, vitrine = preset == .vitrine
        func json(_ value: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) }
        return [
            "eeveeAmoled": vitrine,
            "eeveeAccent": vitrine ? 0x37F200 : -1,
            "eeveeRoundedArtwork": glass,
            "darkPopUps": glass,
            "eeveeLiquidGlassOptions": json(["enabled": glass, "spotifyGlass": true, "tabBar": true, "nowPlayingBar": true,
                "newPlayerDesign": glass, "search": true, "home": true, "playlist": true, "lyricsView": true]),
            "eeveeTabBarOptions": json(["order": [String](), "hidden": [String](), "hideLabels": false, "albumTint": !vitrine]),
            "eeveeNowPlayingBarOptions": json(["albumTint": !vitrine, "roundArtwork": glass, "hideConnect": false]),
            "eeveePlayerOptions": json(["backdrop": glass, "glassLyricsCard": glass,
                "hidden": vitrine ? ["aboutArtist", "relatedVideos", "songDNA", "liveEvents", "exploreArtist", "releaseCountdown", "merch", "recommendations"] : []]),
            "eeveePlaylistOptions": json(["fullCover": vitrine, "dividers": vitrine, "hideFind": false, "hidden": [String]()]),
            "eeveeHomeGradient": json(["enabled": preset == .spotipw, "strength": 1, "height": 1,
                "followAlbum": true, "pages": ["home", "library", "search"]]),
            "eeveeHomeHidden": jsonArray(vitrine ? ["promos", "previews", "dj"] : []),
            "eeveeArtistHidden": jsonArray(vitrine ? ["verified", "listeners"] : []),
            // Motion/video remain opt-in in every factory recipe.
            "asm.artwork.options": json(["enabled": false, "video": "automatic", "motion": "off", "radius": vitrine ? 12.0 : 24.0,
                "shadow": 0.4, "pausedScale": 0.84, "motionDuration": 14.0, "pauseWithMusic": true,
                "wifiOnly": true, "lowPowerStill": true, "country": "us"])
        ]
    }
    private static func jsonArray(_ value: [String]) -> Data { try! JSONEncoder().encode(value) }
}
