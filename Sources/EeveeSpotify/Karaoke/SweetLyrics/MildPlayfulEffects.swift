import Foundation

// Adapted from Mild's spin_frag/float_of, Amll.emph_of and LyricsView.step_drift.
// AGPL-3.0; see THIRD_PARTY_MILD_LYRICS.md. Playback effects use song seconds.
struct MildPlayfulConfiguration: Equatable {
    var spin = 0.0, floatAway = 0.0, zeroGravity = 0.0, jelly = 0.0
    var pop = 1.0, rise = 1.0, linger = 0.0, minimumPop = 0.0
    var enabled: Bool { spin > 0 || floatAway > 0 || zeroGravity > 0 || jelly > 0 }
    init() {}
    init(options: MildLyricsOptions, reduceMotion: Bool) {
        guard options.flag("enabled"), !reduceMotion else { return }
        spin = options.number("spin"); floatAway = options.number("float_up")
        zeroGravity = options.number("zero_g"); jelly = options.number("jelly")
        pop = options.number("pop"); rise = options.number("rise")
        linger = options.number("pop_linger"); minimumPop = options.number("pop_min")
    }
}

struct MildPlayfulContext: Equatable {
    var configuration = MildPlayfulConfiguration()
    var position = 0.0
}

enum MildPlayfulEffects {
    struct Flight: Equatable {
        var lift = 0.0, opacity = 1.0, scale = 1.0
    }
    static func spin(start: Double, end: Double, position: Double, turns: Double) -> Double {
        guard turns > 0, end > start, position >= start, position < end else { return 0 }
        return 360 * turns * (position - start) / (end - start)
    }
    static func flight(start: Double, position: Double, speed: Double, fontHeight: Double) -> Flight {
        guard speed > 0, position > start else { return Flight() }
        let t = min(1, (position - start) * max(0.25, speed)), eased = pow(t, 1.6)
        return Flight(lift: fontHeight * 9 * eased, opacity: 1 - t * t * (3 - 2 * t), scale: 1 + 1.5 * eased)
    }
    static func dotDeparture(start: Double, end: Double, index: Int, speed: Double) -> Double {
        max(start, end - (1 / max(0.25, speed)) * (1 + Double(2 - index) * 0.34))
    }
    static func span(_ word: SweetPreparedWord) -> (start: Double, end: Double) {
        (word.syllables.map(\.start).min() ?? 0, word.syllables.map(\.end).max() ?? 0)
    }
    static func held(_ text: String, duration: Double, threshold: Double) -> Bool {
        guard !SweetTextDirection.isRightToLeft(text) else { return false }
        var n = 0.0
        for c in text.unicodeScalars {
            switch c.value {
            case 0x3040...0x30FF: n += "ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶー".unicodeScalars.contains(c) ? 1 : 2
            case 0x2E80...0x2FFF, 0x3400...0x9FFF: n += 3
            default: if CharacterSet.alphanumerics.contains(c) { n += 1 }
            }
        }
        return n > 1 && duration >= threshold * max(0.8, pow(n / 4.5, 0.6))
    }
    // Adds display-only letter timing paced by native glyph advances. Audio/source
    // timings are unchanged; Arabic joined scripts retain their original shaping.
    static func prepareJelly(_ original: SweetPreparedLyrics, configuration: MildPlayfulConfiguration,
                             advance: (String) -> Double) -> SweetPreparedLyrics {
        guard configuration.jelly > 0, configuration.zeroGravity == 0 else { return original }
        var result = original
        func prepare(_ words: [SweetPreparedWord]) -> [SweetPreparedWord] {
            words.map { source in
                let timing = span(source), text = source.syllables.map(\.text).joined()
                guard held(text, duration: timing.end - timing.start, threshold: 0.05) else { return source }
                var word = source
                word.syllables = source.syllables.map { syllable in
                    var value = syllable
                    let chars = syllable.text.map(String.init)
                    let widths = chars.map { max(0.001, advance($0)) }, total = widths.reduce(0, +)
                    var left = 0.0
                    value.letters = zip(chars, widths).map { char, width in
                        defer { left += width }
                        return SweetPreparedLetter(text: char, start: syllable.start + (syllable.end - syllable.start) * left / total,
                                                   end: syllable.start + (syllable.end - syllable.start) * (left + width) / total)
                    }
                    return value
                }
                return word
            }
        }
        result.lines = original.lines.map { line in
            var value = line
            if case .syllable(let lead, let bg) = line.kind { value.kind = .syllable(lead: prepare(lead), background: prepare(bg)) }
            return value
        }
        return result
    }

