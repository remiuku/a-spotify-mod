import Foundation

struct ASMLyricsOfflineEntry: Codable, Identifiable {
    var schema = 1
    var trackID: String
    var signature: String
    var title: String
    var artist: String
    var lyrics: KaraokeLyricsDto
    var translations: [String: [String: String]] = [:]
    var savedAt = Date()
    var id: String { trackID }
}

/// Application Support, not the purgeable transient lyric or ML caches. All
/// filesystem access is serialized; callers perform it away from the UI loop.
final class ASMLyricsOfflineLibrary {
    static let shared = ASMLyricsOfflineLibrary()
    private let queue = DispatchQueue(label: "asm.lyrics.offline")
    private let directory: URL
    private let maximumEntries: Int
    private let maximumBytes: Int
    enum Failure: Error { case invalid, full }
    init(directory: URL? = nil, maximumEntries: Int = 100, maximumBytes: Int = 50 * 1024 * 1024) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ASMLyricsOffline/v1", isDirectory: true)
        self.maximumEntries = maximumEntries; self.maximumBytes = maximumBytes
    }
    private func path(_ track: String) -> URL { directory.appendingPathComponent(track).appendingPathExtension("json") }
    private func files() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]))?
            .filter { $0.pathExtension == "json" } ?? []
    }
    private func read(_ track: String) -> ASMLyricsOfflineEntry? {
        guard ASMSongLyricsPolicy.validID(track),
              let size = try? path(track).resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2 * 1024 * 1024,
              let data = try? Data(contentsOf: path(track)), let entry = try? JSONDecoder().decode(ASMLyricsOfflineEntry.self, from: data),
              entry.schema == 1, entry.trackID == track, !entry.lyrics.lines.isEmpty else { return nil }
        return entry
    }
    func load(_ track: String, signature: String) -> ASMLyricsOfflineEntry? {
        queue.sync { guard let entry = read(track), entry.signature == signature else { return nil }; return entry }
    }
    func entries() -> [ASMLyricsOfflineEntry] {
        queue.sync { files().compactMap { read($0.deletingPathExtension().lastPathComponent) }.sorted { $0.savedAt > $1.savedAt } }
    }
    func save(_ entry: ASMLyricsOfflineEntry) throws {
        try queue.sync {
            guard ASMSongLyricsPolicy.validID(entry.trackID), !entry.lyrics.lines.isEmpty else { throw Failure.invalid }
            var value = entry
            if let old = read(entry.trackID), old.signature == entry.signature {
                value.translations.merge(old.translations) { new, _ in new }
            }
            try write(value)
        }
    }
    private func write(_ entry: ASMLyricsOfflineEntry) throws {
        let data = try JSONEncoder().encode(entry)
        guard data.count <= 2 * 1024 * 1024 else { throw Failure.full }
        let existing = files(), destination = path(entry.trackID)
        let other = existing.filter { $0 != destination }
        let size = other.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        guard other.count < maximumEntries, size + data.count <= maximumBytes else { throw Failure.full }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
    }
    func remove(_ track: String) throws {
        try queue.sync {
            guard ASMSongLyricsPolicy.validID(track) else { throw Failure.invalid }
            if FileManager.default.fileExists(atPath: path(track).path) { try FileManager.default.removeItem(at: path(track)) }
        }
    }
    func translations(_ track: String, signature: String, target: String) -> [String: String] {
        load(track, signature: signature)?.translations[target] ?? [:]
    }
    func storeTranslations(_ values: [String: String], track: String, signature: String, target: String) {
        queue.sync {
            guard target.count <= 32, var entry = read(track), entry.signature == signature else { return }
            let allowed = Set(entry.lyrics.lines.map { ($0.sweetSyllables ?? $0.syllables).plainText.trimmingCharacters(in: .whitespacesAndNewlines) })
            let filtered = values.filter { allowed.contains($0.key) && !$0.value.isEmpty && $0.value.count <= 8000 }
            guard !filtered.isEmpty else { return }
            if entry.translations[target] == nil && entry.translations.count >= 4 { return }
            entry.translations[target] = filtered
            try? write(entry)
        }
    }
}
