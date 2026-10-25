import Foundation

/// Bounded autocorrelation of local onset strength, not an API tempo claim or
/// a downbeat detector. Octave ambiguity is handled by half/double-time controls.
enum ASMTempoEstimator {
    struct Estimate { let bpm: Double; let confidence: Double }
    static func estimate(_ input: [Float], samplesPerSecond: Double = 100) -> Estimate? {
        guard samplesPerSecond.isFinite, samplesPerSecond >= 50, input.count >= Int(samplesPerSecond * 8) else { return nil }
        let values = input.suffix(1600).map { $0.isFinite ? max(0, Double($0)) : 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }
        let variance = centered.reduce(0) { $0 + $1 * $1 } / Double(values.count)
        guard variance > 0.000001 else { return nil }
        let threshold = mean + sqrt(variance) * 0.5
        var peaks = 0, last = -100
        for i in 1..<(values.count - 1) where values[i] > threshold && values[i] >= values[i - 1] && values[i] > values[i + 1] {
            if i - last >= Int(samplesPerSecond * 0.08) { peaks += 1; last = i }
        }
        guard peaks >= 6 else { return nil }
        let first = Int(floor(samplesPerSecond * 60 / 210)), end = Int(ceil(samplesPerSecond * 60 / 55))
        var correlation = [Double](repeating: 0, count: end + 2)
        for lag in (first - 1)...(end + 1) {
            var sum = 0.0, left = 0.0, right = 0.0
            for i in lag..<centered.count {
                sum += centered[i] * centered[i - lag]
                left += centered[i] * centered[i]; right += centered[i - lag] * centered[i - lag]
            }
            correlation[lag] = sum / max(1e-12, sqrt(left * right))
        }
        let candidates = (first...end).filter { correlation[$0] >= correlation[$0 - 1] && correlation[$0] > correlation[$0 + 1] }
        guard let best = candidates.map({ correlation[$0] }).max(), best >= 0.38,
              let lag = candidates.first(where: { correlation[$0] >= best - 0.035 }) else { return nil }
        let a = correlation[lag - 1], b = correlation[lag], c = correlation[lag + 1]
        let denominator = a - 2 * b + c
        let adjustment = abs(denominator) > 1e-10 ? min(0.5, max(-0.5, 0.5 * (a - c) / denominator)) : 0
        let bpm = 60 * samplesPerSecond / (Double(lag) + adjustment)
        guard bpm.isFinite, (55...210).contains(bpm) else { return nil }
        return Estimate(bpm: bpm, confidence: min(1, max(0, b)))
    }
}
