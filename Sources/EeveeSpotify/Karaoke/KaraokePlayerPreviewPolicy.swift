import Foundation

enum KaraokePlayerPreviewPolicy {
    struct Row: Equatable, Identifiable {
        let id: Int
        let text: String
        let start: Int
        let end: Int
    }
    static func enabled(options: KaraokeOptions, supportedSource: Bool, musicTrack: Bool, nativeInterface: Bool) -> Bool {
        nativeInterface && musicTrack && supportedSource && options.enabled && options.replacePlayerLyrics && options.renderer != .spotify
    }
    static func rows(_ lyrics: KaraokeLyricsDto) -> [Row] {
        lyrics.lines.enumerated().compactMap { index, line in
            let syllables = line.sweetSyllables ?? line.syllables
            let text = syllables.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Row(id: index, text: text, start: line.startMs, end: max(line.endMs, syllables.map(\.endMs).max() ?? line.endMs))
        }.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }
    static func focus(_ rows: [Row], position: Int) -> Int? {
        guard !rows.isEmpty else { return nil }
        var low = 0, high = rows.count
        while low < high {
            let middle = (low + high) / 2
            if rows[middle].start <= position { low = middle + 1 } else { high = middle }
        }
        return max(0, low - 1)
    }
    static func window(_ rows: [Row], position: Int) -> [Row] {
        guard let index = focus(rows, position: position) else { return [] }
        let start = min(max(0, index - 1), max(0, rows.count - 3))
        return Array(rows[start..<min(rows.count, start + 3)])
    }
}
