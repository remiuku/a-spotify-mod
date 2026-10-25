import Foundation

struct ASMSongLyricsPreference: Codable, Equatable {
    var source: Int? = nil
    /// Positive values advance the lyric highlight relative to playback.
    var offsetMs = 0
    var targetLanguage: String? = nil
    var recordingID: Int? = nil
    var recordingLabel: String? = nil
    var normalized: Self {
        var value = self
        if let source, ![1, 2, 3, 5, 6].contains(source) { value.source = nil }
        value.offsetMs = min(10_000, max(-10_000, offsetMs))
        if let language = targetLanguage, language.isEmpty || language.count > 32
            || !language.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "-" }) { value.targetLanguage = nil }
        if source != 1 || (recordingID ?? 0) <= 0 { value.recordingID = nil; value.recordingLabel = nil }
        value.recordingLabel = value.recordingLabel.map { String($0.prefix(300)) }
        return value
    }
}

enum ASMSongLyricsPolicy {
    static func validID(_ track: String) -> Bool {
        !track.isEmpty && track.utf8.count <= 64 && track.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }
    }
    /// A stable configuration identity, not Swift's randomized Hasher and not
    /// a stored copy of provider keys/preferences. Offset/language do not fetch
    /// a different lyric document; source and recording choices do.
    static func signature(source: Int, recording: Int?, configuration: Data) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in configuration { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return "v1/\(source)/\(recording ?? 0)/" + String(hash, radix: 16)
    }
    static func displayPosition(_ milliseconds: Int, offset: Int) -> Int { max(0, milliseconds + min(10_000, max(-10_000, offset))) }
    static func seekPosition(_ milliseconds: Int, offset: Int) -> Int { max(0, milliseconds - min(10_000, max(-10_000, offset))) }
}

final class ASMSongLyricsPreferences {
    static let shared = ASMSongLyricsPreferences()
    static let key = "asm.lyrics.songPreferences.v1"
    private let lock = NSRecursiveLock()
    private let store: UserDefaults
    private var values: [String: ASMSongLyricsPreference]
    init(store: UserDefaults = .standard) {
        self.store = store
        let data = store.data(forKey: Self.key) ?? Data()
        let decoded = data.count <= 2 * 1024 * 1024 ? (try? JSONDecoder().decode([String: ASMSongLyricsPreference].self, from: data)) : nil
        values = (decoded ?? [:]).filter { ASMSongLyricsPolicy.validID($0.key) }.mapValues { $0.normalized }
    }
    func get(_ track: String?) -> ASMSongLyricsPreference {
        lock.lock(); defer { lock.unlock() }
        return track.flatMap { values[$0] } ?? ASMSongLyricsPreference()
    }
    @discardableResult func set(_ value: ASMSongLyricsPreference, track: String) -> Bool {
        guard ASMSongLyricsPolicy.validID(track) else { return false }
        lock.lock(); defer { lock.unlock() }
        guard values[track] != nil || values.count < 2000 else { return false }
        let previous = values[track]
        values[track] = value.normalized
        guard let data = try? JSONEncoder().encode(values), data.count <= 2 * 1024 * 1024 else { values[track] = previous; return false }
        store.set(data, forKey: Self.key)
        return true
    }
    func reset(_ track: String) {
        lock.lock(); defer { lock.unlock() }
        values.removeValue(forKey: track)
        store.set(try? JSONEncoder().encode(values), forKey: Self.key)
    }
}

enum ASMLyricsWakePolicy {
    static func active(visible: Bool, foreground: Bool, enabled: Bool, playing: Bool, musicTrack: Bool) -> Bool {
        visible && foreground && enabled && playing && musicTrack
    }
}
