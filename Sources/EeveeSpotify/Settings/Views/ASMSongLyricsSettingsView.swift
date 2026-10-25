import SwiftUI
import MediaPlayer

@available(iOS 15.0, *)
struct ASMSongLyricsSettingsView: View {
    let trackID: String?
    @State private var preference = ASMSongLyricsPreference()
    @State private var entries: [ASMLyricsOfflineEntry] = []
    @State private var message = ""
    @State private var busy = false
    @State private var search = false
    @State private var editing: ASMLyricsOfflineEntry?
    @State private var title = ""
    @State private var artist = ""
    @AppStorage("asm.lyrics.keepAwake") private var keepAwake = false
    private let languages = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh-Hans", "zh-Hant", "ar", "hi", "ru", "nl", "pl", "tr", "uk", "vi"]
    var body: some View {
        List {
            if let trackID {
                Section {
                    ASMPicker("Lyrics source", selection: Binding(get: { preference.source ?? -1 }, set: {
                        preference.source = $0 == -1 ? nil : $0; preference.recordingID = nil; preference.recordingLabel = nil; savePreference(trackID)
                    })) {
                        ASMText("Use global source").tag(-1)
                        ForEach(LyricsSource.allCases.filter(\.supportsCustomLyricsView), id: \.rawValue) { ASMText($0.description).tag($0.rawValue) }
                    }
                    VStack(alignment: .leading) {
                        HStack { ASMText("Timing adjustment"); Spacer(); ASMText(String(format: "%+.2f s", Double(preference.offsetMs) / 1000)).foregroundColor(.secondary) }
                        Slider(value: Binding(get: { Double(preference.offsetMs) }, set: { preference.offsetMs = Int($0) }),
                               in: -10_000...10_000, step: 50, onEditingChanged: { if !$0 { savePreference(trackID) } })
                    }
                    ASMPicker("Translation language", selection: Binding(get: { preference.targetLanguage ?? "global" }, set: {
                        preference.targetLanguage = $0 == "global" ? nil : $0; savePreference(trackID)
                    })) {
                        ASMText("Use global language").tag("global")
                        if let selected = preference.targetLanguage, !languages.contains(selected) { ASMText(selected).tag(selected) }
                        ForEach(languages, id: \.self) { ASMText(Locale.current.localizedString(forIdentifier: $0) ?? $0).tag($0) }
                    }
                    if let label = preference.recordingLabel { ASMText("Selected: " + label).font(.footnote).foregroundColor(.secondary) }
                    Button("Choose another recording…") { search = true }
                    if preference.recordingID != nil {
                        Button("Use automatic recording match") { preference.recordingID = nil; preference.recordingLabel = nil; savePreference(trackID) }
                    }
                    Button("Reset this song's preferences") {
                        ASMSongLyricsPreferences.shared.reset(trackID); preference = .init(); ASMSongLyricsContext.notify(trackID)
                    }
                } header: { ASMText(title.isEmpty ? "Song preferences" : title) } footer: {
                    ASMText("Positive timing highlights earlier; negative highlights later. Settings apply only to this Spotify track. Translation language applies in Sweet. Other songs keep their preferences.")
                }
                Section {
                    Button(entries.contains(where: { $0.trackID == trackID }) ? "Update saved lyrics" : "Save current lyrics offline") { saveOffline(trackID) }
                        .disabled(busy)
                    Button("Fetch fresh lyrics") {
                        refreshLyrics(trackID)
                    }.disabled(busy)
                    if !message.isEmpty { ASMText(message).font(.footnote).foregroundColor(.secondary) }
                } footer: {
                    ASMText("Saves the current timed lyrics, credits and available translations locally. Audio is not downloaded. Saved lyrics are used before network requests when their source and recording settings still match. Up to 100 songs / 50 MB; saved songs are never silently evicted.")
                }
            } else {
                Section { ASMText("Play a song to set its source, timing, recording and language.").foregroundColor(.secondary) }
            }
            Section {
                ASMToggle("Keep lyrics screen awake while playing", isOn: $keepAwake)
            } footer: { ASMText("Custom full-screen viewers only. Pausing, leaving lyrics or switching away from Spotify restores normal screen sleep.") }
            Section(header: ASMText("Saved lyrics · \(entries.count) / 100")) {
                if entries.isEmpty { ASMText("No saved songs yet.").foregroundColor(.secondary) }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 5) {
                        ASMText(entry.title.isEmpty ? entry.trackID : entry.title).font(.headline)
                        ASMText(entry.artist + " · " + (entry.lyrics.providerName ?? "Lyrics")).font(.footnote).foregroundColor(.secondary)
                        HStack {
                            Button("Song preferences") { editing = entry }
                            Spacer()
                            Button("Remove", role: .destructive) { remove(entry.trackID) }
                        }.font(.footnote)
                    }
                }
            }
            SpacerView()
        }.eeveeSettingsStyle().pickerStyle(.menu).navigationTitle("Song lyrics & offline")
            .task { await reload() }
            .sheet(isPresented: $search) {
                if let trackID { ASMLyricRecordingSearch(trackID: trackID, initialQuery: title + " " + artist) {
                    preference = ASMSongLyricsPreferences.shared.get(trackID)
                } }
            }
            .sheet(item: $editing) { ASMSongLyricsSheet(trackID: $0.trackID) }
    }
    private func savePreference(_ track: String) {
        guard ASMSongLyricsPreferences.shared.set(preference, track: track) else { message = "Song preferences could not be saved."; return }
        preference = ASMSongLyricsPreferences.shared.get(track)
        ASMSongLyricsContext.notify(track)
    }
    private func reload() async {
        preference = ASMSongLyricsPreferences.shared.get(trackID)
        entries = await Task.detached(priority: .utility) { ASMLyricsOfflineLibrary.shared.entries() }.value
        if let saved = entries.first(where: { $0.trackID == trackID }) { title = saved.title; artist = saved.artist }
        if trackID == KaraokePlaybackTracker.shared.currentTrackId() {
            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
            title = info?[MPMediaItemPropertyTitle] as? String ?? title
            artist = info?[MPMediaItemPropertyArtist] as? String ?? artist
        }
    }
    private func saveOffline(_ track: String) {
        let signature = ASMSongLyricsContext.signature(track)
        guard let lyrics = KaraokeLyricsStore.shared.validatedLyrics(trackId: track, signature: signature) else {
            message = "Open this song's custom lyrics and wait for them to finish loading first."; return
        }
        let entry = ASMLyricsOfflineEntry(trackID: track, signature: signature, title: title, artist: artist, lyrics: lyrics,
            translations: ASMLyricsPreparedTranslations.shared.get(track, signature: signature))
        busy = true
        Task {
            let saved = await Task.detached(priority: .utility) { () -> Bool in
                do { try ASMLyricsOfflineLibrary.shared.save(entry); return true } catch { return false }
            }.value
            busy = false; message = saved ? "Lyrics and credits saved. Prepared translations are kept too." : "Could not save. Remove saved songs if the library is full."
            await reload()
        }
    }
    private func remove(_ track: String) {
        Task {
            let ok = await Task.detached(priority: .utility) { () -> Bool in do { try ASMLyricsOfflineLibrary.shared.remove(track); return true } catch { return false } }.value
            if !ok { message = "The saved song could not be removed." }
            await reload()
        }
    }
    private func refreshLyrics(_ track: String) {
        busy = true; message = "Fetching fresh lyrics…"
        let signature = ASMSongLyricsContext.signature(track)
        Task {
            let ok = await Task.detached(priority: .userInitiated) { () -> Bool in
                do {
                    _ = try loadCustomLyricsForTrackId(track, updatesNativeState: false, bypassOffline: true)
                    return KaraokeLyricsStore.shared.validatedLyrics(trackId: track, signature: signature) != nil
                } catch { return false }
            }.value
            busy = false
            guard ASMSongLyricsContext.signature(track) == signature else { message = "Song preferences changed. Fetch again for the new selection."; return }
            message = ok ? "Fresh lyrics are ready. Save again to update the offline copy." : "Could not fetch fresh lyrics. Existing downloads have been kept."
            if ok { ASMSongLyricsContext.notify(track) }
        }
    }
}

