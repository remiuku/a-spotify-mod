import SwiftUI

/// Renders the result supplied by KaraokeLookupView. The lookup shell owns
/// track changes, loading and empty states for both renderers.
@available(iOS 15.0, *)
final class KaraokeLyricsViewModel: ObservableObject {
    @Published private(set) var trackId: String?
    @Published private(set) var lyrics: KaraokeLyricsDto?
    @Published private(set) var layouts: [KaraokeLineLayout] = []

    init(trackId: String?, lyrics: KaraokeLyricsDto) {
        self.trackId = trackId
        apply(lyrics)
    }

    private func apply(_ lyrics: KaraokeLyricsDto?) {
        self.lyrics = lyrics
        let songIsRTL = lyrics?.isRTL ?? false
        layouts = lyrics?.lines.map { line in
            let direction = line.strongDirection
            return KaraokeLineLayout(words: line.words, isRTL: direction.map { $0 == .rightToLeft } ?? songIsRTL)
        } ?? []
    }

    func seek(toLineAt index: Int) {
        guard let lyrics, lyrics.lines.indices.contains(index) else { return }
        let requested = KaraokePlaybackTracker.shared.seek(
            toLineStartMs: lyrics.lines[index].startMs,
            trackId: trackId
        )
        if !requested {
            writeDebugLog("[Karaoke] line seek unavailable: missing player, stale track, or invalid timestamp")
        }
    }

}
