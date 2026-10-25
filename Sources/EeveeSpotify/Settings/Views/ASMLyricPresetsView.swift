import SwiftUI

struct ASMLyricPresetsView: View {
    @State private var viewer = UserDefaults.karaokeOptions.renderer
    @State private var message = ""
    @State private var resetting = false
    private func notifyViewer() {
        let prefix = "asm.interface." + (viewer == .vitrine ? "vitrine" : "spotipw")
        for name in [prefix + ".redesign.lyricsLookDidChange", prefix + ".redesign.lyricsTextDidChange", prefix + ".lyricsRomanisedDidChange"] {
            NotificationCenter.default.post(name: Notification.Name(name), object: nil)
        }
    }
    var body: some View {
        List {
            Section {
                ASMPicker("Viewer", selection: $viewer) {
                    ForEach(KaraokeRenderer.allCases.filter { $0 != .spotify }, id: \.self) { ASMText($0.displayName).tag($0) }
                }
            } footer: { ASMText("Save fonts, motion, background and timing for this viewer. Sources, blending, audio and other viewers stay as they are. Close and reopen lyrics after restoring a preset.") }
            ForEach(1...3, id: \.self) { slot in
                Section(header: ASMText("Preset \(slot)")) {
                    ASMButton("Save current settings") { ASMLyricProfiles.save(viewer, slot: slot, store: .standard); message = "Saved preset \(slot)." }
                    ASMButton("Restore") { message = ASMLyricProfiles.restore(viewer, slot: slot, store: .standard) ? "Restored preset \(slot)." : "This slot is empty."; notifyViewer() }
                }
            }
            Section {
                Button("Reset this viewer", role: .destructive) { resetting = true }
                if !message.isEmpty { ASMText(message).font(.footnote).foregroundColor(.secondary) }
            }
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .onAppear { if viewer == .spotify { viewer = .eevee } }
            .confirmationDialog("Reset \(viewer.displayName)'s display settings?", isPresented: $resetting, titleVisibility: .visible) {
                Button("Reset viewer", role: .destructive) { ASMLyricProfiles.apply([:], viewer: viewer, store: .standard); message = "Viewer reset. Saved presets are kept."; notifyViewer() }
            }
    }
}
