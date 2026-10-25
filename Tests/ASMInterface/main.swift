import Foundation
extension String { var localized: String { self } }

for ui in ASMInterfaceMode.allCases {
    precondition(ASMInterfaceMode.launchMode(ui.rawValue, supportsOverhaul: true) == ui)
    precondition(ASMInterfaceMode.launchMode(ui.rawValue, supportsOverhaul: false) == .spotify)
    for viewer in KaraokeRenderer.allCases {
        var options = KaraokeOptions()
        options.renderer = viewer
        options.blurIntensity = 2.7
        let bytes = try JSONEncoder().encode(options)
        let decoded = try JSONDecoder().decode(KaraokeOptions.self, from: bytes)
        precondition(decoded == options)
        precondition(ASMInterfaceMode.launchMode(ui.rawValue, supportsOverhaul: true) == ui)
    }
}
precondition(ASMInterfaceMode.launchMode(nil, supportsOverhaul: true) == .spotify)
precondition(ASMInterfaceMode.launchMode("unknown", supportsOverhaul: true) == .spotify)
let key = ASMInterfaceMode.preferenceKey
let previous = UserDefaults.standard.object(forKey: key)
defer {
    if let previous { UserDefaults.standard.set(previous, forKey: key) }
    else { UserDefaults.standard.removeObject(forKey: key) }
}
ASMInterfaceMode.stored = .vitrine
precondition(ASMInterfaceMode.stored == .vitrine)
precondition(ASMInterfaceMode.launchMode(ASMInterfaceMode.stored.rawValue, supportsOverhaul: false) == .spotify)
precondition(ASMInterfaceMode.stored == .vitrine, "Unsupported OS must not destroy the saved selection")
print("PASS interfaces: 15 independent interface/viewer combinations, OS gate, unknown recovery, stored-choice preservation and viewer persistence")

let recovery = UserDefaults(suiteName: "asm-recovery-test-" + UUID().uuidString)!
recovery.set("vitrine", forKey: ASMInterfaceMode.preferenceKey)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: true) == .vitrine)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: true) == .vitrine)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: true) == .spotify)
precondition(recovery.string(forKey: "asm.interface.recovered") == "vitrine")
precondition(recovery.string(forKey: "asm.interface.launchMode") == "spotify")
recovery.set("spotipw", forKey: ASMInterfaceMode.preferenceKey)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: true) == .spotipw)
ASMInterfaceMode.finishLaunch(store: recovery)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: true) == .spotipw)
precondition(recovery.integer(forKey: "asm.interface.failures") == 0)
recovery.set("vitrine", forKey: ASMInterfaceMode.preferenceKey)
precondition(ASMInterfaceMode.beginLaunch(store: recovery, supportsOverhaul: false) == .spotify)
precondition(recovery.string(forKey: ASMInterfaceMode.preferenceKey) == "vitrine")
print("PASS launch recovery: repeated incomplete launches, healthy/background exit, UI switch isolation, saved unsupported choice")
