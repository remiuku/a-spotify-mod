import Foundation

enum SweetLyricsAdapter {
    static func document(from lyrics: KaraokeLyricsDto) -> SweetLyricsDocument {
        let timed = lyrics.lines.contains { line in
            (line.sweetSyllables ?? line.syllables).contains { $0.endMs > $0.startMs }
                || !line.backgroundGroups.isEmpty
        }
        func convert(_ syllables: [KaraokeSyllableDto]) -> [SweetLyricSyllable] {
            syllables.map { .init(text: $0.text, romanized: $0.romanized, start: Double($0.startMs) / 1000,
                                 end: Double(max($0.startMs, $0.endMs)) / 1000, joinsNext: $0.isPartOfWord) }
        }
        let lines = lyrics.lines.map { line -> SweetLyricLine in
            let source = line.sweetSyllables ?? line.syllables
            let groups = line.backgroundGroups.map(convert)
            let lead: [SweetLyricSyllable]
            if timed, source.allSatisfy({ $0.endMs <= $0.startMs }) {
                // Mixed documents keep line-only timing as one full-line syllable.
                lead = [.init(text: source.plainText, start: Double(line.startMs) / 1000,
                              end: Double(max(line.startMs, line.endMs)) / 1000, joinsNext: false)]
            } else { lead = convert(source) }
            let all = lead + groups.flatMap { $0 }
            return SweetLyricLine(start: min(Double(line.startMs) / 1000, all.map(\.start).min() ?? .infinity),
                                  end: max(Double(line.endMs) / 1000, all.map(\.end).max() ?? 0),
                                  oppositeAligned: line.oppositeAligned, text: source.plainText, romanizedText: line.pronunciation,
                                  lead: lead, background: groups.flatMap { $0 }, backgroundGroups: groups, translation: line.translation)
        }
        let credits = SweetLyricsCredits(
            providedBy: lyrics.providerName ?? lyrics.providerCode,
            maker: lyrics.makerName.map { SweetLyricsContributor(name: $0, profileURL: lyrics.makerUrl.flatMap(URL.init(string:)), avatarURL: lyrics.makerAvatarUrl.flatMap(URL.init(string:))) },
            uploader: lyrics.uploaderName.map { SweetLyricsContributor(name: $0, profileURL: lyrics.uploaderUrl.flatMap(URL.init(string:)), avatarURL: lyrics.uploaderAvatarUrl.flatMap(URL.init(string:))) }
        )
        return SweetLyricsDocument(kind: timed ? .syllable : .line, lines: lines,
                                   songwriters: lyrics.songWriters, sourceName: credits.providedBy ?? "", credits: credits)
    }

    static func seekStartMs(for line: SweetPreparedLine) -> Int? {
        guard !line.isInterlude, line.start.isFinite, line.start >= 0, line.start < 1e9 else { return nil }
        return Int((line.start * 1000).rounded())
    }
}
