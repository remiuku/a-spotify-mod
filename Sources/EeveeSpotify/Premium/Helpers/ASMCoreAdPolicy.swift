import Foundation

/// Audio-ad routes observed by Vitrine's C++ core delegate fix. Keep ordinary
/// core traffic, playback routes and lookalike hosts outside this interception.
enum ASMCoreAdPolicy {
    static func endpoint(for url: URL) -> String? {
        guard let host = url.host?.lowercased(),
              host == "spotify.com" || host.hasSuffix(".spotify.com") else { return nil }
        let path = url.path.lowercased()
        if path.contains("/ads/") { return "ads-configuration" }
        if path.contains("/ad-logic/") { return "ad-logic" }
        if path.contains("/ad-slot/") || path.contains("/ad-inventory/") { return "ad-inventory" }
        if url.isEsperantoAdRequest { return "esperanto-ad" }
        return nil
    }
}
