import Foundation

/// Strictly viewer-local snapshots: no provider, blending, audio or account keys.
enum ASMViewerDisplay {
    static var eevee: KaraokeOptions {
        get { UserDefaults.standard.data(forKey: "asm.viewer.eevee").flatMap { try? JSONDecoder().decode(KaraokeOptions.self, from: $0) } ?? UserDefaults.standard.data(forKey: "karaokeOptions").flatMap { try? JSONDecoder().decode(KaraokeOptions.self, from: $0) } ?? KaraokeOptions() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "asm.viewer.eevee") }
    }
}

enum ASMLyricProfiles {
    static func accepts(_ key: String, viewer: KaraokeRenderer) -> Bool {
        guard viewer == .spotiPW || viewer == .vitrine else { return false }
        let prefix = "asm.interface.\(viewer.rawValue)."
        return key.hasPrefix(prefix + "redesign.lyrics") || ["lyricsRomanised", "lyricsSimulateWords", "lyricsDelay"].contains { key == prefix + $0 }
    }
    static func moduleKeys(_ viewer: KaraokeRenderer, store: UserDefaults) -> [String] {
        guard viewer == .spotiPW || viewer == .vitrine else { return [] }
        return store.dictionaryRepresentation().keys.filter { accepts($0, viewer: viewer) }
    }
    static func capture(_ viewer: KaraokeRenderer, store: UserDefaults) -> [String: Any] {
        var values: [String: Any] = [:]
        for key in moduleKeys(viewer, store: store) { values[key] = store.object(forKey: key) }
        if let data = store.data(forKey: viewer == .eevee && store.data(forKey: "asm.viewer.eevee") != nil ? "asm.viewer.eevee" : "karaokeOptions"), let options = try? JSONDecoder().decode(KaraokeOptions.self, from: data) {
            let fields: [String: Any] = viewer == .eevee
                ? ["alignment": options.textAlignment.rawValue, "reverse": options.reversedDirection, "blur": options.blurIntensity]
                : viewer == .sweetLyrics ? ["simple": options.sweetSimpleLyrics] : [:]
            values["host"] = fields
        }
        if viewer == .sweetLyrics, let data = store.data(forKey: "mildLyricsOptions"), let mild = try? JSONDecoder().decode(MildLyricsOptions.self, from: data) {
            values["mild"] = ["numbers": mild.numbers.filter { key, _ in MildLyricsOptions.sliders.contains { $0.id == key && $0.section != "Sources" } },
                              "choices": mild.choices.filter { key, _ in MildLyricsOptions.pickers.contains { $0.id == key && $0.section != "Sources" } },
                              "flags": mild.flags.filter { key, _ in MildLyricsOptions.toggles.contains { $0.id == key && $0.section != "Sources" } }]
        }
        return values
    }
    static func apply(_ values: [String: Any], viewer: KaraokeRenderer, store: UserDefaults) {
        // Even a modified snapshot cannot write outside this viewer's namespace.
        for key in moduleKeys(viewer, store: store) { store.removeObject(forKey: key) }
        if viewer == .spotiPW || viewer == .vitrine {
            for (key, value) in values where accepts(key, viewer: viewer) { store.set(value, forKey: key) }
        }
        let optionKey = viewer == .eevee ? "asm.viewer.eevee" : "karaokeOptions"
        var options = (store.data(forKey: optionKey) ?? store.data(forKey: "karaokeOptions")).flatMap { try? JSONDecoder().decode(KaraokeOptions.self, from: $0) } ?? KaraokeOptions()
        let host = values["host"] as? [String: Any] ?? [:]
        if viewer == .eevee {
            options.textAlignment = (host["alignment"] as? String).flatMap(KaraokeTextAlignment.init(rawValue:)) ?? .center
            options.reversedDirection = host["reverse"] as? Bool ?? false
            options.blurIntensity = min(4, max(0, host["blur"] as? Double ?? 1.5))
        } else if viewer == .sweetLyrics {
            options.sweetSimpleLyrics = host["simple"] as? Bool ?? false
            var mild = store.data(forKey: "mildLyricsOptions").flatMap { try? JSONDecoder().decode(MildLyricsOptions.self, from: $0) } ?? MildLyricsOptions()
            let saved = values["mild"] as? [String: Any] ?? [:]
            let numbers = saved["numbers"] as? [String: Double] ?? [:], choices = saved["choices"] as? [String: String] ?? [:], flags = saved["flags"] as? [String: Bool] ?? [:]
            for spec in MildLyricsOptions.sliders where spec.section != "Sources" { mild.numbers[spec.id] = numbers[spec.id] }
            for spec in MildLyricsOptions.pickers where spec.section != "Sources" { mild.choices[spec.id] = choices[spec.id] }
            for spec in MildLyricsOptions.toggles where spec.section != "Sources" { mild.flags[spec.id] = flags[spec.id] }
            store.set(try? JSONEncoder().encode(mild), forKey: "mildLyricsOptions")
        }
        store.set(try? JSONEncoder().encode(options), forKey: optionKey)
    }
    static func save(_ viewer: KaraokeRenderer, slot: Int, store: UserDefaults) {
        guard (1...3).contains(slot), viewer != .spotify else { return }
        store.set(capture(viewer, store: store), forKey: "asm.lyricPreset.\(viewer.rawValue).\(slot)")
    }
    @discardableResult static func restore(_ viewer: KaraokeRenderer, slot: Int, store: UserDefaults) -> Bool {
        guard (1...3).contains(slot), let values = store.dictionary(forKey: "asm.lyricPreset.\(viewer.rawValue).\(slot)") else { return false }
        apply(values, viewer: viewer, store: store); return true
    }
}
