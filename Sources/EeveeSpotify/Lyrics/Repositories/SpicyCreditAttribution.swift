import Foundation

/// Accepts the API's casing variants and string-form contributor records.
struct SpicyCreditAttribution {
    struct Person {
        let name: String
        let profile: String?
        let avatar: String?
    }
    let origin: String
    let maker: Person?
    let uploader: Person?
    init(_ root: SpicyLyricsJSON) {
        let raw = root["source"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch raw.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") {
        case "apple", "apple_music", "am", "aml": origin = "Apple Music"
        case "spotify", "spotify_lyrics", "spt": origin = "Spotify"
        case "spicy", "spicy_lyrics", "community", "spl": origin = "Spicy Lyrics"
        case "": origin = "Spicy Lyrics"
        default: origin = raw
        }
        func person(_ value: SpicyLyricsJSON?) -> Person? {
            func text(_ keys: [String]) -> String? {
                keys.lazy.compactMap { value?[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            }
            guard let name = value?.stringValue ?? text(["username", "Username", "name", "Name"]), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return Person(name: name, profile: text(["url", "Url", "profileUrl", "ProfileUrl"]),
                          avatar: text(["avatar", "Avatar", "avatarUrl", "AvatarUrl"]))
        }
        let upload = root["UploadAttribution"] ?? root["uploadAttribution"]
        maker = person(upload?["Maker"] ?? upload?["maker"])
        uploader = person(upload?["Uploader"] ?? upload?["uploader"])
    }
}
