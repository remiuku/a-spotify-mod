import Foundation

/// Interface ownership is independent of the lyrics renderer and look profiles.
enum ASMInterfaceMode: String, CaseIterable, Codable {
    case spotify, spotipw, vitrine
    static let preferenceKey = "asm.interface.mode"
    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .spotipw: return "spoti.pw"
        case .vitrine: return "Vitrine"
        }
    }
    static var stored: Self {
        get { Self(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .spotify }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey) }
    }
    static let active: Self = {
        let supported: Bool
        if #available(iOS 26.0, *) { supported = true } else { supported = false }
        return beginLaunch(store: .standard, supportsOverhaul: supported)
    }()
    /// Two foreground launches that never reached a usable window trigger recovery.
    /// Backgrounding and normal exits clear the attempt, so iOS eviction is not a failure.
    static func beginLaunch(store: UserDefaults, supportsOverhaul: Bool) -> Self {
        var mode = launchMode(store.string(forKey: preferenceKey), supportsOverhaul: supportsOverhaul)
        let pending = store.string(forKey: "asm.interface.pending")
        var failures = store.integer(forKey: "asm.interface.failures")
        failures = pending == mode.rawValue && mode != .spotify ? failures + 1 : 0
        if failures >= 2 {
            store.set(mode.rawValue, forKey: "asm.interface.recovered")
            mode = .spotify
            store.set(mode.rawValue, forKey: preferenceKey)
            failures = 0
        }
        store.set(failures, forKey: "asm.interface.failures")
        store.set(mode.rawValue, forKey: "asm.interface.launchMode")
        if mode != .spotify { store.set(mode.rawValue, forKey: "asm.interface.pending") }
        else { store.removeObject(forKey: "asm.interface.pending") }
        store.synchronize()
        return mode
    }
    static func finishLaunch(store: UserDefaults = .standard) {
        store.removeObject(forKey: "asm.interface.pending")
        store.removeObject(forKey: "asm.interface.failures")
    }
    static func launchMode(_ rawValue: String?, supportsOverhaul: Bool) -> Self {
        guard supportsOverhaul else { return .spotify }
        return rawValue.flatMap(Self.init(rawValue:)) ?? .spotify
    }
}
