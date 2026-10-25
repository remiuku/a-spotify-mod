import Foundation

enum ASMSongLyricsContext {
    static func source(_ track: String?) -> LyricsSource {
        ASMSongLyricsPreferences.shared.get(track).source.flatMap(LyricsSource.init(rawValue:)) ?? UserDefaults.lyricsSource
    }
    static func signature(_ track: String) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let config = ((try? encoder.encode(UserDefaults.lyricsOptions)) ?? Data())
            + (source(track) == .mild ? UserDefaults.mildLyricsOptions.sourceSelectionData : Data())
        return ASMSongLyricsPolicy.signature(source: source(track).rawValue,
            recording: ASMSongLyricsPreferences.shared.get(track).recordingID, configuration: config)
    }
    static func notify(_ track: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ASMSongLyricsChanged"), object: track)
            KaraokeLyricsStore.shared.notify()
        }
    }
    static func flattened(_ lyrics: KaraokeLyricsDto) -> LyricsDto {
        LyricsDto(lines: lyrics.lines.map { LyricsLineDto(content: $0.plainText, offsetMs: $0.startMs) },
                  timeSynced: true, romanization: .original, translation: nil, providerCredit: lyrics.providerName)
    }
}
