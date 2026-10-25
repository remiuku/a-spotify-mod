import Foundation

/// Main-thread request coalescing. Only the current track is requested, using
/// the existing native Spotify session token; no login or developer key added.
final class ASMDJInfoTempoClient {
    static let shared = ASMDJInfoTempoClient()
    private struct Entry: Codable { let bpm: Double; let saved: Date }
    private var cache: [String: Entry] = [:]
    private var pending = Set<String>()
    private var attempts: [String: Date] = [:]
    private var tokens: [String: String] = [:]
    private var statuses: [String: String] = [:]
    private let session: URLSession
    private let key = "asm.lyrics.djInfoTempoCache.v1"
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8; config.timeoutIntervalForResource = 12; config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        if let data = UserDefaults.standard.data(forKey: key), data.count < 64 * 1024,
           let values = try? JSONDecoder().decode([String: Entry].self, from: data) {
            cache = values.filter { ASMSongLyricsPolicy.validID($0.key) && ASMDancerTempo.valid($0.value.bpm) != nil
                && Date().timeIntervalSince($0.value.saved) < 7 * 86400 }
        }
    }
    func cached(_ track: String?) -> ASMDancerTempo? {
        guard let track, let entry = cache[track], Date().timeIntervalSince(entry.saved) < 7 * 86400 else { return nil }
        return ASMDancerTempo(bpm: entry.bpm, source: "Spotify DJ Info")
    }
    func status(_ track: String?) -> String { track.flatMap { statuses[$0] } ?? "Spotify DJ Info lookup not started." }
    func request(_ track: String) {
        guard ASMSongLyricsPolicy.validID(track), cached(track) == nil, !pending.contains(track) else { return }
        guard let token = spotifyAccessToken, !token.isEmpty else { statuses[track] = "Waiting for Spotify's session token."; return }
        if let previous = attempts[track], Date().timeIntervalSince(previous) < 60, tokens[track] == token { return }
        if attempts.count >= 128 { attempts.removeAll(); tokens.removeAll(); statuses.removeAll() }
        attempts[track] = Date(); tokens[track] = token; pending.insert(track)
        statuses[track] = "Looking up Spotify DJ Info…"
        perform(track: track, token: token, individual: false)
    }
    private func perform(track: String, token: String, individual: Bool) {
        let base = "https://spclient.wg.spotify.com/audio-attributes/v1/audio-features"
        let url = URL(string: individual ? base + "/" + track + "?format=json" : base + "?ids=" + track)!
        var request = URLRequest(url: url)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(EeveeSpotify.spotifyVersion, forHTTPHeaderField: "Spotify-App-Version")
        request.setValue("iOS", forHTTPHeaderField: "App-Platform")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { [weak self] data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode
            let tempo = code == 200 ? data.flatMap { ASMDJInfoTempoPolicy.decode($0, track: track) } : nil
            DispatchQueue.main.async {
                guard let self else { return }
                if let tempo {
                    self.cache[track] = Entry(bpm: tempo.bpm, saved: Date())
                    if self.cache.count > 128, let oldest = self.cache.min(by: { $0.value.saved < $1.value.saved })?.key { self.cache[oldest] = nil }
                    UserDefaults.standard.set(try? JSONEncoder().encode(self.cache), forKey: self.key)
                    self.statuses[track] = "Spotify DJ Info tempo ready."
                    self.pending.remove(track); return
                }
                // Follow the same batch -> single-track fallback as DJ Info.
                // Auth/rate failures don't trigger another immediate request.
                if !individual, code != 401, code != 403, code != 429 {
                    self.perform(track: track, token: token, individual: true); return
                }
                self.pending.remove(track)
                if let code, code != 200 { self.statuses[track] = "Spotify DJ Info unavailable (HTTP \(code))." }
                else { self.statuses[track] = error == nil ? "Spotify DJ Info returned no tempo for this track." : "Spotify DJ Info could not connect." }
                // No token, request headers or response body is written to logs.
            }
        }.resume()
    }
}
