import Foundation

enum LyricsSource: Int, CaseIterable, CustomStringConvertible {
    case genius
    case lrclib
    case musixmatch
    case petit
    case notReplaced
    case spicylyrics
    case mild

    public static var allCases: [LyricsSource] {
        return [.spicylyrics, .mild, .musixmatch, .lrclib, .genius, .petit]
    }

    var description: String {
        switch self {
        case .genius:       return "Genius"
        case .lrclib:       return "LRCLIB"
        case .musixmatch:   return "Musixmatch"
        case .petit:        return "PetitLyrics"
        case .notReplaced:  return "Spotify"
        case .spicylyrics:  return "SpicyLyrics"
        case .mild:         return "Mild sources + blends"
        }
    }

    var isReplacingLyrics: Bool { self != .notReplaced }

    /// The custom lyrics view needs time-synced lyrics; Genius only has plain text.
    var supportsCustomLyricsView: Bool { isReplacingLyrics && self != .genius }

    static var defaultSource: LyricsSource {
        .spicylyrics
    }
}
