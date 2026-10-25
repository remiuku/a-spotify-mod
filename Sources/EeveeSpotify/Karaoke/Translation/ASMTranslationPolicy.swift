import Foundation

struct ASMTranslationOptions: Codable, Hashable {
    var enabled = false
    var source = "auto"
    var target = Locale.current.language.languageCode?.identifier ?? "en"
    static let key = "asm.lyrics.translation.options"
    static func load(from store: UserDefaults = .standard) -> Self {
        store.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }
    static func forTrack(_ track: String?) -> Self {
        var value = load()
        if let target = ASMSongLyricsPreferences.shared.get(track).targetLanguage { value.target = target }
        return value
    }
    func save(to store: UserDefaults = .standard) {
        store.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}

/// Display-only requests: original words, timing, source/blend results and
/// provider metadata are never rewritten by machine translation.
struct ASMTranslationPlan: Hashable {
    let texts: [String]
    let supplied: [String: String]
    static func text(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
    static func reply(identifier: String?, original: String, translated: String, batch: [String]) -> (String, String)? {
        guard let identifier, let index = Int(identifier), batch.indices.contains(index),
              batch[index] == original, let value = text(translated) else { return nil }
        return (batch[index], value)
    }
    static func matchesTarget(_ language: String, confidence: Double, target: String) -> Bool {
        guard confidence >= 0.65, Locale.Language(identifier: language).languageCode
                == Locale.Language(identifier: target).languageCode else { return false }
        let scripts = ["Hans", "Hant"]
        let sourceScript = language.split(separator: "-").map(String.init).first(where: scripts.contains)
        let targetScript = target.split(separator: "-").map(String.init).first(where: scripts.contains)
        return sourceScript == nil || targetScript == nil || sourceScript == targetScript
    }
    init(lyrics: KaraokeLyricsDto) {
        var seen = Set<String>(), allTexts: [String] = [], characters = 0
        // Prefer supplied translations even when a repeated chorus has some
        // copies without metadata. A repeated phrase needs only one request.
        let supplied: [String: String] = lyrics.lines.reduce(into: [:]) { values, line in
            if let original = Self.text((line.sweetSyllables ?? line.syllables).plainText),
               let translation = Self.text(line.translation), translation.count <= 8_000 { values[original] = translation }
        }
        for line in lyrics.lines {
            guard let value = Self.text((line.sweetSyllables ?? line.syllables).plainText),
                  seen.insert(value).inserted,
                  value.unicodeScalars.contains(where: CharacterSet.letters.contains),
                  value.count <= 1_000, allTexts.count < 512, characters + value.count <= 24_000 else { continue }
            allTexts.append(value); characters += value.count
        }
        self.texts = allTexts
        self.supplied = supplied.filter { allTexts.contains($0.key) }
    }
}

struct ASMTranslationJob: Hashable {
    let track: String?
    let plan: ASMTranslationPlan
    let options: ASMTranslationOptions
    let foreground: Bool
}

/// A changed song/language or disabled feature invalidates earlier async work,
/// even when the underlying system call doesn't finish cancellation immediately.
struct ASMTranslationSelection {
    private var revision = 0
    mutating func begin() -> Int { revision += 1; return revision }
    func accepts(_ token: Int, cancelled: Bool) -> Bool { token == revision && !cancelled }
}
