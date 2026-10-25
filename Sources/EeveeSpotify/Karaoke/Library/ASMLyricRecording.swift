import Foundation

struct ASMLyricRecording: Decodable, Identifiable {
    var id: Int
    var trackName: String
    var artistName: String
    var albumName: String?
    var duration: Double?
    var syncedLyrics: String?
    var instrumental: Bool?
    var label: String { String((trackName + " · " + artistName + " · " + (albumName ?? "")).prefix(300)) }
    var usable: Bool { id > 0 && instrumental != true && !(syncedLyrics?.isEmpty ?? true) }
    static func timedLines(_ lrc: String) -> [(text: String, ms: Int)] {
        guard lrc.utf8.count <= 1024 * 1024,
              let regex = try? NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{1,2}(?:\.\d{1,3})?)\]"#) else { return [] }
        var result: [(String, Int)] = []
        for raw in lrc.components(separatedBy: .newlines).prefix(4000) {
            let string = raw as NSString
            let matches = regex.matches(in: raw, range: NSRange(location: 0, length: string.length))
            guard let last = matches.last, matches.first?.range.location == 0 else { continue }
            let text = string.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            for match in matches.prefix(16) {
                guard let minute = Double(string.substring(with: match.range(at: 1))),
                      let second = Double(string.substring(with: match.range(at: 2))), second < 60 else { continue }
                let ms = (minute * 60 + second) * 1000
                guard ms.isFinite, ms >= 0, ms <= 86_400_000 else { continue }
                result.append((String(text.prefix(2000)), Int(ms.rounded())))
            }
        }
        return result.sorted { $0.1 < $1.1 }
    }
}
