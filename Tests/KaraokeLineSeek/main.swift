private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
}

require(KaraokeLineSeek.seconds(startMs: 12_345, displayedTrackId: "song", playingTrackId: "song") == 12.345,
        "a tapped line must seek in seconds, preserving fractional timing")
require(KaraokeLineSeek.seconds(startMs: 0, displayedTrackId: "song", playingTrackId: "song") == 0,
        "the first line can seek to the start")
require(KaraokeLineSeek.seconds(startMs: -1, displayedTrackId: "song", playingTrackId: "song") == nil,
        "invalid negative timestamps must not seek")
require(KaraokeLineSeek.seconds(startMs: 12_345, displayedTrackId: "previous", playingTrackId: "next") == nil,
        "stale lyrics must not seek the new track")
require(KaraokeLineSeek.seconds(startMs: 12_345, displayedTrackId: "song", playingTrackId: nil) == nil,
        "a lyrics prefetch must not substitute for the player's current track")
require(KaraokeLineSeek.seconds(startMs: 12_345, displayedTrackId: nil, playingTrackId: "song") == nil,
        "lyrics without a track identity must not seek")
require(KaraokeLineSeek.seconds(startMs: 12_345, displayedTrackId: "", playingTrackId: "") == nil,
        "empty matching identifiers must not authorize a seek")
print("Karaoke line seek regression tests passed")
