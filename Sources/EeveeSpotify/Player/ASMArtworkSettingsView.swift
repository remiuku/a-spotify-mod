import SwiftUI
import UniformTypeIdentifiers

struct ASMArtworkSettingsView: View {
    @State private var lockMode = UserDefaults.asmLockMode
    @State private var lockStatus = ASMLockScreenHost.status
    private let lockTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var options = UserDefaults.asmArtworkOptions
    @State private var album = ASMArtworkAlbum.current()
    @State private var custom = ""
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        List {
            Section(footer: ASMText("asm_artwork_hint".localized)) {
                ASMToggle("asm_artwork_enabled".localized, isOn: $options.enabled)
                ASMPicker("asm_artwork_video".localized, selection: $options.video) {
                    ForEach(ASMArtworkVideo.allCases, id: \.self) { ASMText("asm_video_\($0.rawValue)".localized).tag($0) }
                }
                ASMToggle("asm_artwork_wifi".localized, isOn: $options.wifiOnly)
                TextField("asm_artwork_country".localized, text: $options.country)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section(header: ASMText("asm_artwork_current".localized), footer: ASMText("asm_artwork_override_hint".localized)) {
                if let album {
                    ASMText(album.album).font(.headline)
                    ASMText(album.artist).foregroundColor(.secondary)
                    TextField("asm_artwork_url".localized, text: $custom)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    ASMButton("asm_artwork_save".localized) {
                        let value = custom.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard value.isEmpty || value.hasPrefix("local:") || (URL(string: value)?.scheme == "https" && URL(string: value)?.host != nil) else {
                            message = "asm_artwork_invalid_url".localized; return
                        }
                        ASMArtworkRepository.shared.setOverride(value, for: album); message = "asm_artwork_saved".localized
                    }
                    ASMButton("asm_artwork_import".localized) { importing = true }
                    ASMButton("asm_artwork_clear".localized) { custom = ""; ASMArtworkRepository.shared.setOverride("", for: album) }
                } else { ASMText("asm_artwork_play_song".localized).foregroundColor(.secondary) }
                if let message { ASMText(message).font(.footnote).foregroundColor(.secondary) }
            }
            Section(header: ASMText("Lock screen · experimental"), footer: ASMText("Animated modes need iOS 26 and a local exported clip. Uses the album video source above; unavailable videos fall back to the cover. LiveContainer and background delivery need phone testing.")) {
                ASMPicker("Artwork", selection: $lockMode) { ForEach(ASMLockMode.allCases, id: \.self) { ASMText($0.title).tag($0) } }
                ASMText(lockStatus).font(.footnote).foregroundColor(.secondary)
            }
            Section(header: ASMText("asm_artwork_motion".localized)) {
                ASMPicker("asm_artwork_motion".localized, selection: $options.motion) {
                    ForEach(ASMArtworkMotion.allCases, id: \.self) { ASMText("asm_motion_\($0.rawValue)".localized).tag($0) }
                }
                slider("asm_artwork_duration", value: $options.motionDuration, range: 2...60, unit: "s")
                slider("asm_artwork_radius", value: $options.radius, range: 0...180, unit: "pt")
                slider("asm_artwork_shadow", value: $options.shadow, range: 0...1, unit: "")
                slider("asm_artwork_paused_scale", value: $options.pausedScale, range: 0.65...1, unit: "×")
            }
            Section(footer: ASMText("asm_artwork_system_hint".localized)) {
                ASMToggle("asm_artwork_pause".localized, isOn: $options.pauseWithMusic)
                ASMToggle("asm_artwork_battery".localized, isOn: $options.lowPowerStill)
            }
            SettingsResetSection(visible: options != ASMArtworkOptions()) { options = ASMArtworkOptions() }
        }
        .eeveeSettingsStyle()
        .onAppear(perform: refreshAlbum)
        .onChange(of: lockMode) { UserDefaults.asmLockMode = $0; ASMLockScreenHost.tick() }
        .onReceive(lockTick) { _ in lockStatus = ASMLockScreenHost.status }
        .onReceive(NotificationCenter.default.publisher(for: .eeveeKaraokeLyricsChanged)) { _ in refreshAlbum() }
        .onChange(of: options) {
            UserDefaults.asmArtworkOptions = $0
            NotificationCenter.default.post(name: .asmArtworkChanged, object: nil)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            do {
                guard let album, let source = try result.get().first else { return }
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                let ext = source.pathExtension.lowercased()
                guard ["mp4", "mov", "m4v"].contains(ext) else { message = "asm_artwork_invalid_video".localized; return }
                try FileManager.default.createDirectory(at: ASMArtworkRepository.library, withIntermediateDirectories: true)
                let name = UUID().uuidString + "." + ext
                try FileManager.default.copyItem(at: source, to: ASMArtworkRepository.library.appendingPathComponent(name))
                custom = "local:" + name
                ASMArtworkRepository.shared.setOverride(custom, for: album)
                message = "asm_artwork_saved".localized
            } catch { message = error.localizedDescription }
        }
    }
    private func refreshAlbum() {
        let current = ASMArtworkAlbum.current()
        if current != album { album = current; message = nil }
        if let album { custom = ASMArtworkRepository.shared.override(for: album) }
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack { ASMText(title.localized); Spacer(); ASMText(String(format: "%.2f %@", value.wrappedValue, unit)).foregroundColor(.secondary).monospacedDigit() }
            Slider(value: value, in: range)
        }
    }
}
