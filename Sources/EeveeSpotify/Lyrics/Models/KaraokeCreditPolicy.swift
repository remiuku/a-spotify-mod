import Foundation

/// Matches Spicy Lyrics Mobile's footer ordering, labels and measurements.
/// Writers scroll with the document; the remaining source/community rows pin.
enum KaraokeCreditPolicy {
    struct Contributor: Equatable {
        let name: String
        let profile: URL?
        let avatar: URL?
    }
    struct Row: Equatable {
        enum Kind { case provider, community, contributor }
        let kind: Kind
        let text: String
        var label: String? = nil
        var contributor: Contributor? = nil
    }
    static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
    static func https(_ value: String?) -> URL? {
        guard let value = nonEmpty(value), let url = URL(string: value), url.scheme?.lowercased() == "https",
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func contributor(_ name: String?, profile: String?, avatar: String?) -> Contributor? {
        guard let raw = nonEmpty(name), let name = nonEmpty(String(raw.drop(while: { $0 == "@" }))) else { return nil }
        let link = https(profile).flatMap { url -> URL? in
            ["spicylyrics.org", "www.spicylyrics.org", "github.com", "unison.boidu.dev"].contains(url.host?.lowercased() ?? "") ? url : nil
        }
        return Contributor(name: name, profile: link, avatar: https(avatar))
    }
    static func rows(_ lyrics: KaraokeLyricsDto) -> [Row] {
        let maker = contributor(lyrics.makerName, profile: lyrics.makerUrl, avatar: lyrics.makerAvatarUrl)
        let uploader = contributor(lyrics.uploaderName, profile: lyrics.uploaderUrl, avatar: lyrics.uploaderAvatarUrl)
        let catalogue = nonEmpty(lyrics.creditProviderName) ?? nonEmpty(lyrics.providerName)
            ?? (lyrics.providerCode != nil ? "Spicy Lyrics" : nil)
        let origin = nonEmpty(lyrics.creditOrigin) ?? nonEmpty(lyrics.providerName) ?? catalogue
        var rows: [Row] = []
        if let origin { rows.append(Row(kind: .provider, text: "Provided by: " + (origin == "Spicy Lyrics Community" ? "Spicy Lyrics" : origin))) }
        let community = catalogue == "Spicy Lyrics" && (maker != nil || uploader != nil)
        if community { rows.append(Row(kind: .community, text: "These lyrics have been provided by our community")) }
        if let maker { rows.append(Row(kind: .contributor, text: "Made by @" + maker.name, label: "Made by", contributor: maker)) }
        if let uploader {
            let label = maker != nil ? "Uploaded by" : community ? "Made by" : "Submitted by"
            rows.append(Row(kind: .contributor, text: label + " @" + uploader.name, label: label, contributor: uploader))
        }
        return rows
    }
    struct Metrics {
        let lyricSize: Double
        let width: Double
        /// Short viewports use two compact groups and small type independently
        /// of landscape lyric size. Portrait keeps the reference measurements.
        let compact: Bool
        var providerSize: Double { min(compact ? 10.5 : .infinity, lyricSize * 0.34 * 1.15) }
        var communitySize: Double { min(compact ? 10.5 : .infinity, lyricSize * 0.35 * 1.15) }
        var avatarSize: Double { providerSize * 1.4 }
        var horizontalInset: Double { width * 0.05 }
        var rowSpacing: Double { compact ? 3 : 0 }
        init(width: Double, compact: Bool = false) {
            self.width = max(0, width.isFinite ? width : 0)
            self.compact = compact
            let base = min(56, max(29.6, self.width * 0.07))
            lyricSize = compact ? Swift.min(base, 34) : base
        }
        func margin(before kind: Row.Kind) -> Double {
            let ratio = kind == .community ? 0.3 : kind == .contributor ? 0.2 : 0.25
            return lyricSize * ratio * (compact ? 0.6 : 1)
        }
    }
}
