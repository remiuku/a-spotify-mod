import Foundation
import QuartzCore
import EeveeSpotifyC

/// Main-thread ownership; the one-second analysis runs on a utility queue.
/// The audio callback only collects bounded scalar onset strengths in C.
final class ASMDancerTempoService {
    static let shared = ASMDancerTempoService()
    private var owners = Set<UUID>()
    private var track: String?
    private var rate = 1.0
    private var revision: UInt32 = 0
    private var timer: DispatchSourceTimer?
    private var estimate: ASMDancerTempo?
    private var previousCandidate: Double?
    private var stable = 0
    private var lastPosition: (Int, Double)?
    private var message = "Waiting for music on this device."
    private let worker = DispatchQueue(label: "asm.dancer.tempo.analysis", qos: .utility)

    func tempo(for snapshot: ASMDancerSnapshot) -> ASMDancerTempo? {
        if let metadata = snapshot.tempo { return metadata }
        if let remote = ASMDJInfoTempoClient.shared.cached(snapshot.trackId) { return remote }
        return snapshot.trackId == track ? estimate : nil
    }
    func status(snapshot: ASMDancerSnapshot, options: ASMDancerOptions) -> String {
        if !options.enabled { return "Dancer is disabled. Animation preview still works." }
        if !options.sync { return "Original animation timing · BPM sync off." }
        if options.forceManual { return String(format: "Manual: %.0f BPM", options.fallbackBPM) }
        let selected = options.estimateBPM ? tempo(for: snapshot) : snapshot.tempo ?? ASMDJInfoTempoClient.shared.cached(snapshot.trackId)
        if let tempo = selected { return String(format: "%.1f BPM · %@", tempo.bpm, tempo.source) }
        let remote = ASMDJInfoTempoClient.shared.status(snapshot.trackId)
        if !options.estimateBPM { return remote + " Manual BPM fallback." }
        if !snapshot.isPlaying { return "Play a song on this phone to estimate BPM." }
        return remote + " " + message + " Manual BPM is used while waiting."
    }
    func update(owner: UUID, snapshot: ASMDancerSnapshot, options: ASMDancerOptions, active: Bool) {
        if active, options.enabled, options.sync, !options.forceManual, let track = snapshot.trackId, snapshot.tempo == nil {
            ASMDJInfoTempoClient.shared.request(track)
        }
        let needed = active && options.enabled && options.sync && options.estimateBPM && !options.forceManual
            && snapshot.isPlaying && snapshot.trackId != nil && snapshot.tempo == nil && ASMDJInfoTempoClient.shared.cached(snapshot.trackId) == nil
        guard needed else { lastPosition = nil; removeOwner(owner); return }
        owners.insert(owner)
        let speed = ASMPlaybackRate(), now = CACurrentMediaTime()
        let jumped = lastPosition.map { abs(Double(snapshot.positionMs - $0.0) / 1000 - (now - $0.1) * speed) > 2 } ?? false
        if snapshot.trackId != track || abs(rate - speed) > 0.001 || jumped {
            stop(); track = snapshot.trackId; rate = speed; estimate = nil; stable = 0; previousCandidate = nil
        }
        lastPosition = (snapshot.positionMs, now)
        if timer == nil { start() }
    }
    func removeOwner(_ owner: UUID) {
        if !Thread.isMainThread { DispatchQueue.main.async { self.removeOwner(owner) }; return }
        owners.remove(owner)
        if owners.isEmpty { stop() }
    }
    private func stop() {
        guard timer != nil else { return }
        timer?.cancel(); timer = nil; revision &+= 1
        ASMTempoCaptureSetEnabled(false, revision)
    }
    private func start() {
        revision &+= 1; let token = revision, audioRate = rate
        message = "Listening for a steady beat…"
        ASMTempoCaptureSetEnabled(true, token)
        let source = DispatchSource.makeTimerSource(queue: worker)
        source.schedule(deadline: .now() + 1, repeating: 1)
        source.setEventHandler { [weak self] in
            var values = [Float](repeating: 0, count: 1600), hops: UInt64 = 0
            let capacity = UInt32(values.count)
            let count = ASMTempoCaptureRead(&values, capacity, token, &hops)
            let result = count > 0 ? ASMTempoEstimator.estimate(Array(values.prefix(Int(count)))) : nil
            DispatchQueue.main.async {
                guard let self, self.revision == token, self.timer != nil else { return }
                if hops == 0 { self.message = "No local output samples yet. Spotify Connect playback on another device cannot be analyzed."; return }
                if hops < 800 { self.message = "Listening: \(hops / 100)/8 seconds…"; return }
                guard let result, let bpm = ASMDancerTempo.valid(result.bpm / max(0.25, audioRate)) else {
                    self.message = "No steady beat detected yet."; return
                }
                if let previous = self.previousCandidate, abs(bpm - previous) / previous < 0.035 { self.stable += 1 }
                else { self.stable = 1 }
                self.previousCandidate = bpm
                guard self.stable >= 2 else { self.message = "Confirming estimated tempo…"; return }
                self.estimate = ASMDancerTempo(bpm: bpm, source: String(format: "Estimated locally · %.0f%% confidence", result.confidence * 100))
            }
        }
        timer = source; source.resume()
    }
}
