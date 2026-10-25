import Foundation

@main enum TranslationChecks {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message)
    }
    static func line(_ text: String, translation: String? = nil, start: Int = 0) -> KaraokeLineDto {
        var line = KaraokeLineDto(syllables: [.init(text: text, startMs: start, endMs: start + 1000, isPartOfWord: false)],
                                  startMs: start, endMs: start + 1000)
        line.translation = translation
        return line
    }
    static func main() async throws {
        let dto = KaraokeLyricsDto(lines: [line("One"), line("Two", translation: "Dos"), line("One", start: 2000),
            line("Two"), line("  "), line("♪ ♪"), line(String(repeating: "x", count: 1001))], songWriters: [], providerCode: nil)
        check(ASMTranslationPlan(lyrics: dto).texts == ["One", "Two"], "Deduplicate choruses and exclude empty/music/oversized lines")
        check(ASMTranslationPlan(lyrics: dto).supplied["Two"] == "Dos",
              "Keep a source-translated line eligible for machine fallback when its translation is in the wrong target language")
        check(ASMTranslationPlan.matchesTarget("es", confidence: 0.9, target: "es-MX")
              && !ASMTranslationPlan.matchesTarget("en", confidence: 0.9, target: "es")
              && !ASMTranslationPlan.matchesTarget("es", confidence: 0.2, target: "es")
              && !ASMTranslationPlan.matchesTarget("zh-Hans", confidence: 0.9, target: "zh-Hant"),
              "Source preference respects target language, confidence and Chinese script variants")
        let replies = [("1", "Two", "Dos"), ("0", "One", "Uno")].compactMap {
            ASMTranslationPlan.reply(identifier: $0.0, original: $0.1, translated: $0.2, batch: ["One", "Two"])
        }
        check(Dictionary(uniqueKeysWithValues: replies) == ["One": "Uno", "Two": "Dos"], "Out-of-order replies remain attached to the right original lines")
        check(ASMTranslationPlan.reply(identifier: "0", original: "Two", translated: "Wrong", batch: ["One"]) == nil
              && ASMTranslationPlan.reply(identifier: "100", original: "One", translated: "Wrong", batch: ["One"]) == nil
              && ASMTranslationPlan.reply(identifier: nil, original: "One", translated: "Wrong", batch: ["One"]) == nil,
              "Mismatched/missing reply IDs cannot attach a translation to the wrong lyric")
        var sweet = line("Other base")
        sweet.sweetSyllables = [.init(text: "Actual Sweet words", startMs: 0, endMs: 1000, isPartOfWord: false)]
        check(ASMTranslationPlan(lyrics: .init(lines: [sweet], songWriters: [], providerCode: nil)).texts == ["Actual Sweet words"],
              "Translation lookup uses Sweet's original words, not an alternate renderer's regrouping")
        let defaults = UserDefaults(suiteName: "ASMTranslation-check-\(UUID().uuidString)")!
        var options = ASMTranslationOptions.load(from: defaults)
        check(!options.enabled, "Never enable automatic translation for existing installs without a setting")
        options.enabled = true; options.target = "es"; options.source = "ja"; options.save(to: defaults)
        check(ASMTranslationOptions.load(from: defaults) == options, "Language selection and switch persist separately from source/audio/viewer settings")
        var selection = ASMTranslationSelection()
        let old = selection.begin(), latest = selection.begin()
        check(!selection.accepts(old, cancelled: false) && selection.accepts(latest, cancelled: false)
              && !selection.accepts(latest, cancelled: true), "Late song/language replies and cancelled tasks cannot replace current lyrics")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("asm-translations-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("cache.json")
        let cache = ASMTranslationCache(url: url)
        await cache.store(["Hello": "Hola"], source: "en", target: "es")
        await cache.store(["Hello": "Bonjour"], source: "en", target: "fr")
        let spanish = await cache.lookup(["Hello"], source: "en", target: "es")
        let wrongSource = await cache.lookup(["Hello"], source: "de", target: "es")
        check(spanish["Hello"] == "Hola" && wrongSource.isEmpty, "Cache keys include exact source, target and original text")
        let reopened = ASMTranslationCache(url: url)
        let french = await reopened.lookup(["Hello"], source: "en", target: "fr")
        check(french["Hello"] == "Bonjour", "Translations survive view teardown and process restart")
        await cache.store(["Hello": "Qué tal"], source: "en", target: "es")
        let replaced = await cache.lookup(["Hello"], source: "en", target: "es")
        check(replaced["Hello"] == "Qué tal", "Updated results replace older records for the same pair")
        await cache.store(Dictionary(uniqueKeysWithValues: (0..<1000).map { ("line \($0)", "translation \($0)") }), source: "en", target: "es")
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([ASMTranslationCache.Entry].self, from: data)
        check(records.count <= 512 && data.count <= 1_048_576, "Cache stays bounded over many songs")
        await cache.clear()
        let cleared = await cache.lookup(["Hello"], source: "en", target: "es")
        check(cleared.isEmpty && !FileManager.default.fileExists(atPath: url.path), "Clear removes memory and disk results")
        try Data("broken cache".utf8).write(to: url)
        let corrupt = ASMTranslationCache(url: url)
        let recovered = await corrupt.lookup(["Hello"], source: "en", target: "es")
        check(recovered.isEmpty, "A corrupt cache never blocks original lyrics")
        print("PASS translation: source preference, chorus deduplication, Sweet text identity, opt-in persistence, stale/cancelled reply rejection, language-isolated persistent cache, bounds and corruption recovery")
    }
}
