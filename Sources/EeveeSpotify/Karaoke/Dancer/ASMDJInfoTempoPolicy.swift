import Foundation

/// Native adaptation of DJ Info 2.4.2's JSON audio-features normalization.
/// See THIRD_PARTY_DJ_INFO.md / MIT notice for the inspected source pin.
enum ASMDJInfoTempoPolicy {
    static func decode(_ data: Data, track: String) -> ASMDancerTempo? {
        guard data.count <= 256 * 1024, ASMSongLyricsPolicy.validID(track),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["error"] == nil else { return nil }
        let record: [String: Any]
        if let features = json["audio_features"] as? [Any] {
            let records = features.compactMap { $0 as? [String: Any] }
            guard let match = records.first(where: { $0["id"] as? String == track })
                ?? (features.count == 1 ? records.first : nil) else { return nil }
            record = match
        } else { record = json }
        guard record["error"] == nil,
              (record["id"] as? String).map({ $0 == track }) ?? true,
              (record["uri"] as? String).map({ $0 == "spotify:track:" + track }) ?? true,
              let tempo = record["tempo"] as? NSNumber, let bpm = ASMDancerTempo.valid(tempo.doubleValue) else { return nil }
        return ASMDancerTempo(bpm: bpm, source: "Spotify DJ Info")
    }
}