@available(iOS 15.0, *)
struct ASMSongLyricsSheet: View {
    let trackID: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView { ASMSongLyricsSettingsView(trackID: trackID).toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
        } }.navigationViewStyle(.stack).preferredColorScheme(.dark)
    }
}

@available(iOS 15.0, *)
private struct ASMLyricRecordingSearch: View {
    let trackID: String
    let initialQuery: String
    let onChoice: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ASMLyricRecording] = []
    @State private var busy = false
    @State private var message = ""
    @State private var revision = UUID()
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Song and artist", text: $query).onSubmit { find() }
                    Button(busy ? "Searching…" : "Search LRCLIB recordings") { find() }.disabled(busy || query.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !message.isEmpty { ASMText(message).font(.footnote).foregroundColor(.secondary) }
                } footer: { ASMText("Choose explicitly: live, acoustic, remastered and studio recordings can have different timings. Only timed results are listed. Other sources remain available through the source picker.") }
                ForEach(results) { result in
                    Button {
                        var preference = ASMSongLyricsPreferences.shared.get(trackID)
                        preference.source = LyricsSource.lrclib.rawValue; preference.recordingID = result.id; preference.recordingLabel = result.label
                        guard ASMSongLyricsPreferences.shared.set(preference, track: trackID) else { message = "Could not save this choice."; return }
                        ASMSongLyricsContext.notify(trackID); onChoice(); dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            ASMText(result.trackName).font(.headline)
                            ASMText(result.artistName + " · " + (result.albumName ?? "Unknown album")).font(.subheadline).foregroundColor(.secondary)
                            if let duration = result.duration, duration.isFinite, duration >= 0, duration < 86400 {
                                ASMText(String(format: "%d:%02d · timed lyrics", Int(duration) / 60, Int(duration) % 60)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                SpacerView()
            }.eeveeSettingsStyle().navigationTitle("Choose a recording")
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Cancel") { dismiss() } } }
        }.navigationViewStyle(.stack).preferredColorScheme(.dark)
            .onAppear { query = initialQuery }
            .onDisappear { revision = UUID() }
    }
    private func find() {
        let token = UUID(); revision = token; busy = true; results = []; message = ""
        let text = query
        Task {
            let found = await Task.detached(priority: .userInitiated) { try? LrclibLyricsRepository.shared.searchRecordings(text) }.value
            guard revision == token else { return }
            busy = false; results = found ?? []
            message = found == nil ? "Search could not connect. Try again." : results.isEmpty ? "No timed recordings found. Try a different song title or artist." : "Tap the matching recording to remember it for this Spotify song."
        }
    }
}
