import Foundation

actor ASMTranslationCache {
    struct Entry: Codable {
        let source: String
        let target: String
        let text: String
        let translation: String
    }
    static let shared = ASMTranslationCache(url: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        .first?.appendingPathComponent("ASMLyricTranslations/v1.json"))
    private let url: URL?
    private var entries: [Entry] = []
    private var loaded = false
    private let maximumBytes = 1_048_576
    init(url: URL?) { self.url = url }
    private func load() {
        guard !loaded else { return }; loaded = true
        guard let url, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maximumBytes, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = Array(decoded.filter { !$0.text.isEmpty && !$0.translation.isEmpty }.suffix(512))
    }
    func lookup(_ texts: [String], source: String, target: String) -> [String: String] {
        load()
        let wanted = Set(texts)
        return entries.reduce(into: [:]) { result, entry in
            if entry.source == source, entry.target == target, wanted.contains(entry.text) {
                result[entry.text] = entry.translation
            }
        }
    }
    func store(_ values: [String: String], source: String, target: String) {
        load()
        for (text, translation) in values.sorted(by: { $0.key < $1.key }) {
            guard text.count <= 1_000, translation.count <= 8_000,
                  ASMTranslationPlan.text(text) != nil, ASMTranslationPlan.text(translation) != nil else { continue }
            entries.removeAll { $0.source == source && $0.target == target && $0.text == text }
            entries.append(Entry(source: source, target: target, text: text, translation: translation))
        }
        entries = Array(entries.suffix(512))
        guard let url else { return }
        do {
            var data = try JSONEncoder().encode(entries)
            while data.count > maximumBytes, !entries.isEmpty {
                entries.removeFirst(min(32, entries.count)); data = try JSONEncoder().encode(entries)
            }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch { /* A cache failure must never block lyrics or playback. */ }
    }
    func clear() {
        loaded = true; entries.removeAll()
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
