import SwiftUI

/// A compact header action; viewer selection and presets stay in settings.
@available(iOS 15.0, *)
struct ASMLyricsSoundButton: View {
    @State private var audio = false
    @State private var songLyrics = false
    var body: some View {
        Button { audio = true } label: {
            ASMImage(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sound")
        .accessibilityHint("Open quick audio controls. Hold for song lyrics and offline settings.")
        .contextMenu { Button("Song lyrics & offline") { songLyrics = true } }
        .sheet(isPresented: $audio) { ASMAudioQuickView().preferredColorScheme(.dark) }
        .sheet(isPresented: $songLyrics) { ASMSongLyricsSheet(trackID: KaraokePlaybackTracker.shared.currentTrackId()) }
    }
}
