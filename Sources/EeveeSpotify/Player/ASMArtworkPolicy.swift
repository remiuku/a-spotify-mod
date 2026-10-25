import Foundation

enum ASMArtworkMotion: String, CaseIterable, Codable { case off, spin, breathe, float, tilt }
enum ASMArtworkVideo: String, CaseIterable, Codable { case off, automatic, custom }

struct ASMArtworkOptions: Codable, Equatable {
    var enabled = false
    var video = ASMArtworkVideo.automatic
    var motion = ASMArtworkMotion.off
    var radius = 24.0
    var shadow = 0.4
    var pausedScale = 0.84
    var motionDuration = 14.0
    var pauseWithMusic = true
    var wifiOnly = true
    var lowPowerStill = true
    var country = "us"

    var safeRadius: Double { radius.isFinite ? min(180, max(0, radius)) : 24 }
    var safeShadow: Double { shadow.isFinite ? min(1, max(0, shadow)) : 0.4 }
    var safePausedScale: Double { pausedScale.isFinite ? min(1, max(0.65, pausedScale)) : 0.84 }
    var safeDuration: Double { motionDuration.isFinite ? min(60, max(2, motionDuration)) : 14 }

    func animates(active: Bool, playing: Bool, reduceMotion: Bool, lowPower: Bool) -> Bool {
        enabled && active && !reduceMotion && !(lowPowerStill && lowPower) && (!pauseWithMusic || playing)
    }
}

/// Only use the primary album header's square artwork. Related albums elsewhere
/// on the page must never supply the current album's fallback video.
enum ASMArtworkMetadata {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
    static func albumKey(artist: String, album: String) -> String { normalized(artist) + "/" + normalized(album) }
    static func matches(artist: String, album: String, candidate: [String: Any]) -> Bool {
        guard !normalized(artist).isEmpty, !normalized(album).isEmpty else { return false }
        return normalized(candidate["artistName"] as? String ?? "") == normalized(artist)
            && normalized(candidate["collectionName"] as? String ?? "") == normalized(album)
    }
    static func squareVideo(inHTML html: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: #"<script\b[^>]*\bid=["']serialized-server-data["'][^>]*>(.*?)</script>"#, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html), let data = String(html[range]).data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = root["data"] as? [[String: Any]], let page = entries.first?["data"] as? [String: Any],
              let sections = page["sections"] as? [[String: Any]],
              let items = sections.first?["items"] as? [[String: Any]], let header = items.first,
              let artwork = header["videoArtwork"] as? [String: Any],
              let dictionary = artwork["dictionary"] as? [String: Any] else { return nil }
        for key in ["motionDetailSquare", "motionSquareVideo", "motionSquare"] {
            guard let square = dictionary[key] as? [String: Any], let raw = square["video"] as? String,
                  let url = URL(string: raw), url.scheme == "https",
                  let host = url.host?.lowercased(), host == "apple.com" || host.hasSuffix(".apple.com") || host.hasSuffix(".mzstatic.com"),
                  url.pathExtension.lowercased() == "m3u8" || url.pathExtension.lowercased() == "mp4" else { continue }
            return url
        }
        return nil
    }
}
