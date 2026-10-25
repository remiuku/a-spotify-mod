import Foundation
import ObjectiveC.runtime
import EeveeSpotifyC

/// Tracks live playback position and the current track's Spotify ID, for the
/// karaoke overlay's animation loop.
///
/// Kept as its own observer/store (registered separately, see
/// KaraokeHooks.x.swift) rather than reading through SponsorBlockSkipper
/// directly, so the karaoke feature has no dependency on SponsorBlock being
/// enabled or its internal state machine.
final class KaraokePlaybackTracker {
    static let shared = KaraokePlaybackTracker()

    private let queue = DispatchQueue(label: "com.eevee.karaoke.playback")

    private var clock = ASMPlaybackClock()
    private var rateObserver: NSObjectProtocol?
    private var lastTrackId: String?
    // Only ever set from the player observer, unlike lastTrackId (which a lyrics fetch also sets).
    private var observedTrackId: String?
    private var observedTitle: String?
    private var hasObservedItem = false
    private var dancerTempo: ASMDancerTempo?
    private weak var seekPlayer: AnyObject?

    private var didDumpStateShape = false
    private var activityState: String?

    private init() {
        rateObserver = NotificationCenter.default.addObserver(forName: Notification.Name("ASMPlaybackRateChanged"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let rate = ASMPlaybackRate()
            self.queue.async { self.clock.changeAudioRate(rate, at: self.uptimeSec()) }
        }
    }

    func capturePlayer(_ player: AnyObject) {
        guard player.responds(to: NSSelectorFromString("seekTo:")) else { return }
        queue.sync { seekPlayer = player }
    }

    @discardableResult
    func seek(toLineStartMs startMs: Int, trackId: String?) -> Bool {
        // Row buttons invoke this on main. Do not send player commands from the tracking queue.
        guard Thread.isMainThread else { return false }
        guard startMs >= 0 else { return false }
        let (player, playingTrackId) = queue.sync { (seekPlayer, observedTrackId) }
        guard let player,
              let seconds = KaraokeLineSeek.seconds(
                startMs: ASMSongLyricsPolicy.seekPosition(startMs, offset: ASMSongLyricsPreferences.shared.get(trackId).offsetMs), displayedTrackId: trackId, playingTrackId: playingTrackId
              ), EeveeKaraokeSeekToSeconds(player, seconds) else { return false }
        // Follow the player's state callback for highlighting, including rejected seeks and paused playback.
        writeDebugLog("[Karaoke] requested line seek to \(seconds)s")
        ASMActivityRecorder.store.record("playback.seek", ["seconds": String(seconds), "track": trackId ?? "unknown"])
        return true
    }

    /// Reads the verified SPTPlayerState selectors defensively. Its computed
    /// position is live even when paused; the clock chooses positionAsOfTimestamp
    /// in that state and gives pause precedence over a stale isPlaying flag.
    func processStateChange(state: AnyObject) {
        if !didDumpStateShape {
            didDumpStateShape = true
            karaokeDumpClassMethods("playerState", of: state)
        }

        func safeValue(_ key: String) -> Any? {
            guard state.responds(to: Selector(key)) else { return nil }
            return state.value(forKey: key)
        }

        let trackObj = safeValue("track") as AnyObject?
        let uriObj: Any? = trackObj.flatMap { obj -> Any? in
            guard obj.responds(to: Selector("URI")) else { return nil }
            return obj.value(forKey: "URI")
        }
        let uriString: String = {
            if let s = uriObj as? String { return s }
            if let u = uriObj as? URL { return u.absoluteString }
            return ""
        }()

        // spotify:track:<id> — same extraction style used elsewhere in the
        // codebase for episode URIs (extractEpisodeID in SponsorBlockSkipper).
        let trackId: String? = uriString.hasPrefix("spotify:track:")
            ? String(uriString.dropFirst("spotify:track:".count))
            : nil
        let itemKind: String = {
            if uriString.isEmpty { return "unknown" }
            for kind in ["track", "ad", "episode", "local"] {
                if uriString.hasPrefix("spotify:\(kind):") { return kind }
            }
            return "other"
        }()

        let trackTitle: String? = trackObj.flatMap { obj in
            guard obj.responds(to: NSSelectorFromString("trackTitle")) else { return nil }
            return obj.value(forKey: "trackTitle") as? String
        }
        let observedAt = uptimeSec()
        let tempo: ASMDancerTempo? = {
            guard UserDefaults.standard.bool(forKey: ASMDancerOptions.enabledKey),
                  let obj = trackObj, obj.responds(to: NSSelectorFromString("metadata")),
                  let metadata = obj.value(forKey: "metadata") as? [String: String] else { return nil }
            return ASMDancerTempo.read(metadata)
        }()
        let audioRate = ASMPlaybackRate()
        let position = (safeValue("position") as? NSNumber)?.doubleValue
        let frozenPosition = (safeValue("positionAsOfTimestamp") as? NSNumber)?.doubleValue
        let playbackSpeed = (safeValue("playbackSpeed") as? NSNumber)?.doubleValue
        let paused = (safeValue("isPaused") as? NSNumber)?.boolValue
        let playing = (safeValue("isPlaying") as? NSNumber)?.boolValue
        let loading = (safeValue("isLoading") as? NSNumber)?.boolValue

        // A state whose item is not a music track (podcast episode, ad, local file)
        // means the previous track's lyrics no longer apply.
        let isNonTrackItem = trackId == nil && !uriString.isEmpty

        queue.async {
            self.clock.receiveSpotifyState(position: position, positionAsOfTimestamp: frozenPosition, reportedSpeed: playbackSpeed,
                                           paused: paused, playing: playing, loading: loading, audioRate: audioRate, now: observedAt)

            if ASMActivityRecorder.store.isEnabled {
                // Distinguish consecutive ad items without writing ad URIs or IDs.
                let signature = "\(uriString)|\(self.clock.isPlaying)|\(loading ?? false)"
                if signature != self.activityState {
                    self.activityState = signature
                    ASMActivityRecorder.store.record("playback.state", ["track": trackId ?? "non-track",
                        "item_kind": itemKind,
                        "playing": String(self.clock.isPlaying), "loading": String(loading ?? false),
                        "position_seconds": String(self.clock.position(at: observedAt))])
                }
            } else { self.activityState = nil }

            if !uriString.isEmpty { self.hasObservedItem = true; self.observedTitle = trackTitle }
            let previousTrackId = self.lastTrackId
            let previousObservedTrackId = self.observedTrackId
            // A queued lyrics lookup never supplies tempo. Keep a same-track
            // value through sparse callbacks, clear it at every item change.
            if trackId != self.observedTrackId || isNonTrackItem { self.dancerTempo = nil }
            if let tempo, trackId != nil { self.dancerTempo = tempo }
            if let trackId = trackId, !trackId.isEmpty {
                self.lastTrackId = trackId
                self.observedTrackId = trackId
            } else if isNonTrackItem {
                self.lastTrackId = nil
                self.observedTrackId = nil
            }
            // Button visibility follows the track, so tell it when the track changes.
            if self.lastTrackId != previousTrackId || self.observedTrackId != previousObservedTrackId {
                KaraokeLyricsStore.shared.notify()
            }
        }
    }

    func updateTrackIdFromLyricsFetch(_ trackId: String) {
        guard !trackId.isEmpty else { return }
        queue.async {
            guard self.lastTrackId != trackId else { return }
            self.lastTrackId = trackId
            KaraokeLyricsStore.shared.notify()
        }
    }

    /// Estimated current playback position in milliseconds, interpolated
    /// between actual state-change callbacks the same way SponsorBlockSkipper
    /// does — needed because callbacks don't fire every frame, but the
    /// karaoke animation needs a smooth value every frame.
    func playbackSnapshot() -> (positionMs: Int, isPlaying: Bool) {
        queue.sync { (Int(clock.position(at: uptimeSec()) * 1000), clock.isPlaying) }
    }

    func dancerSnapshot() -> ASMDancerSnapshot {
        queue.sync {
            ASMDancerSnapshot(positionMs: Int(clock.position(at: uptimeSec()) * 1000), isPlaying: clock.isPlaying,
                              trackId: hasObservedItem ? observedTrackId : lastTrackId, tempo: dancerTempo)
        }
    }

    func currentPositionMs() -> Int {
        queue.sync { Int(clock.position(at: uptimeSec()) * 1000) }
    }

    func lyricSnapshot() -> (positionMs: Int, isPlaying: Bool) {
        let raw = queue.sync { (Int(clock.position(at: uptimeSec()) * 1000), clock.isPlaying, observedTrackId) }
        return (ASMSongLyricsPolicy.displayPosition(raw.0, offset: ASMSongLyricsPreferences.shared.get(raw.2).offsetMs), raw.1)
    }
    func currentLyricPositionMs() -> Int { lyricSnapshot().positionMs }

    /// The track the player itself reports as playing, or nil when the observer hasn't reported one.
    func matchesNowPlaying(title: String) -> Bool {
        queue.sync { observedTrackId != nil && observedTitle == title }
    }

    func playerReportedTrackId() -> String? {
        queue.sync { observedTrackId }
    }

    func currentTrackId() -> String? {
        // A lyrics request can name a queued song. Once the player has
        // reported an item, only that item determines custom-view access.
        queue.sync { hasObservedItem ? observedTrackId : lastTrackId }
    }

    func isPlaying() -> Bool {
        queue.sync { clock.isPlaying }
    }

    private func uptimeSec() -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000.0
    }
}
