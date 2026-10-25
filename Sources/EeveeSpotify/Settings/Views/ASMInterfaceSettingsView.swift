import SwiftUI
import EeveeSpotifyC

struct ASMInterfaceSettingsView: View {
    @State private var mode = ASMInterfaceMode.stored
    var body: some View {
        List {
            Section {
                ASMPicker("Interface", selection: $mode) {
                    ForEach(ASMInterfaceMode.allCases, id: \.self) { option in
                        ASMText(option.displayName).tag(option)
                            .disabled(option != .spotify && !overhaulAvailable)
                    }
                }
            } footer: {
                ASMText(overhaulAvailable ? "Switching interfaces takes effect after you close and reopen Spotify. Audio and lyrics settings stay as they are. Configure the selected overhaul below; the other theme, layout and saved-look pages apply to the Spotify interface." : "The spoti.pw and Vitrine interfaces require iOS 26. Lyrics viewers remain separate.")
            }
            if let recovered = UserDefaults.standard.string(forKey: "asm.interface.recovered") {
                Section { ASMText("Recovered to Spotify after repeated incomplete \(recovered) launches. Your saved display settings are kept; choose an interface above to retry.").font(.footnote) }
            }
            if mode != .spotify {
                Section(header: ASMText(mode.displayName)) {
                    ASMImportedSettingsLink(mode: mode.rawValue, page: "Appearance", title: "Appearance")
                    ASMImportedSettingsLink(mode: mode.rawValue, page: "Player", title: "Player")
                    ASMImportedSettingsLink(mode: mode.rawValue, page: "Tab", title: "Tabs")
                    if mode == .vitrine {
                        ASMImportedSettingsLink(mode: mode.rawValue, page: "Home", title: "Home")
                        ASMImportedSettingsLink(mode: mode.rawValue, page: "Album", title: "Albums")
                        ASMImportedSettingsLink(mode: mode.rawValue, page: "Artist", title: "Artists")
                    }
                }
            }
            Section {
                SettingsLink(title: "Lyrics viewers", subtitle: "Choose independently of the interface", icon: "quote.bubble", color: .purple) { ASMViewerSettingsView() }
            }
            RestartSection(visible: mode != ASMInterfaceMode.active)
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .onChange(of: mode) {
                ASMActivityRecorder.store.record("settings.interface", ["mode": $0.rawValue])
                ASMInterfaceMode.stored = $0; UserDefaults.standard.removeObject(forKey: "asm.interface.recovered")
            }
    }
    private var overhaulAvailable: Bool { if #available(iOS 26.0, *) { return true }; return false }
}

struct ASMImportedSettingsLink: View {
    let mode: String
    let page: String
    let title: String
    @State private var unavailable = false
    var body: some View {
        Button {
            guard let controller = ASMInterfaceSettingsPage(mode, page), let nav = SettingsNavigator.navigationController else { unavailable = true; return }
            nav.pushViewController(controller, animated: true)
        } label: {
            SettingsLabel(title: title, icon: "slider.horizontal.3", color: .purple, chevron: true)
        }.alert("Module unavailable", isPresented: $unavailable) {
            Button("OK", role: .cancel) {}
        } message: { Text("Reimport the complete app update in LiveContainer.") }
    }
}

struct ASMViewerSettingsView: View {
    @State private var options = UserDefaults.karaokeOptions
    var body: some View {
        List {
            Section {
                ASMPicker("Lyrics viewer", selection: $options.renderer) {
                    ForEach(KaraokeRenderer.allCases, id: \.self) { renderer in ASMText(renderer.displayName).tag(renderer) }
                }
            } footer: { ASMText("Choose a viewer independently of Spotify, spoti.pw or Vitrine's interface. Each viewer keeps its own settings. Sources and blending are shared.") }
            Section {
                SettingsLink(title: "Lyric presets & reset", icon: "bookmark", color: .purple) { ASMLyricPresetsView() }
                SettingsLink(title: "Song lyrics & offline", icon: "arrow.down.circle", color: .purple) {
                    ASMSongLyricsSettingsView(trackID: KaraokePlaybackTracker.shared.currentTrackId())
                }
            }
            Section {
                ASMToggle("Use custom lyrics in the player", isOn: $options.replacePlayerLyrics)
            } footer: {
                ASMText("Replaces the stock lyrics card with a custom-source preview and hides the duplicate line over the artwork. Tap the preview to open your chosen viewer. Selecting Spotify restores its original lyrics surfaces.")
            }
            Section(header: ASMText("Source metadata · Eevee / Sweet")) {
                ASMToggle("Show source translations", isOn: $options.showTranslation)
                ASMPicker("Translation display · Sweet", selection: $options.translationDisplay) {
                    ForEach(ASMTranslationDisplay.allCases, id: \.self) { ASMText($0.title).tag($0) }
                }
                ASMToggle("Show source pronunciation", isOn: $options.showPronunciation)
                ASMText("Shown when supplied by the source. spoti.pw and Vitrine have their own controls below.").font(.footnote).foregroundColor(.secondary)
                SettingsLink(title: "On-device translation", icon: "translate", color: .purple) { ASMTranslationSettingsView() }
            }
            Section(header: ASMText("Viewer settings")) {
                SettingsLink(title: "Eevee", icon: "quote.bubble", color: .green) { ASMEeveeViewerSettingsView() }
                SettingsLink(title: "Sweet Lyrics / Mild", icon: "textformat.size", color: .purple) { MildLyricsSettingsView(page: .display) }
                ASMMenuLink(route: .funLyrics)
                ASMImportedSettingsLink(mode: "spotipw", page: "Lyrics", title: "spoti.pw")
                ASMImportedSettingsLink(mode: "vitrine", page: "Lyrics", title: "Vitrine")
            }
            Section {
                ASMMenuLink(route: .mildSources)
                if !UserDefaults.lyricsSource.supportsCustomLyricsView && options.renderer != .spotify {
                    ASMText("Choose a custom source on the main Lyrics page to use this viewer.").font(.footnote).foregroundColor(.secondary)
                }
            }
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .onAppear { options = UserDefaults.karaokeOptions }
            .onChange(of: options) {
                ASMActivityRecorder.store.record("settings.lyrics", ["viewer": $0.renderer.rawValue])
                UserDefaults.karaokeOptions = $0
            }
    }
}

struct ASMEeveeViewerSettingsView: View {
    @State private var options = ASMViewerDisplay.eevee
    var body: some View {
        List {
            Section {
                ASMPicker("karaoke_alignment".localized, selection: $options.textAlignment) {
                    ForEach(KaraokeTextAlignment.allCases, id: \.self) { ASMText($0.displayName).tag($0) }
                }
                ASMToggle("karaoke_reversed_direction".localized, isOn: $options.reversedDirection)
                VStack(alignment: .leading) {
                    ASMText("karaoke_blur_intensity".localized)
                    Slider(value: $options.blurIntensity, in: 0...4, step: 0.1)
                }
            }
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .onAppear { options = ASMViewerDisplay.eevee }
            .onChange(of: options) { ASMViewerDisplay.eevee = $0 }
    }
}