    private static let easeIn = SweetEasing.cubicBezier(0.2, 0.4, 0.58, 1)
    private static let easeOut = SweetEasing.cubicBezier(0.3, 0, 0.58, 1)
    static func emphasis(_ x: Double) -> Double {
        guard x > 0, x < 1 else { return 0 }
        return x < 0.5 ? easeIn.value(at: x * 2) : 1 - easeOut.value(at: (x - 0.5) * 2)
    }
    struct JellyLetter { var lift = 0.0, scale = 1.0 }
    static func jelly(word: SweetPreparedWord, letterIndex: Int, position: Double, lastWord: Bool,
                      configuration c: MildPlayfulConfiguration, fontHeight: Double) -> JellyLetter {
        let timing = span(word), duration = timing.end - timing.start
        let text = word.syllables.map(\.text).joined(), letters = word.syllables.flatMap { $0.letters ?? [] }
        guard c.jelly > 0, held(text, duration: duration, threshold: 0.05), letters.indices.contains(letterIndex) else { return JellyLetter() }
        let uniform = !held(text, duration: duration, threshold: c.minimumPop > 0 ? c.minimumPop : 1)
        var du = uniform ? 1 : max(1, duration)
        var amount = du / 2
        amount = (amount > 1 ? sqrt(amount) : pow(amount, 3)) * 0.6
        if lastWord { amount *= 1.6; du *= 1.2 }
        amount = min(1.2, amount) * c.pop
        let tail = min(0.6, max(0.3, 0.3 * duration))
        var end = duration + tail
        end += (max(end, 1.8 * du) - end) * c.linger
        let offsets = letters.map { max(0, $0.start - timing.start) }
        let i = letterIndex, offset = offsets[i]
        var lean = i == 0 ? 0 : min(0.6, max(0, offsets[i] - offsets[i - 1]))
        var length = max(0.15, min(du, (end - offset + 0.06) / 1.4))
        var floatLength = max(0.15, min(du, (end - offset + lean + 0.06) / 1.4))
        if letters.count > 1 && !uniform {
            let firstLength = max(0.15, min(du, (end - offsets[0] + 0.06) / 1.4))
            let firstFloat = firstLength
            let past = end + tail + 0.06
            length = max(length, min(du, firstLength, (past - offset) / 1.4))
            floatLength = max(floatLength, min(du, firstFloat, (past - offset + lean) / 1.4))
        }
        if uniform { lean = min(lean, 0.125); length = 0.5; floatLength = 0.5 + lean / 1.4 }
        let arrival = timing.start + offset
        let grow = emphasis(max(0, min(1, (position - arrival) / length)))
        let x = (position - (arrival - lean - 0.06)) / (floatLength * 1.4)
        let em = fontHeight * 0.83, swell = em * 0.05 * min(1, c.rise) * c.jelly
        let lift = x > 0 && x < 1 ? pow(sin(.pi * x), 2) * (swell + 0.025 * amount * em) : 0
        return JellyLetter(lift: lift, scale: 1 + grow * 0.1 * amount)
    }
}

