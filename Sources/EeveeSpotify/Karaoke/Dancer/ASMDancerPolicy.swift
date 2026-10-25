import Foundation

enum ASMDancerAnimation: String, Codable, CaseIterable, Identifiable {
    case dance, tiny, explosion, bounce
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dance: return "Side-to-side dance"
        case .tiny: return "Tiny bounce"
        case .explosion: return "Explosion"
        case .bounce: return "Bounce GIF"
        }
    }
    var filename: String {
        switch self {
        case .dance: return "dance-1.webp"
        case .tiny: return "dance-2.webp"
        case .explosion: return "dance-3.webp"
        case .bounce: return "bounce.gif"
        }
    }
    /// Loop timing comes from the original frame delays. Beat counts are a
    /// calibration, not embedded music metadata; the user can change them.
    var measuredSeconds: Double? {
        switch self {
        case .dance: return 4.16
        case .tiny: return 0.50
        case .explosion: return 0.24
        case .bounce: return 0.50
        }
    }
    var defaultBeats: Double { self == .dance ? 8 : 1 }
    var playbackSeconds: Double? {
        measuredSeconds.map { $0 + (self == .dance ? ASMDancerLoopPolicy.closingSeconds : 0) }
    }
}

enum ASMDancerLoopPolicy {
    static let sourceHash = "f0c48f0d0084ff22841817f4f1e2c54e592c6fbd1e167f9d98bc2130d6d6f2fd"
    static let closingSeconds = 0.08
    /// The supplied clip finishes front -> side -> back, omitting the opposite
    /// side before wrapping. Frame 44 is that existing pose from its first full
    /// turn. Reuse it only for this exact clip; retain all 52 original frames.
    static func closingPose(animation: ASMDancerAnimation, sourceHash: String?, frameCount: Int) -> Int? {
        guard animation == .dance, sourceHash == Self.sourceHash, frameCount == 52 else { return nil }
        return 44
    }
}

struct ASMDancerOptions: Codable, Equatable {
    var enabled = false
    var animation = ASMDancerAnimation.dance
    var sync = true
    var forceManual = false
    var manualBPM = 120.0
    var beatCounts: [String: Double] = [:]
    var offsetBeats = 0.0
    var tempoScale = ASMDancerTempoScale.normal
    var estimateBPM = true
    init() {}
    private enum CodingKeys: String, CodingKey { case enabled, animation, sync, forceManual, manualBPM, beatCounts, offsetBeats, tempoScale, estimateBPM }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        animation = (try? values.decode(ASMDancerAnimation.self, forKey: .animation)) ?? .dance
        sync = try values.decodeIfPresent(Bool.self, forKey: .sync) ?? true
        forceManual = try values.decodeIfPresent(Bool.self, forKey: .forceManual) ?? false
        manualBPM = try values.decodeIfPresent(Double.self, forKey: .manualBPM) ?? 120
        beatCounts = try values.decodeIfPresent([String: Double].self, forKey: .beatCounts) ?? [:]
        offsetBeats = try values.decodeIfPresent(Double.self, forKey: .offsetBeats) ?? 0
        tempoScale = (try? values.decode(ASMDancerTempoScale.self, forKey: .tempoScale)) ?? .normal
        estimateBPM = try values.decodeIfPresent(Bool.self, forKey: .estimateBPM) ?? true
    }
    static let key = "asm.lyrics.dancer.options"
    static let enabledKey = "asm.lyrics.dancer.enabled"
    var beats: Double {
        let value = beatCounts[animation.rawValue] ?? animation.defaultBeats
        return value.isFinite ? min(32, max(1, value)) : animation.defaultBeats
    }
    var fallbackBPM: Double { ASMDancerTempo.valid(manualBPM) ?? 120 }
    static func load(from store: UserDefaults = .standard) -> Self {
        store.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }
    func save(to store: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        store.set(data, forKey: Self.key)
        store.set(enabled, forKey: Self.enabledKey)
    }
}

