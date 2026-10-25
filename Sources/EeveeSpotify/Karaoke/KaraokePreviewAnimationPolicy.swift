import Foundation

/// Compact use of the existing Sweet renderer: at most three lead lines, no
/// interludes/background rows or loose-word scene, and deliberately gentle motion.
enum KaraokePreviewAnimationPolicy {
    static func window(_ lyrics: SweetPreparedLyrics, position: Double) -> SweetPreparedLyrics {
        var low = 0, high = lyrics.lines.count
        while low < high {
            let middle = (low + high) / 2
            if lyrics.lines[middle].start <= position { low = middle + 1 } else { high = middle }
        }
        let focus = max(0, low - 1)
        let start = min(max(0, focus - 1), max(0, lyrics.lines.count - 3))
        var result = lyrics
        result.lines = Array(lyrics.lines[start..<min(lyrics.lines.count, start + 3)])
        return result
    }

    static func shouldPublish(visible: Bool, position: Int, playing: Bool,
                              previousPosition: Int?, previousPlaying: Bool?) -> Bool {
        visible && (playing || position != previousPosition || playing != previousPlaying)
    }

    static func compact(_ source: SweetLineVisual, reduceMotion: Bool) -> SweetLineVisual {
        var result = source
        result.blur = 0
        result.opacity = source.state == .active ? 1 : 0.38
        result.scale = reduceMotion ? 1 : max(0.98, min(1.025, result.scale))
        func glyph(_ value: SweetGlyphVisual) -> SweetGlyphVisual {
            var value = value
            value.scale = reduceMotion ? 1 : max(0.97, min(1.035, value.scale))
            value.yOffset = reduceMotion ? 0 : max(-0.025, min(0.025, value.yOffset))
            value.glow = max(0, min(0.65, value.glow))
            return value
        }
        func words(_ values: [[SweetSyllableVisual]]) -> [[SweetSyllableVisual]] {
            values.map { $0.map { original in
                var value = original
                value.glyph = glyph(value.glyph)
                value.letters = value.letters.map(glyph)
                return value
            } }
        }
        result.line = glyph(result.line)
        result.lead = words(result.lead)
        result.background = words(result.background)
        return result
    }
}
