import Foundation

enum KaraokeVocalMetadata {
    static func decorate(_ line: KaraokeLineDto, from entry: SpicyLyricsJSON, defaultAgent: String?) -> KaraokeLineDto {
        var result = line
        func text(_ names: [String]) -> String? {
            for name in names {
                if let value = entry[name]?.stringValue ?? entry[name]?["Text"]?.stringValue,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            }
            return nil
        }
        result.pronunciation = text(["RomanizedText", "Romanization", "Pronunciation"])
        result.translation = text(["Translation", "TranslatedText"])
        let source = entry["Lead"]?["Syllables"]?.arrayValue ?? entry["Syllables"]?.arrayValue ?? []
        for index in result.syllables.indices where source.indices.contains(index) {
            result.syllables[index].romanized = source[index]["RomanizedText"]?.stringValue ?? source[index]["Pronunciation"]?.stringValue
        }
        if result.pronunciation == nil, !result.syllables.isEmpty, result.syllables.allSatisfy({ $0.romanized != nil }) {
            var roman = result.syllables
            for index in roman.indices { roman[index].text = roman[index].romanized ?? roman[index].text }
            result.pronunciation = roman.plainText
        }
        let agent = entry["Agent"]?.stringValue
        result.oppositeAligned = entry["OppositeAligned"]?.boolValue
            ?? (agent != nil && defaultAgent != nil && agent != defaultAgent)
        let groups = entry["Background"]?.arrayValue ?? entry["Background"].map { [$0] } ?? []
        result.backgroundGroups = groups.compactMap { group in
            let syllables = (group["Syllables"]?.arrayValue ?? []).compactMap { item -> KaraokeSyllableDto? in
                guard let text = item["Text"]?.stringValue, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let start = item["StartTime"]?.doubleValue ?? 0
                let end = item["EndTime"]?.doubleValue ?? start
                guard start.isFinite, end.isFinite, abs(start) < 1e9, abs(end) < 1e9 else { return nil }
                return KaraokeSyllableDto(text: text, startMs: Int(start * 1000), endMs: Int(max(start, end) * 1000),
                                          isPartOfWord: item["IsPartOfWord"]?.boolValue ?? false)
            }
            return syllables.isEmpty ? nil : syllables
        }
        return result
    }
}
