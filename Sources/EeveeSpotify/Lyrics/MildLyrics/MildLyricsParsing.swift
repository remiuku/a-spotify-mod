import Foundation

enum MildLyricsParsing {
    static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let value = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: value.length)).map { match in
            (0..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : value.substring(with: match.range(at: $0)) }
        }
    }
    static func recordingMatches(title: String, artist: String, duration: Double, query: LyricsSearchQuery, expectedDuration: Double) -> Bool {
        let ours = MildLyricsBlend.key(query.title), theirs = MildLyricsBlend.key(title)
        let by = String(String.UnicodeScalarView(MildLyricsBlend.key(artist)))
        let wanted = String(String.UnicodeScalarView(MildLyricsBlend.key(query.primaryArtist)))
        return !ours.isEmpty && ours == theirs && !by.isEmpty && !wanted.isEmpty
            && (by == wanted || by.contains(wanted) || wanted.contains(by))
            && (expectedDuration <= 0 || duration <= 0 || abs(expectedDuration - duration) <= 8)
    }
    static func ttml(_ text: String, name: String) -> KaraokeLyricsDto? {
        let xml = text.replacingOccurrences(of: "xmlns:lrc=", with: "xmlns:itunes=")
            .replacingOccurrences(of: "lrc:", with: "itunes:")
        guard let doc = try? SweetTTMLParser.parse(xml, sourceName: name), doc.kind != .static else { return nil }
        func syllables(_ source: [SweetLyricSyllable]) -> [KaraokeSyllableDto] {
            source.map { .init(text: $0.text, startMs: Int($0.start * 1000), endMs: Int($0.end * 1000), isPartOfWord: $0.joinsNext, romanized: $0.romanized) }
        }
        let lines = doc.lines.map { line -> KaraokeLineDto in
            let lead = line.lead.isEmpty ? [KaraokeSyllableDto(text: line.text, startMs: Int(line.start * 1000), endMs: Int(line.end * 1000), isPartOfWord: false)] : syllables(line.lead)
            return KaraokeLineDto(syllables: lead, startMs: Int(line.start * 1000), endMs: Int(line.end * 1000),
                                  oppositeAligned: line.oppositeAligned, backgroundGroups: line.backgroundVocals.map(syllables),
                                  pronunciation: line.romanizedText, translation: line.translation)
        }
        return KaraokeLyricsDto(lines: lines, songWriters: doc.songwriters, providerCode: nil, providerName: name)
    }
    static func lrc(_ text: String, name: String) -> KaraokeLyricsDto? {
        var lines: [KaraokeLineDto] = []
        let offset = matches(#"\[offset:(-?\d+)\]"#, text).first.flatMap { Int($0[1]) } ?? 0
        for raw in text.components(separatedBy: .newlines) {
            let stamps = matches(#"\[(\d+):(\d+(?:[.:]\d+)?)\]"#, raw)
            guard !stamps.isEmpty else { continue }
            let words = raw.replacingOccurrences(of: #"\[\d+:\d+(?:[.:]\d+)?\]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            guard !words.isEmpty else { continue }
            for stamp in stamps {
                let seconds = Double(stamp[2].replacingOccurrences(of: ":", with: ".")) ?? 0
                let start = max(0, Int(((Double(stamp[1]) ?? 0) * 60 + seconds) * 1000) + offset)
                lines.append(.init(syllables: [.init(text: words, startMs: start, endMs: start + 5000, isPartOfWord: false)], startMs: start, endMs: start + 5000))
            }
        }
        lines.sort { $0.startMs < $1.startMs }
        for i in lines.indices where i + 1 < lines.count {
            lines[i].endMs = max(lines[i].startMs, lines[i + 1].startMs)
            lines[i].syllables[0].endMs = lines[i].endMs
        }
        return lines.isEmpty ? nil : .init(lines: lines, songWriters: [], providerCode: nil, providerName: name)
    }
    // YRC has absolute word times, KRC relative word times, QRC places times after text.
    static func words(_ text: String, format: String, name: String) -> KaraokeLyricsDto? {
        var lines: [KaraokeLineDto] = []
        var writers: [String] = []
        var content = text.replacingOccurrences(of: "&#10;", with: "\n").replacingOccurrences(of: "&apos;", with: "'")
        if format == "qrc", let embedded = matches(#"LyricContent="(.*?)""#, content).first { content = embedded[1] }
        content = content.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
        for raw in content.components(separatedBy: .newlines) {
            guard let head = matches(#"^\[(\d+),(\d+)\](.*)$"#, raw).first,
                  let start = Int(head[1]), let duration = Int(head[2]), start < 86_400_000, duration < 600_000 else { continue }
            let pattern = format == "qrc" ? #"(.*?)\((\d+),(\d+)\)"# : format == "krc" ? #"<(\d+),(\d+),\d+>([^<]*)"# : #"\((\d+),(\d+),\d+\)(.*?)(?=\(\d+,\d+,\d+\)|$)"#
            let parts = matches(pattern, head[3])
            var syllables: [KaraokeSyllableDto] = []
            for part in parts {
                let rawText = format == "qrc" ? part[1] : part[3]
                let at = Int(format == "qrc" ? part[2] : part[1]) ?? 0
                let length = Int(format == "qrc" ? part[3] : part[2]) ?? 0
                let body = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty, length >= 0, at < 86_400_000, length < 600_000 else { continue }
                if rawText.first?.isWhitespace == true, !syllables.isEmpty { syllables[syllables.count - 1].isPartOfWord = false }
                let base = format == "krc" ? start : 0
                syllables.append(.init(text: body, startMs: base + at, endMs: base + at + length, isPartOfWord: rawText.last?.isWhitespace != true))
            }
            guard !syllables.isEmpty else { continue }
            if let credit = matches(#"(?i)^(作词|作曲|编曲|制作人|词|曲|lyrics(?:\s+by)?|written(?:\s+by)?|composer|writer|arranger|producer|vocals?|mix(?:ed)?(?:\s+by)?)\s*[:：]\s*(.*)$"#, syllables.plainText).first {
                if credit[1].range(of: #"(?i)词|曲|lyrics|written|composer|writer"#, options: .regularExpression) != nil {
                    writers += credit[2].components(separatedBy: CharacterSet(charactersIn: "/、,&")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
                continue
            }
            if format == "yrc", let first = syllables.first, first.startMs + 1000 < start {
                syllables = syllables.map { var s = $0; s.startMs += start; s.endMs += start; return s }
            }
            syllables[syllables.count - 1].isPartOfWord = false
            lines.append(.init(syllables: syllables, startMs: start, endMs: max(start + duration, syllables.map(\.endMs).max() ?? start)))
        }
        return lines.isEmpty ? nil : .init(lines: lines.sorted { $0.startMs < $1.startMs }, songWriters: Array(Set(writers)).sorted(), providerCode: nil, providerName: name)
    }
    static func content(_ text: String, name: String) -> KaraokeLyricsDto? {
        text.contains("<tt") ? ttml(text, name: name) : lrc(text, name: name)
    }
}