// Positions are absolute inside the lyric viewport. Scrolling a source row must
// not drag an already loose word. Bodies outlive their source rows and retire
// with a timed fade; the scrolling view is only used to admit a finished word.
final class MildWordDrift {
    struct State {
        var x: Double, y: Double, vx: Double, vy: Double, angle: Double, angularVelocity: Double
    }
    struct Candidate { let key: String; let frame: CGRect; let end: Double }
    struct Body {
        let key: String
        var state: State
        let size: CGSize
        var age: Double = 0
        var opacity: Double { min(1, max(0, (8 - age) / 2)) }
    }
    static let maximumBodies = 96
    private var entries: [String: Body] = [:]
    private var previous: Double?
    private var previousPosition: Double?
    private(set) var revision = 0
    func reset() {
        entries.removeAll(); previous = nil; previousPosition = nil; revision += 1
    }
    static func hasFinished(start: Double, end: Double, position: Double) -> Bool {
        start.isFinite && end.isFinite && position.isFinite && end > start && position >= end
    }
    func update(candidates: [Candidate], viewport: CGSize, now: Double, position: Double,
                isPlaying: Bool, speed: Double) -> [Body] {
        guard now.isFinite, position.isFinite, viewport.width > 0, viewport.height > 0 else { return [] }
        let elapsed = previous.map { max(0, now - $0) } ?? 0
        let jumped = previousPosition.map { position < $0 - 0.05 || position - $0 > max(1, elapsed * 4 + 0.25) } ?? false
        if jumped { reset() }
        let dt = isPlaying && !jumped ? min(0.05, elapsed) : 0
        let ageDelta = isPlaying && !jumped ? min(0.25, elapsed) : 0
        previous = now; previousPosition = position
        for key in Array(entries.keys) {
            guard var body = entries[key] else { continue }
            body.age += ageDelta
            if body.age >= 8 { entries.removeValue(forKey: key); continue }
            body.state = Self.integrate(body.state, dt: dt, speed: speed.isFinite ? max(0, speed) : 0,
                                        width: viewport.width, height: viewport.height,
                                        wordWidth: body.size.width, wordHeight: body.size.height)
            entries[key] = body
        }
        let bounds = CGRect(origin: .zero, size: viewport)
        for candidate in candidates.sorted(by: { $0.end == $1.end ? $0.key < $1.key : $0.end < $1.end }) {
            // A short release window prevents a newly mounted old row or a
            // future row below the viewport from spawning at the bottom edge.
            guard entries[candidate.key] == nil, entries.count < Self.maximumBodies,
                  candidate.end.isFinite, position >= candidate.end, position - candidate.end <= 0.6,
                  candidate.frame.width > 0, candidate.frame.height > 0,
                  bounds.contains(CGPoint(x: candidate.frame.midX, y: candidate.frame.midY)) else { continue }
            let state = Self.seed(candidate.key, x: candidate.frame.minX, y: candidate.frame.minY)
            entries[candidate.key] = Body(key: candidate.key,
                state: Self.integrate(state, dt: 0, speed: 0, width: viewport.width, height: viewport.height,
                                      wordWidth: candidate.frame.width, wordHeight: candidate.frame.height),
                size: candidate.frame.size)
        }
        return entries.values.sorted { $0.key < $1.key }
    }
    static func seed(_ key: String, x: Double, y: Double) -> State {
        // Stable hash instead of Python's process-randomized hash; same motion
        // ranges, with reproducible headings after a row leaves and returns.
        var hash: UInt64 = 14695981039346656037
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        let angle = Double(hash % 6283) / 1000, speed = Double(18 + ((hash >> 13) % 46))
        return State(x: x, y: y, vx: cos(angle) * speed, vy: sin(angle) * speed,
                     angle: 0, angularVelocity: (Double((hash >> 7) % 61) - 30) / 1.4)
    }
    static func integrate(_ state: State, dt: Double, speed: Double, width: Double, height: Double,
                          wordWidth: Double, wordHeight: Double) -> State {
        var s = state
        s.x += s.vx * speed * dt; s.y += s.vy * speed * dt; s.angle += s.angularVelocity * speed * dt
        let maxX = max(0, width - wordWidth), maxY = max(0, height - wordHeight)
        if s.x < 0 { s.x = 0; s.vx = abs(s.vx) }
        else if s.x > maxX { s.x = maxX; s.vx = -abs(s.vx) }
        if s.y < 0 { s.y = 0; s.vy = abs(s.vy) }
        else if s.y > maxY { s.y = maxY; s.vy = -abs(s.vy) }
        return s
    }
}
