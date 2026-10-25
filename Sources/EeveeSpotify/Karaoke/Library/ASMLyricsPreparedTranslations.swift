import Foundation

/// In-process handoff so Save includes completed translations without a new request.
final class ASMLyricsPreparedTranslations {
    static let shared = ASMLyricsPreparedTranslations()
    private let lock = NSLock()
    private var values: [String: (String, [String: [String: String]])] = [:]
    private var order: [String] = []
    func store(_ translations: [String: String], track: String, signature: String, target: String) {
        lock.lock(); defer { lock.unlock() }
        guard !translations.isEmpty, target.count <= 32 else { return }
        var languages = values[track].flatMap { $0.0 == signature ? $0.1 : nil } ?? [:]
        guard languages[target] != nil || languages.count < 4 else { return }
        var limited: [String: String] = [:], bytes = 0
        for (text, translation) in translations.sorted(by: { $0.key < $1.key }) where text.count <= 1000 && translation.count <= 8000 {
            let size = text.utf8.count + translation.utf8.count
            guard limited.count < 512, bytes + size <= 512 * 1024 else { break }
            limited[text] = translation; bytes += size
        }
        languages[target] = limited
        values[track] = (signature, languages); order.removeAll { $0 == track }; order.append(track)
        while order.count > 8 { values[order.removeFirst()] = nil }
        func cost() -> Int { values.values.reduce(0) { $0 + $1.1.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count } } } }
        while cost() > 6 * 1024 * 1024, !order.isEmpty { values[order.removeFirst()] = nil }
    }
    func get(_ track: String, signature: String) -> [String: [String: String]] {
        lock.lock(); defer { lock.unlock() }
        guard let value = values[track], value.0 == signature else { return [:] }
        return value.1
    }
}
