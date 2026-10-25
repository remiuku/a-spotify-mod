import Foundation

/// Integrates rate changes at their boundary, rather than applying the new rate
/// to all the time elapsed since the last Spotify state callback.
struct ASMPlaybackClock {
    private var seconds = 0.0
    private var stamp: Double?
    private(set) var baseSpeed = 1.0
    private(set) var audioRate = 1.0
    private(set) var isPlaying = false

    func position(at now: Double) -> Double {
        let elapsed = isPlaying ? stamp.map { max(0, now - $0) } ?? 0 : 0
        return max(0, seconds + elapsed * baseSpeed * audioRate)
    }
    mutating func receive(position: Double, reportedSpeed: Double, audioRate: Double, playing: Bool, now: Double) {
        seconds = position.isFinite ? max(0, position) : self.position(at: now)
        stamp = now
        self.audioRate = Self.rate(audioRate)
        // SPTPlayerState.playbackSpeed already includes the audio hook's factor.
        baseSpeed = reportedSpeed.isFinite && reportedSpeed > 0 ? reportedSpeed / self.audioRate : 1
        isPlaying = playing
    }
    /// SPTPlayerState.position continues extrapolating from its timestamp even
    /// when isPaused is true. A paused callback must use the stored anchor.
    /// Paused seeks publish a new anchor, so they remain immediately visible.
    mutating func receiveSpotifyState(position: Double?, positionAsOfTimestamp: Double?, reportedSpeed: Double?,
                                      paused: Bool?, playing: Bool?, loading: Bool?, audioRate: Double, now: Double) {
        let running: Bool
        if paused == true || playing == false || loading == true { running = false }
        else if let paused { running = !paused }
        else if let playing { running = playing }
        else if let reportedSpeed, reportedSpeed.isFinite, reportedSpeed <= 0 { running = false }
        else { running = isPlaying }
        func valid(_ value: Double?) -> Double? { value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } }
        let actual: Double
        if running { actual = valid(position) ?? self.position(at: now) }
        else { actual = valid(positionAsOfTimestamp) ?? ((isPlaying || stamp == nil) ? valid(position) : nil) ?? self.position(at: now) }
        let speed = reportedSpeed.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? baseSpeed * Self.rate(audioRate)
        receive(position: actual, reportedSpeed: speed, audioRate: audioRate, playing: running, now: now)
    }

    mutating func changeAudioRate(_ rate: Double, at now: Double) {
        seconds = position(at: now)
        stamp = now
        audioRate = Self.rate(rate)
    }
    private static func rate(_ value: Double) -> Double { value.isFinite && value > 0 ? min(4, max(0.25, value)) : 1 }
}
