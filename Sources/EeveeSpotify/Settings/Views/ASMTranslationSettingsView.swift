import SwiftUI
import Translation

struct ASMTranslationSettingsView: View {
    var body: some View {
        if #available(iOS 26.0, *) { ASMInstalledTranslationSettingsView() }
        else {
            List {
                ASMText("Silent on-device lyrics translation requires iOS 26 or later. Source-provided translations remain available.")
            }.eeveeSettingsStyle()
        }
    }
}

@available(iOS 26.0, *)
private struct ASMInstalledTranslationSettingsView: View {
    private struct Language: Identifiable {
        let id: String
        let name: String
    }
    @State private var options = ASMTranslationOptions.load()
    @State private var languages: [Language] = []
    @State private var downloadSource = "ja"
    @State private var pairStatus: LanguageAvailability.Status?
    @State private var configuration: TranslationSession.Configuration?
    @State private var preparing = false
    @State private var message = ""
    @State private var lastStatus = UserDefaults.standard.string(forKey: "asm.lyrics.translation.lastStatus") ?? "No translation run yet."
    private var pair: String { downloadSource + "/" + options.target }
    var body: some View {
        List {
            Section {
                ASMToggle("On-device translations in Sweet", isOn: $options.enabled)
                ASMPicker("Translate into", selection: $options.target) {
                    if languages.isEmpty { ASMText("Loading languages…").tag(options.target) }
                    ForEach(languages) { ASMText($0.name).tag($0.id) }
                }
                ASMPicker("Song language", selection: $options.source) {
                    ASMText("Detect automatically").tag("auto")
                    ForEach(languages) { ASMText($0.name).tag($0.id) }
                }
            } footer: {
                ASMText("Shown beneath the original lines. Source translations are preferred. Automatic mode uses installed languages only, skips uncertain lines, and never opens a download prompt. Reopen lyrics after changing these options.")
            }
            Section {
                ASMPicker("Language to download", selection: $downloadSource) {
                    if languages.isEmpty { ASMText("Loading languages…").tag(downloadSource) }
                    ForEach(languages) { ASMText($0.name).tag($0.id) }
                }
                ASMText(pairMessage).font(.footnote).foregroundColor(.secondary)
                Button {
                    var next = ASMAppleTranslation.configuration(source: downloadSource, target: options.target)
                    if let configuration { next = configuration; next.invalidate() }
                    message = ""; preparing = true; configuration = next
                } label: { ASMText(preparing ? "Preparing languages…" : "Download languages") }
                    .disabled(preparing || pairStatus != .supported)
                if !message.isEmpty { ASMText(message).font(.footnote).foregroundColor(.secondary) }
            } header: {
                ASMText("Prepare languages")
            } footer: {
                ASMText("Apple may ask for download permission here. Downloads are shared with the Translate app. Translation itself stays on this device and does not control playback.")
            }
            Section(header: ASMText("Last lyrics request")) {
                ASMText(lastStatus).font(.footnote).foregroundColor(.secondary)
                Button("Clear translation cache") {
                    Task {
                        await ASMTranslationCache.shared.clear()
                        lastStatus = "Translation cache cleared."
                        UserDefaults.standard.removeObject(forKey: "asm.lyrics.translation.lastStatus")
                    }
                }
            }
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .task {
                let available = await ASMAppleTranslation.availability().supportedLanguages
                guard !Task.isCancelled else { return }
                languages = available.map { Language(id: $0.minimalIdentifier,
                    name: Locale.current.localizedString(forIdentifier: $0.minimalIdentifier) ?? $0.minimalIdentifier) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                if !languages.contains(where: { $0.id == options.target }) {
                    options.target = languages.first(where: { $0.id.hasPrefix(options.target + "-") })?.id
                        ?? languages.first(where: { $0.id == "en" })?.id ?? languages.first?.id ?? "en"
                }
                if !languages.contains(where: { $0.id == downloadSource }) { downloadSource = languages.first?.id ?? "en" }
                await checkPair()
            }
            .task(id: pair) { await checkPair() }
            .onChange(of: options) { _ in options.save(); configuration = nil; preparing = false }
            .onChange(of: downloadSource) { _ in configuration = nil; preparing = false }
            // The only translationTask in the feature is this explicit setup
            // action. A nil configuration never requests language downloads.
            .translationTask(configuration) { session in
                do {
                    try await session.prepareTranslation()
                    guard !Task.isCancelled else { return }
                    message = "Languages are ready for silent translation."
                    await checkPair()
                } catch {
                    guard !Task.isCancelled else { return }
                    message = "Languages could not be prepared. You can also download them in Apple's Translate app."
                }
                preparing = false
            }
    }
    private var pairMessage: String {
        if downloadSource == options.target { return "Choose a different source and target language." }
        switch pairStatus {
        case .installed: return "Installed · ready for automatic translation."
        case .supported: return "A language download is needed before automatic translation can use this pair."
        case .unsupported: return "This language pair is not supported by Apple."
        default: return "Checking language availability…"
        }
    }
    private func checkPair() async {
        let expected = pair
        pairStatus = nil
        let status = await ASMAppleTranslation.availability().status(from: Locale.Language(identifier: downloadSource),
                                                                    to: Locale.Language(identifier: options.target))
        guard !Task.isCancelled, pair == expected else { return }
        pairStatus = status
    }
}
