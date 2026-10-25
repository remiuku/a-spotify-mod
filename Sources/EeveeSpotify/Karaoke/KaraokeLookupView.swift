import SwiftUI

struct KaraokeLookupKey: Hashable {
    let trackId: String
    let source: Int
    let options: LyricsOptions
    let mildSettings: Data
    let signature: String

    init(trackId: String) {
        self.trackId = trackId
        source = ASMSongLyricsContext.source(trackId).rawValue
        signature = ASMSongLyricsContext.signature(trackId)
        options = UserDefaults.lyricsOptions
        mildSettings = ASMSongLyricsContext.source(trackId) == .mild ? UserDefaults.mildLyricsOptions.sourceSelectionData : Data()
    }
}

@available(iOS 15.0, *)
final class KaraokeLookupModel: ObservableObject {
    enum Phase {
        case loading, ready(KaraokeLyricsDto), missing, failed, noTrack
    }
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var trackId: String?
    private var selection = KaraokeLookupSelection<KaraokeLookupKey>()
    private static let requests = KaraokeLookupRequests<KaraokeLookupKey, KaraokeLyricsDto?>()

    // Called on main, including notifications. Do not render intermediate
    // provider publications while Mild is still ranking/blending its results.
    func sync(retry: Bool = false, reload: Bool = false) {
        guard KaraokeOverlayPresenter.isAvailableForCurrentTrack(),
              let id = KaraokePlaybackTracker.shared.currentTrackId() else {
            _ = selection.begin(nil)
            trackId = nil
            phase = .noTrack
            return
        }
        let key = KaraokeLookupKey(trackId: id)
        guard retry || reload || selection.key != key else { return }
        let revision = selection.begin(key)
        trackId = id
        if !retry, let cached = KaraokeLyricsStore.shared.validatedLyrics(trackId: id, signature: key.signature) {
            phase = .ready(cached)
            return
        }
        phase = .loading
        writeDebugLog("[KaraokeLookup] searching selected sources independently of Spotify's lyrics availability")
        Self.requests.request(key, operation: {
            // Uses the same source, metadata resolution and fallback policy as
            // the native integration, without changing its global loading state.
            _ = try loadCustomLyricsForTrackId(id, updatesNativeState: false, bypassOffline: retry)
            guard KaraokeLookupKey(trackId: id) == key else { return nil }
            return KaraokeLyricsStore.shared.validatedLyrics(trackId: id, signature: key.signature)
        }) { [weak self] result in
            guard let self,
                  self.selection.accepts(key, revision: revision),
                  KaraokePlaybackTracker.shared.currentTrackId() == id,
                  KaraokeLookupKey(trackId: id) == key else { return }
            switch result {
            case .success(let lyrics):
                self.phase = lyrics.map { .ready($0) } ?? .missing
            case .failure(let error):
                self.phase = (error as? LyricsError) == .noSuchSong ? .missing : .failed
            }
        }
    }
}

/// Owns lookup/loading/empty states so neither renderer needs Spotify to request
/// lyrics first. It also remains open across songs whose lookup is slow or empty.
@available(iOS 15.0, *)
struct KaraokeLookupView: View {
    let onDismiss: () -> Void
    @StateObject private var model = KaraokeLookupModel()
    @State private var selectedRenderer = UserDefaults.karaokeOptions.renderer
    @State private var displayRevision = 0
    @State private var creditsHeight: CGFloat = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            switch model.phase {
            case .ready(let lyrics):
                renderer(lyrics).id("\(model.trackId ?? "")/\(selectedRenderer.rawValue)/\(displayRevision)")
            default:
                status
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if case .ready(let lyrics) = model.phase, selectedRenderer != .spotiPW && selectedRenderer != .vitrine {
                KaraokeCreditsFooterView(lyrics: lyrics)
                    .background(GeometryReader { geometry in Color.clear.preference(key: ASMCreditsHeightKey.self, value: geometry.size.height) })
            }
        }
        .onPreferenceChange(ASMCreditsHeightKey.self) { creditsHeight = $0 }
        .overlay(alignment: .bottomTrailing) {
            if case .ready = model.phase, selectedRenderer != .spotiPW && selectedRenderer != .vitrine {
                let side: CGFloat = verticalSizeClass == .compact ? 44 : 64
                ASMDancerView().frame(width: side, height: side)
                    .padding(.trailing, 24).padding(.bottom, creditsHeight + 6)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.sync() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ASMViewerChanged"))) { _ in
            if UserDefaults.karaokeOptions.renderer == .spotify {
                KaraokeOverlayPresenter.switchToSpotify()
            } else {
                selectedRenderer = UserDefaults.karaokeOptions.renderer
                displayRevision += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eeveeKaraokeLyricsChanged)) { _ in model.sync() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ASMSongLyricsChanged"))) { note in
            guard note.object as? String == model.trackId else { return }
            model.sync(retry: note.userInfo?["refresh"] as? Bool == true, reload: true)
            displayRevision += 1
        }
        .modifier(ASMLyricsKeepAwake())
    }

    @ViewBuilder private func renderer(_ lyrics: KaraokeLyricsDto) -> some View {
        if selectedRenderer == .spotiPW {
            ASMImportedLyricsView(mode: "spotipw", lyrics: lyrics, onDismiss: onDismiss)
        } else if selectedRenderer == .vitrine {
            ASMImportedLyricsView(mode: "vitrine", lyrics: lyrics, onDismiss: onDismiss)
        } else if selectedRenderer == .sweetLyrics, #available(iOS 16.0, *) {
            SweetLyricsOverlayView(trackId: model.trackId, lyrics: lyrics, onDismiss: onDismiss)
        } else {
            KaraokeLyricsView(trackId: model.trackId, lyrics: lyrics, onDismiss: onDismiss)
        }
    }

    private var status: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                ASMLyricsSoundButton()
                Button(action: onDismiss) { ASMImage(systemName: "xmark").font(.title3).padding(12) }
                    .accessibilityLabel("karaoke_close".localized)
            }
            Spacer()
            switch model.phase {
            case .loading:
                ProgressView().tint(.white)
                ASMText("karaoke_lookup_loading".localized)
            case .missing:
                ASMText("karaoke_lookup_missing".localized)
                ASMText("karaoke_lookup_sources_hint".localized).font(.subheadline).foregroundColor(.secondary)
                retryButton
            case .failed:
                ASMText("karaoke_lookup_failed".localized)
                retryButton
            case .noTrack:
                ASMText("karaoke_lookup_no_track".localized)
            case .ready:
                EmptyView()
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .foregroundColor(.white)
        .background(Color.black.ignoresSafeArea())
    }

    private var retryButton: some View {
        ASMButton("karaoke_lookup_retry".localized) { model.sync(retry: true) }
            .buttonStyle(.borderedProminent)
    }
}
