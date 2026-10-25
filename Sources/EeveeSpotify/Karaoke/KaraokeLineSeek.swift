/// Lyric providers use milliseconds; Spotify's player seekTo: takes seconds.
enum KaraokeLineSeek {
    static func seconds(startMs: Int, displayedTrackId: String?, playingTrackId: String?) -> Double? {
        guard startMs >= 0,
              let displayedTrackId, !displayedTrackId.isEmpty,
              displayedTrackId == playingTrackId else { return nil }
        return Double(startMs) / 1000.0
    }
}
