import Foundation
import MediaPlayer

extension Notification.Name { static let asmArtworkChanged = Notification.Name("ASMArtworkChanged") }
extension UserDefaults {
    @UserDefault(key: "asm.artwork.options", defaultValue: ASMArtworkOptions()) static var asmArtworkOptions
}

struct ASMArtworkAlbum: Equatable {
    let artist: String
    let album: String
    var key: String { ASMArtworkMetadata.albumKey(artist: artist, album: album) }
    static func current() -> ASMArtworkAlbum? {
        // Read on main; metadata is checked again before any result is displayed.
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        guard let artist = info?[MPMediaItemPropertyArtist] as? String,
              let album = info?[MPMediaItemPropertyAlbumTitle] as? String,
              !artist.isEmpty, !album.isEmpty else { return nil }
        return ASMArtworkAlbum(artist: artist, album: album)
    }
}

/// Metadata-only cache. Video streams are played by AVPlayer, never downloaded
/// into the source checkout. Failed lookups expire, and overrides remain local.
final class ASMArtworkRepository {
    static let shared = ASMArtworkRepository()
    private struct Cached { let url: URL?; let expires: Date }
    private let lock = NSLock()
    private var cache: [String: Cached] = [:]
    private let requests = KaraokeLookupRequests<String, URL?>()
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()
    static var library: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("a spotify mod/Artwork", isDirectory: true)
    }
    func override(for album: ASMArtworkAlbum) -> String {
        (UserDefaults.container.dictionary(forKey: "asm.artwork.overrides") as? [String: String])?[album.key] ?? ""
    }
    func setOverride(_ value: String, for album: ASMArtworkAlbum) {
        var entries = UserDefaults.container.dictionary(forKey: "asm.artwork.overrides") as? [String: String] ?? [:]
        entries[album.key] = value.isEmpty ? nil : value
        UserDefaults.container.set(entries, forKey: "asm.artwork.overrides")
        NotificationCenter.default.post(name: .asmArtworkChanged, object: nil)
    }
    func lookup(_ album: ASMArtworkAlbum, options: ASMArtworkOptions, completion: @escaping (URL?) -> Void) {
        let override = self.override(for: album)
        guard options.video != .off else { completion(nil); return }
        if override.hasPrefix("local:") {
            let name = String(override.dropFirst(6))
            guard name == (name as NSString).lastPathComponent else { completion(nil); return }
            let url = Self.library.appendingPathComponent(name)
            completion(FileManager.default.fileExists(atPath: url.path) ? url : nil)
            return
        }
        guard options.video != .custom || !override.isEmpty else { completion(nil); return }
        let key = album.key + "/" + options.country + "/" + override + "/" + String(options.wifiOnly)
        lock.lock(); let cached = cache[key]; lock.unlock()
        if let cached, cached.expires > Date() { completion(cached.url); return }
        requests.request(key, operation: {
            let result: URL?
            if let custom = URL(string: override), custom.scheme == "https", custom.host != nil {
                if custom.host?.lowercased() == "music.apple.com" { result = try self.fetchAlbum(custom, options: options) }
                else if ["m3u8", "mp4", "mov"].contains(custom.pathExtension.lowercased()) { result = custom }
                else { result = nil }
            } else if options.video == .automatic { result = try self.find(album, options: options) }
            else { result = nil }
            self.lock.lock()
            if self.cache.count > 64 { self.cache = [:] }
            self.cache[key] = Cached(url: result, expires: Date().addingTimeInterval(result == nil ? 300 : 3600))
            self.lock.unlock()
            return result
        }, completion: { completion((try? $0.get()) ?? nil) })
    }
    private func fetch(_ url: URL, options: ASMArtworkOptions, limit: Int) throws -> Data {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = !options.wifiOnly
        request.allowsExpensiveNetworkAccess = !options.wifiOnly
        request.allowsConstrainedNetworkAccess = false
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        let semaphore = DispatchSemaphore(value: 0)
        var received: Data?, responseCode = 0
        let task = session.dataTask(with: request) { data, response, _ in
            responseCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            received = data; semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 20) == .success else { task.cancel(); throw URLError(.timedOut) }
        guard responseCode == 200, let received, received.count <= limit else { throw URLError(.badServerResponse) }
        return received
    }
    private func find(_ album: ASMArtworkAlbum, options: ASMArtworkOptions) throws -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        let country = options.country.range(of: "^[a-zA-Z]{2}$", options: .regularExpression) == nil ? "us" : options.country.lowercased()
        components.queryItems = [URLQueryItem(name: "term", value: album.artist + " " + album.album), URLQueryItem(name: "entity", value: "album"), URLQueryItem(name: "limit", value: "25"), URLQueryItem(name: "country", value: country)]
        let data = try fetch(components.url!, options: options, limit: 1_000_000)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let matched = results.first(where: { ASMArtworkMetadata.matches(artist: album.artist, album: album.album, candidate: $0) }),
              let id = matched["collectionId"] as? NSNumber else { return nil }
        return try fetchAlbum(URL(string: "https://music.apple.com/\(country)/album/\(id.stringValue)")!, options: options)
    }
    private func fetchAlbum(_ url: URL, options: ASMArtworkOptions) throws -> URL? {
        let data = try fetch(url, options: options, limit: 5_000_000)
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        return ASMArtworkMetadata.squareVideo(inHTML: html)
    }
}
