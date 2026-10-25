import Foundation

struct SweetFrameMetrics {
    struct Sample {
        let ticksPerSecond: Double
        let longestGap: Double
    }
    private var started: Double?
    private var previous: Double?
    private var ticks = 0
    private var longestGap = 0.0

    mutating func reset() { self = SweetFrameMetrics() }

    mutating func record(at now: Double) -> Sample? {
        guard now.isFinite else { return nil }
        guard let started, let previous, now >= previous else {
            self.started = now; self.previous = now; ticks = 0; longestGap = 0
            return nil
        }
        ticks += 1
        longestGap = max(longestGap, now - previous)
        self.previous = now
        let elapsed = now - started
        guard elapsed >= 5 else { return nil }
        let sample = Sample(ticksPerSecond: Double(ticks) / elapsed, longestGap: longestGap)
        self.started = now; ticks = 0; longestGap = 0
        return sample
    }
}

final class SweetFrameDiagnostics {
    private var metrics = SweetFrameMetrics()
    func reset() { metrics.reset() }
    func record(at now: Double) {
        guard let sample = metrics.record(at: now) else { return }
        writeDebugLog(String(format: "[SweetLyrics] periodic render ticks %.1f/s; longest gap %.3fs", sample.ticksPerSecond, sample.longestGap))
    }
}
