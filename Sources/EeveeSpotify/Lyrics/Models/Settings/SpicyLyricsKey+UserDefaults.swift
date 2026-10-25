import Foundation

extension UserDefaults {
    private static let spicyLyricsApiKeyKey = "spicyLyricsApiKey"

    static let spicyLyricsDefaultApiKey = "" // supply your own key in settings

    static var spicyLyricsApiKey: String {
        get {
            (container.string(forKey: spicyLyricsApiKeyKey) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set (key) {
            container.set(
                key.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: spicyLyricsApiKeyKey
            )
        }
    }

    static var effectiveSpicyLyricsApiKey: String {
        let key = spicyLyricsApiKey
        return key.isEmpty ? spicyLyricsDefaultApiKey : key
    }
}
