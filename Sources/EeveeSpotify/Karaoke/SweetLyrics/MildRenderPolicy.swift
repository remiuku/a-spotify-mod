import Foundation

enum MildRenderPolicy {
    static func document(_ original: SweetLyricsDocument, options: MildLyricsOptions) -> SweetLyricsDocument {
        var document = original
        document.lines = original.lines.map { source in
            var line = source
            if options.flag("fold_adlibs") { line.background = []; line.backgroundGroups = [] }
            let gap = options.number("merge_splits") / 1000
            if gap > 0 {
                var merged: [SweetLyricSyllable] = []
                for syllable in line.lead {
                    if let last = merged.last, last.joinsNext, syllable.start >= last.end, syllable.start - last.end <= gap {
                        merged[merged.count - 1].text += syllable.text
                        merged[merged.count - 1].end = syllable.end
                        merged[merged.count - 1].joinsNext = syllable.joinsNext
                    } else { merged.append(syllable) }
                }
                line.lead = merged
            }
            if options.choice("roman") == "instead" {
                line.text = roman(line.text)
                line.lead = line.lead.map { var s = $0; s.text = roman(s.text); return s }
                line.backgroundGroups = line.backgroundVocals.map { $0.map { var s = $0; s.text = roman(s.text); return s } }
                line.background = line.backgroundGroups?.flatMap { $0 } ?? []
            }
            return line
        }
        if options.choice("renderer") == "karaoke" { document.kind = .line }
        return document
    }
    static func roman(_ text: String) -> String { text.applyingTransform(.toLatin, reverse: false) ?? text }
    static func visual(_ source: SweetLineVisual, line: SweetPreparedLine, focus: Int, position: Double,
                       options: MildLyricsOptions, reduceMotion: Bool) -> SweetLineVisual {
        var result = source
        let style = options.choice("renderer"), distance = abs(line.id - focus), limit = Int(options.number("focus"))
        if (limit > 0 && distance > limit) || (style == "spotlight" && distance > 1) { result.opacity = 0.06 }
        if style == "snap" { result.line.gradient = position >= line.start ? 1 : -1 }
        if style == "amll" { result.scale = source.state == .active ? 1.04 : 1 }
        func glyph(_ glyph: SweetGlyphVisual, start: Double, end: Double) -> SweetGlyphVisual {
            var g = glyph
            let long = end - start >= options.number("pop_min")
            let linger = position >= end && position < end + options.number("pop_linger")
            g.scale = reduceMotion ? 1 : 1 + (g.scale - 1) * (long ? options.number("pop") : 0)
            if linger && !reduceMotion && long { g.scale = max(g.scale, 1 + 0.035 * options.number("pop")) }
            g.yOffset = reduceMotion ? 0 : g.yOffset * options.number("rise")
            g.glow = g.glow * (long ? options.number("pop_glow") : 1)
                + (position >= start && position < end ? options.number("word_glow") : 0)
            if style == "snap" { g.gradient = position >= start ? 1 : -1; g.scale = 1; g.yOffset = 0 }
            if style == "flow" { g.scale = 1; g.yOffset = 0 }
            if style == "amll" {
                g.scale = 1 + (g.scale - 1) * 1.6
                g.yOffset *= 1.5
                g.glow *= 0.4
            }
            return g
        }
        if case .syllable(let words, _) = line.kind {
            result.lead = source.lead.enumerated().map { w, syllables in
                syllables.enumerated().map { s, original in
                    guard words.indices.contains(w), words[w].syllables.indices.contains(s) else { return original }
                    let timing = words[w].syllables[s]
                    var value = original
                    value.glyph = glyph(value.glyph, start: timing.start, end: timing.end)
                    value.letters = value.letters.enumerated().map { i, g in
                        let letter = timing.letters?.indices.contains(i) == true ? timing.letters![i] : nil
                        return glyph(g, start: letter?.start ?? timing.start, end: letter?.end ?? timing.end)
                    }
                    return value
                }
            }
            if style == "word" {
                let index = words.firstIndex { $0.syllables.contains { $0.start <= position && $0.end > position } }
                result.lead = index.flatMap { result.lead.indices.contains($0) ? [result.lead[$0]] : nil } ?? []
            }
        }
        if reduceMotion {
            result.scale = 1
            result.dots = result.dots.map { var dot = $0; dot.scale = 1; dot.yOffset = 0; return dot }
        }
        return result
    }
    static func line(_ line: SweetPreparedLine, position: Double, options: MildLyricsOptions) -> SweetPreparedLine {
        guard options.choice("renderer") == "word", case .syllable(let words, _) = line.kind else { return line }
        var value = line
        let selected = words.first { word in word.syllables.contains { $0.start <= position && $0.end > position } }
        value.kind = .syllable(lead: selected.map { [$0] } ?? [], background: [])
        return value
    }
}