enum ASMDancerTempoScale: String, Codable, CaseIterable {
    case half, normal, double
    var factor: Double { self == .half ? 0.5 : self == .double ? 2 : 1 }
    var title: String { self == .half ? "Half-time (×½)" : self == .double ? "Double-time (×2)" : "Normal (×1)" }
}

struct ASMDancerTempo: Equatable {
    let bpm: Double
    let source: String
    static func valid(_ bpm: Double) -> Double? { bpm.isFinite && (30...300).contains(bpm) ? bpm : nil }
    static func read(_ metadata: [String: String]) -> Self? {
        // metadata() and both automix cuepoint keys are present in Spotify
        // 9.1.88. Not all tracks carry tempo, and cue tempo is not a beat grid.
        for key in ["tempoBpm", "bpm", "tempo", "automix.fade_in_cuepoint.tempo", "automix.fade_out_cuepoint.tempo"] {
            guard let value = metadata[key], let number = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let bpm = valid(number) else { continue }
            return Self(bpm: bpm, source: key.hasPrefix("automix.") ? "Spotify mix cue" : "Spotify metadata")
        }
        return nil
    }
}

struct ASMDancerSnapshot {
    let positionMs: Int
    let isPlaying: Bool
    let trackId: String?
    let tempo: ASMDancerTempo?
}

enum ASMDancerTiming {
    static func phase(positionMs: Int, loopSeconds: Double, bpm: Double?, beats: Double, offsetBeats: Double, tempoScale: Double = 1) -> Double {
        guard loopSeconds.isFinite, loopSeconds > 0 else { return 0 }
        let seconds = Double(max(0, positionMs)) / 1000
        let count = beats.isFinite ? min(32, max(1, beats)) : 1
        let offset = offsetBeats.isFinite ? min(1, max(-1, offsetBeats)) / count : 0
        let factor = [0.5, 1, 2].contains(tempoScale) ? tempoScale : 1
        let cycles = bpm.flatMap(ASMDancerTempo.valid).map { seconds * $0 * factor / 60 / count }
            ?? (seconds / loopSeconds)
        let phase = (cycles + offset).truncatingRemainder(dividingBy: 1)
        return phase < 0 ? phase + 1 : phase
    }
    /// Preserve variable frame delays; do not distribute frames uniformly.
    static func frame(phase: Double, ends: [Double]) -> Int {
        guard phase.isFinite, let duration = ends.last, duration > 0 else { return 0 }
        let time = min(1.nextDown, max(0, phase)) * duration
        var low = 0, high = ends.count
        while low < high {
            let middle = (low + high) / 2
            if ends[middle] <= time { low = middle + 1 } else { high = middle }
        }
        return min(low, max(0, ends.count - 1))
    }
}

enum ASMDancerSpritePolicy {
    /// Fit tall transparent animation canvases into the small overlay without
    /// shrinking their character to a few pixels or stretching its artwork.
    /// Compress only the travel path; keep one pixel scale for every sprite.
    static func placements(bounds: [CGRect]) -> [CGRect] {
        guard !bounds.isEmpty else { return [] }
        let side = bounds.map { max($0.width, $0.height) }.max() ?? 0
        guard side.isFinite, side > 0 else { return bounds.map { _ in CGRect(x: 0, y: 0, width: 1, height: 1) } }
        let scale = 0.5 / side
        let minY = bounds.map(\.midY).min() ?? 0
        let maxY = bounds.map(\.midY).max() ?? 0
        let centerX = bounds.map(\.midX).reduce(0, +) / CGFloat(bounds.count)
        return bounds.map { box in
            let width = box.width * scale, height = box.height * scale
            let progress = maxY > minY ? (box.midY - minY) / (maxY - minY) : 0.5
            let centerY = 0.25 + progress * 0.5
            let x = min(1 - width, max(0, 0.5 + (box.midX - centerX) * scale - width / 2))
            return CGRect(x: x, y: centerY - height / 2, width: width, height: height)
        }
    }
}
