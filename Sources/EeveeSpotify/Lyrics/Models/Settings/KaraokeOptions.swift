import Foundation

enum KaraokeRenderer: String, Codable, CaseIterable {
    case spotify
    case eevee
    case sweetLyrics
    case spotiPW = "spotipw"
    case vitrine

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "spicyMobile" { self = .sweetLyrics; return }
        guard let renderer = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown lyrics renderer")
        }
        self = renderer
    }

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .eevee: return "Eevee"
        case .sweetLyrics: return "Sweet Lyrics"
        case .spotiPW: return "spoti.pw"
        case .vitrine: return "Vitrine"
        }
    }
}

enum KaraokeTextAlignment: String, Codable, CaseIterable {
    case leading
    case center
    case trailing

    var displayName: String {
        "karaoke_alignment_\(rawValue)".localized
    }
}

struct KaraokeOptions: Codable, Hashable {
    var renderer: KaraokeRenderer = .eevee
    var sweetSimpleLyrics = false
    var showTranslation = false
    var showPronunciation = false
    var translationDisplay: ASMTranslationDisplay = .bilingual
    var replacePlayerLyrics = true
    var textAlignment: KaraokeTextAlignment = .center
    var reversedDirection = false
    var enabled = true
    var blurIntensity: Double = 1.5

    init(textAlignment: KaraokeTextAlignment = .center, reversedDirection: Bool = false, enabled: Bool = true, blurIntensity: Double = 1.5) {
        self.textAlignment = textAlignment
        self.reversedDirection = reversedDirection
        self.enabled = enabled
        self.blurIntensity = blurIntensity
    }

    private enum CodingKeys: String, CodingKey {
        case renderer, sweetSimpleLyrics, showTranslation, showPronunciation, translationDisplay, replacePlayerLyrics, textAlignment, reversedDirection, enabled, blurIntensity
    }

    // Settings saved before these fields existed must keep decoding.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        renderer = (try? container.decode(KaraokeRenderer.self, forKey: .renderer)) ?? .eevee
        sweetSimpleLyrics = try container.decodeIfPresent(Bool.self, forKey: .sweetSimpleLyrics) ?? false
        showTranslation = try container.decodeIfPresent(Bool.self, forKey: .showTranslation) ?? false
        showPronunciation = try container.decodeIfPresent(Bool.self, forKey: .showPronunciation) ?? false
        translationDisplay = (try? container.decode(ASMTranslationDisplay.self, forKey: .translationDisplay)) ?? .bilingual
        replacePlayerLyrics = try container.decodeIfPresent(Bool.self, forKey: .replacePlayerLyrics) ?? true
        textAlignment = try container.decodeIfPresent(KaraokeTextAlignment.self, forKey: .textAlignment) ?? .center
        reversedDirection = try container.decodeIfPresent(Bool.self, forKey: .reversedDirection) ?? false
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        blurIntensity = try container.decodeIfPresent(Double.self, forKey: .blurIntensity) ?? 1.5
    }
}

enum ASMTranslationDisplay: String, Codable, CaseIterable {
    case original, bilingual, translated
    var title: String {
        switch self {
        case .original: return "Original only"
        case .bilingual: return "Original + translation"
        case .translated: return "Translation only"
        }
    }
    func hideOriginal(translation: String?) -> Bool {
        self == .translated && !(translation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
