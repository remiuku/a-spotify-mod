// Adapted from sppqq/sweet-lyrics-ios, revision 90c10d785d3187258b8cb6e3e63b790ff4900da5.
// Modified for EeveeSpotify; AGPL-3.0. See THIRD_PARTY_SWEET_LYRICS.md.
import Foundation
#if canImport(QuartzCore)
import QuartzCore
#else
import CoreFoundation
#endif

enum SweetElementState: Equatable {
    case notSung, active, sung

    init(_ time: Double, _ start: Double, _ end: Double) {
        if time < start { self = .notSung } else if time >= end { self = .sung } else { self = .active }
    }
}

@inline(__always) private func progress(_ time: Double, _ start: Double, _ end: Double) -> Double {
    if time <= start { return 0 }
    if time >= end { return 1 }
    return (time - start) / (end - start)
}

// MARK: - Visual output (what the views draw)

/// Transform + paint of one glyph run (a syllable, a letter or a dot).
struct SweetGlyphVisual: Equatable {
    var scale: Double = 1
    /// Vertical offset as a fraction of the font size.
    var yOffset: Double = 0
    /// 0…1+ glow strength, mapped to a shadow per element kind.
    var glow: Double = 0
    /// Left edge of the fill gradient as a fraction of the glyph width (-0.2 = unlit, 1 = lit).
    var gradient: Double = -0.2
    var opacity: Double = 1
}

struct SweetSyllableVisual: Equatable {
    var glyph = SweetGlyphVisual()
    /// Per-letter visuals for emphasized syllables, empty otherwise.
    var letters: [SweetGlyphVisual] = []
}

struct SweetLineVisual: Equatable {
    var state: SweetElementState = .notSung
    var opacity: Double = 0.51
    var blur: Double = 0
    /// Whole-line scale (line-synced lines grow to 1.05 while active).
    var scale: Double = 1
    /// Syllable-synced lines: `[word][syllable]`.
    var lead: [[SweetSyllableVisual]] = []
    var background: [[SweetSyllableVisual]] = []
    /// Line-synced lines.
    var line = SweetGlyphVisual()
    /// Interlude dots. An interlude row only takes up space while active (`presence` 0/1);
    /// its dot group pops in and out with `dotGroupScale`.
    var dots: [SweetGlyphVisual] = []
    var presence: Double = 1
    var dotGroupScale: Double = 0
}

// MARK: - Animation curves (values from Spicy Lyrics' SweetLyricsAnimator.ts)

private enum SweetCurves {
    static let scale = SweetCubicSpline([(0, 0.95), (0.7, 1.0505), (1, 1)])
    static let yOffset = SweetCubicSpline([(0, 1.0 / 100), (0.9, -(1.0 / 60)), (1, 0)])
    static let glow = SweetCubicSpline([(0, 0), (0.15, 1), (0.6, 1), (1, 0)])
    static let letterScale = SweetCubicSpline([(0, 0.95), (0.7, 1.175), (1, 1)])
    static let letterYOffset = SweetCubicSpline([(0, 1.0 / 100), (0.9, -(1.0 / 56)), (1, 0)])
    static let lineGlow = SweetCubicSpline([(0, 0), (0.5, 1), (1, 0)])

    static let dotScale = SweetCubicSpline([(0, 0.75), (0.7, 1.05), (1, 1)])
    static let dotYOffset = SweetCubicSpline([(0, 0), (0.9, -0.12), (1, 0)])
    static let dotGlow = SweetCubicSpline([(0, 0), (0.6, 1), (1, 1)])
    static let dotOpacity = SweetCubicSpline([(0, 0.35), (0.6, 1), (1, 1)])

    static let sungLetterGlow = glow.at(0.2)

    // Simple Lyrics Mode (`$simpleLyricsMode`): words only drift up, letters get milder curves
    // scaled by `SimpleLyricsMode_LetterEffectsStrengthConfig`, dots only fade.
    static let simpleYOffset = SweetCubicSpline([(0, 1.0 / 100), (1, -0.033)])
    static let simpleLetterScale = SweetCubicSpline([(0, 0.95), (0.7, 1.07), (1, 1)])
    static let simpleLetterYOffset = SweetCubicSpline([(0, 1.0 / 100), (0.9, -(1.0 / 62)), (1, 0)])
    static let simpleDotOpacity = SweetCubicSpline([(0, 0.27), (0.6, 1), (1, 1)])
    /// `Animate()` runs Simple Lyrics Mode 33.5 ms behind.
    static let simplePositionOffset = -0.0335
    static let simpleLongerThan = 1.5
    static let simpleLonger = (glow: 0.4, yOffset: 0.45, scale: 1.103)
    static let simpleShorter = (glow: 0.285, yOffset: 0.1, scale: 1.09)

    // SweetSpring tuning.
    static let yOffsetFrequency = 1.45, yOffsetDamping = 0.4
    static let scaleFrequency = 0.88, scaleDamping = 0.64
    static let glowFrequency = 1.18, glowDamping = 0.56

    // Line states (Mixed.css).
    static let notSungOpacity = 0.51
    static let activeOpacity = 1.0
    static let sungOpacity = 0.497
    /// `.line.Active + .line.Sung` (a line overlapped by the active one) when line blur is on.
    static let sungAfterActiveOpacity = 0.45
    static let blurMultiplier = 1.25
    static var maxBlur: Double { blurMultiplier * 5 + blurMultiplier * 0.465 }

    // CSS transitions (Mixed.css).
    /// `.line { transition: opacity 0.2s cubic-bezier(0.61, 1, 0.88, 1) }`
    static let lineOpacity = (duration: 0.2, easing: SweetEasing.cubicBezier(0.61, 1, 0.88, 1))
    /// Line-synced `.line { transition: scale/opacity 0.2s cubic-bezier(0.37, 0, 0.63, 1) }`
    static let lineSynced = (duration: 0.2, easing: SweetEasing.cubicBezier(0.37, 0, 0.63, 1))
    static let activeLineSyncedScale = 1.05
    /// `.musical-line { transition: opacity 0.14s }`
    static let interludeOpacity = (duration: 0.14, easing: SweetEasing.ease)
    /// `.dotGroup { transition: scale 0.3s }`
    static let dotsIn = (duration: 0.3, easing: SweetEasing.ease)
    /// `.musical-line:is(.pre-hidden, :not(.Active)) .dotGroup`: a small wind-up, then gone.
    static let dotsOut = (duration: 0.4, easing: SweetEasing.linearPoints([
        (0, 0), (0.094, -0.006), (0.18, -0.029), (0.433, -0.157), (0.514, -0.185), (0.559, -0.189),
        (0.60, -0.182), (0.639, -0.163), (0.676, -0.133), (0.723, -0.074), (0.767, 0.006),
        (0.85, 0.238), (0.927, 0.566), (1, 1),
    ]))
    /// The dots start hiding this long before the interlude ends (`preHiddenDotLineMs`).
    static let preHiddenDots = 0.5
}

// MARK: - SweetSpring bundles

private struct SweetGlyphSprings {
    var scale: SweetSpring
    var yOffset: SweetSpring
    var glow: SweetSpring

    init(scale: Double, yOffset: Double, glow: Double,
         scaleFrequency: Double = SweetCurves.scaleFrequency, scaleDamping: Double = SweetCurves.scaleDamping,
         yFrequency: Double = SweetCurves.yOffsetFrequency, yDamping: Double = SweetCurves.yOffsetDamping,
         glowFrequency: Double = SweetCurves.glowFrequency, glowDamping: Double = SweetCurves.glowDamping) {
        self.scale = SweetSpring(scale, frequency: scaleFrequency, damping: scaleDamping)
        self.yOffset = SweetSpring(yOffset, frequency: yFrequency, damping: yDamping)
        self.glow = SweetSpring(glow, frequency: glowFrequency, damping: glowDamping)
    }

    mutating func step(scale s: Double, yOffset y: Double, glow g: Double, dt: Double) -> (Double, Double, Double) {
        scale.setGoal(s)
        yOffset.setGoal(y)
        glow.setGoal(g)
        return (scale.step(dt), yOffset.step(dt), glow.step(dt))
    }

    var isSettled: Bool { scale.canSleep && yOffset.canSleep && glow.canSleep }
}

private struct SweetSyllableSprings {
    var glyph: SweetGlyphSprings
    var letters: [SweetGlyphSprings]
}

private struct SweetDotSprings {
    var glyph: SweetGlyphSprings
    var opacity: SweetSpring
}

/// Scale that eases in with one curve and out with another (the interlude's dot group).
private struct SweetInOutTween {
    private var tween = SweetTween(0, duration: SweetCurves.dotsOut.duration, easing: SweetCurves.dotsOut.easing)
    private var showing = false

    mutating func update(show: Bool, now: Double, snap: Bool) -> Double {
        if show != showing {
            showing = show
            let spec = show ? SweetCurves.dotsIn : SweetCurves.dotsOut
            tween = SweetTween(tween.value, duration: spec.duration, easing: spec.easing)
        }
        return tween.update(to: show ? 1 : 0, now: now, snap: snap)
    }

    var isSettled: Bool { tween.isSettled }
}

private struct SweetLineSprings {
    var opacity: SweetTween
    var scale: SweetTween
    var glow: SweetSpring
    var dotGroup = SweetInOutTween()
    var lead: [[SweetSyllableSprings]]
    var background: [[SweetSyllableSprings]]
    var dots: [SweetDotSprings]
    /// False once a line is off-stage and every spring has come to rest: it is skipped until
    /// its state changes again. Most of a song is asleep at any moment.
    var awake = true
    var lastState: SweetElementState?
}

// MARK: - Animator

/// Per-frame state machine for the lyrics. Not observable on purpose: the lyrics view's
/// `TimelineView` drives it once per frame and reads the resulting `visuals`.
final class SweetLyricsAnimator {
    let lyrics: SweetPreparedLyrics
    /// Simple Lyrics Mode.
    let simple: Bool
    private(set) var visuals: [SweetLineVisual]
    /// The line the view should keep in focus (scroll target and blur origin).
    private(set) var focusIndex: Int = 0

    private var springs: [SweetLineSprings]
    private var lastFrame: CFTimeInterval?
    private var lastPosition: Double?
    /// The last step jumped to the clock instead of animating (a seek, a resume, `snapNext()`).
    private(set) var snapped = true
    /// Smoothed time between frames actually drawn.
    private var frameTime: Double?
    private var expectedFrameTime: Double?
    /// Seconds the lyrics run ahead of the clock while frames come slower than asked for.
    private(set) var presentationLead: Double = 0

    /// A frame computed at `now` reaches the screen about one frame time later and stays there
    /// for another frame time. At the requested rate that delay is what the sync was set up with;
    /// when frames drop (a hot phone, a busy main thread) it grows, and the words fall behind
    /// the sound. Run ahead by the extra so they stay on time.
    private func updateLead(dt: Double, expected: Double?) {
        guard let expected, dt > 0.006, dt < 0.4 else { return }
        // A new rate (paused at 15 fps, playing again at 60): start from it, not from the old one.
        if expected != expectedFrameTime {
            expectedFrameTime = expected
            frameTime = expected
            presentationLead = 0
            return
        }
        let smoothed = frameTime.map { $0 + (dt - $0) * (dt > $0 ? 0.3 : 0.08) } ?? dt
        frameTime = smoothed
        presentationLead = Sweetclamp(1.5 * (smoothed - expected * 1.1), 0, 0.15)
    }

    /// The next step jumps straight to the clock (it was just checked and may have moved).
    func snapNext() { lastPosition = nil }

    init(lyrics: SweetPreparedLyrics, simple: Bool = false) {
        self.lyrics = lyrics
        self.simple = simple
        springs = lyrics.lines.map(Self.makeSprings)
        visuals = lyrics.lines.map(Self.makeVisual)
    }

    /// Advances every spring to `position` (seconds). Safe to call more than once per frame.
    /// `frameInterval` is the frame time the caller asked for: frames coming slower than that
    /// move the lyrics ahead by the extra delay before they are seen (nil: no compensation).
    func step(position: Double, now: CFTimeInterval, blurEnabled: Bool, frameInterval: Double? = nil, isPlaying: Bool = true) {
        var dt = lastFrame.map { now - $0 } ?? (1.0 / 60)
        if dt <= 0 { return }
        if isPlaying { updateLead(dt: dt, expected: frameInterval) }
        else {
            // A paused clock has no presentation latency to compensate. Let
            // springs settle at the held position without leading into new words.
            presentationLead = 0; frameTime = nil; expectedFrameTime = nil
        }
        let position = position + presentationLead + (simple ? SweetCurves.simplePositionOffset : 0)
        // No frames for a while (the app or the floating window was hidden, the phone stalled):
        // whatever the springs were doing is stale, so snap like after a seek.
        let resumed = dt > 0.4
        // The springs are solved exactly for any step, so a slow frame takes its whole length:
        // capping it (it used to stop at 1/15 s) made them lag further behind the lower the fps.
        dt = min(dt, 0.25)
        // A seek: snap everything instead of animating across the whole song.
        let jumped = resumed || lastPosition.map { abs(position - $0) > 1.5 } ?? true
        lastFrame = now
        lastPosition = position
        snapped = jumped

        if lyrics.kind == .static {
            guard jumped else { return }
            for index in visuals.indices {
                visuals[index].state = .active
                visuals[index].opacity = 1
                visuals[index].blur = 0
                visuals[index].line.gradient = 1
            }
            return
        }

        focusIndex = Self.focus(in: lyrics.lines, at: position)
        var previousActive = false

        for index in lyrics.lines.indices {
            let line = lyrics.lines[index]
            var lineSprings = springs[index]
            let state = SweetElementState(position, line.start, line.end)
            if lineSprings.lastState != state || jumped { lineSprings.awake = true }
            lineSprings.lastState = state

            // Line level: opacity (a CSS transition) and the distance blur (set directly).
            var targetOpacity: Double
            switch state {
            case .notSung: targetOpacity = SweetCurves.notSungOpacity
            case .active: targetOpacity = SweetCurves.activeOpacity
            case .sung: targetOpacity = SweetCurves.sungOpacity
            }
            if state == .sung, previousActive, blurEnabled, !line.isInterlude {
                targetOpacity = SweetCurves.sungAfterActiveOpacity
            }
            if !line.isInterlude { previousActive = state == .active }

            let distance = abs(index - focusIndex)
            let blur = (!blurEnabled || state == .active || distance == 0)
                ? 0 : min(SweetCurves.blurMultiplier * Double(distance), SweetCurves.maxBlur)

            var visual = visuals[index]
            visual.state = state
            visual.blur = blur

            switch line.kind {
            case .syllable(let lead, let background):
                visual.opacity = lineSprings.opacity.update(to: targetOpacity, now: now, snap: jumped)
                if lineSprings.awake {
                    let settledLead = stepWords(lead, springs: &lineSprings.lead, into: &visual.lead,
                                                time: position, dt: dt, snap: jumped)
                    let settledBackground = stepWords(background, springs: &lineSprings.background,
                                                      into: &visual.background, time: position, dt: dt, snap: jumped)
                    if state != .active, settledLead, settledBackground { lineSprings.awake = false }
                }

            case .line:
                visual.opacity = lineSprings.opacity.update(to: targetOpacity, now: now, snap: jumped)
                visual.scale = lineSprings.scale.update(
                    to: state == .active ? SweetCurves.activeLineSyncedScale : 1, now: now, snap: jumped)
                if lineSprings.awake {
                    let p = progress(position, line.start, line.end)
                    let targetGlow: Double
                    switch state {
                    case .active:
                        targetGlow = SweetCurves.lineGlow.at(p)
                        visual.line.gradient = p
                    case .notSung:
                        targetGlow = SweetCurves.lineGlow.at(0)
                        visual.line.gradient = -0.2
                    case .sung:
                        targetGlow = SweetCurves.lineGlow.at(1)
                        visual.line.gradient = 1
                    }
                    lineSprings.glow.setGoal(simple ? 0 : targetGlow, replacePosition: jumped)
                    visual.line.glow = lineSprings.glow.step(dt)
                    if state != .active, lineSprings.glow.canSleep { lineSprings.awake = false }
                }

            case .interlude(let dots):
                // Only takes up space while active; fades in and out over 0.14s.
                visual.presence = state == .active ? 1 : 0
                visual.opacity = lineSprings.opacity.update(to: state == .active ? 1 : 0, now: now, snap: jumped)
                let preHidden = position > line.end - SweetCurves.preHiddenDots
                visual.dotGroupScale = lineSprings.dotGroup.update(
                    show: state == .active && !preHidden, now: now, snap: jumped)
                if lineSprings.awake {
                    var settled = lineSprings.dotGroup.isSettled
                    for (k, dot) in dots.enumerated() {
                        let p: Double
                        switch SweetElementState(position, dot.start, dot.end) {
                        case .notSung: p = 0
                        case .active: p = progress(position, dot.start, dot.end)
                        case .sung: p = 1
                        }
                        var s = lineSprings.dots[k]
                        if simple {
                            // Simple mode: the dots only fade in.
                            let opacityTarget = SweetCurves.simpleDotOpacity.at(p)
                            s.opacity.setGoal(opacityTarget, replacePosition: jumped)
                            let opacity = s.opacity.step(dt)
                            settled = settled && s.opacity.canSleep
                            lineSprings.dots[k] = s
                            visual.dots[k] = SweetGlyphVisual(scale: 1, yOffset: 0, glow: 0, gradient: 1, opacity: opacity)
                            continue
                        }
                        if jumped {
                            s.glyph.scale.setGoal(SweetCurves.dotScale.at(p), replacePosition: true)
                            s.glyph.yOffset.setGoal(SweetCurves.dotYOffset.at(p), replacePosition: true)
                            s.glyph.glow.setGoal(SweetCurves.dotGlow.at(p), replacePosition: true)
                            s.opacity.setGoal(SweetCurves.dotOpacity.at(p), replacePosition: true)
                        }
                        let (scale, y, glow) = s.glyph.step(
                            scale: SweetCurves.dotScale.at(p), yOffset: SweetCurves.dotYOffset.at(p), glow: SweetCurves.dotGlow.at(p), dt: dt)
                        s.opacity.setGoal(SweetCurves.dotOpacity.at(p))
                        let opacity = s.opacity.step(dt)
                        settled = settled && s.glyph.isSettled && s.opacity.canSleep
                        lineSprings.dots[k] = s
                        visual.dots[k] = SweetGlyphVisual(scale: scale, yOffset: y, glow: glow, gradient: 1, opacity: opacity)
                    }
                    if state != .active, settled { lineSprings.awake = false }
                }

            case .static:
                break
            }

            springs[index] = lineSprings
            if visuals[index] != visual { visuals[index] = visual }
        }
    }

    /// Lines starting this close together are sung together (a duet); the first one keeps focus.
    private static let duetWindow: Double = 0.6

    /// The last line that has started (so the view stays on a line through short gaps).
    private static func focus(in lines: [SweetPreparedLine], at time: Double) -> Int {
        guard !lines.isEmpty else { return 0 }
        // Presentation order keeps backing groups under their lead, even if they start earlier.
        // Such rows are not sorted by start time, so a binary search can select the wrong lead.
        var found = 0
        for (index, line) in lines.enumerated() where line.start <= time {
            if line.isBackground {
                if time < line.end, let lead = line.leadID { found = max(found, lead) }
            } else { found = max(found, index) }
        }
        // Background rows never hold focus: they belong to their lead line (`ResolveToLeadIndex`).
        if lines[found].isBackground, let lead = lines[found].leadID { found = lead }
        // Prefer the first of several lines that start together (duets). Only lines that start
        // together count: a long earlier line that merely overlaps (a trailing backing vocal, a
        // word timed a bit early) must not hold focus while the next line is being sung.
        var index = found
        while index > 0 {
            var previousIndex = index - 1
            while previousIndex > 0 && lines[previousIndex].isBackground { previousIndex -= 1 }
            let previous = lines[previousIndex]
            guard !previous.isInterlude, !previous.isBackground,
                  lines[index].start - previous.start <= duetWindow,
                  SweetElementState(time, previous.start, previous.end) == .active
            else { break }
            index = previousIndex
        }
        return index
    }

    /// Steps every syllable of a word list; returns whether all of their springs are at rest.
    private func stepWords(_ words: [SweetPreparedWord], springs: inout [[SweetSyllableSprings]], into visuals: inout [[SweetSyllableVisual]],
                           time: Double, dt: Double, snap: Bool) -> Bool {
        var settled = true
        for w in words.indices {
            for s in words[w].syllables.indices {
                let syllable = words[w].syllables[s]
                var store = springs[w][s]
                var visual = visuals[w][s]
                if let letters = syllable.letters, let first = letters.first, let last = letters.last {
                    // A letter group lives on the emphasized range (`Emphasize` ends it 250 ms early),
                    // and the whole word rides the word springs while its letters ripple on top.
                    var group = syllable
                    group.start = first.start
                    group.end = last.end
                    stepSyllable(group, &store, &visual, time: time, dt: dt, snap: snap)
                    stepLetters(group, letters, &store, &visual, time: time, dt: dt, snap: snap)
                } else {
                    stepSyllable(syllable, &store, &visual, time: time, dt: dt, snap: snap)
                }
                settled = settled && store.glyph.isSettled && store.letters.allSatisfy(\.isSettled)
                springs[w][s] = store
                visuals[w][s] = visual
            }
        }
        return settled
    }

    private func stepSyllable(_ syllable: SweetPreparedSyllable, _ store: inout SweetSyllableSprings, _ visual: inout SweetSyllableVisual,
                              time: Double, dt: Double, snap: Bool) {
        let state = SweetElementState(time, syllable.start, syllable.end)
        if simple {
            // No scale or glow: the word drifts up while a wider, softer fill passes over it.
            let p: Double
            switch state {
            case .notSung: p = 0; visual.glyph.gradient = -0.5
            case .active: p = progress(time, syllable.start, syllable.end); visual.glyph.gradient = -0.5 + 1.2 * p
            case .sung: p = 1; visual.glyph.gradient = 1
            }
            store.glyph.yOffset.setGoal(SweetCurves.simpleYOffset.at(p), replacePosition: snap)
            visual.glyph.yOffset = store.glyph.yOffset.step(dt)
            visual.glyph.scale = 1
            visual.glyph.glow = 0
            return
        }
        let p: Double
        switch state {
        case .notSung:
            p = 0
            visual.glyph.gradient = -0.2
        case .active:
            p = progress(time, syllable.start, syllable.end)
            visual.glyph.gradient = -0.2 + 1.2 * p
        case .sung:
            p = 1
            visual.glyph.gradient = 1
        }
        let targets = (SweetCurves.scale.at(p), SweetCurves.yOffset.at(p), SweetCurves.glow.at(p))
        if snap {
            store.glyph.scale.setGoal(targets.0, replacePosition: true)
            store.glyph.yOffset.setGoal(targets.1, replacePosition: true)
            store.glyph.glow.setGoal(targets.2, replacePosition: true)
        }
        let (scale, y, glow) = store.glyph.step(scale: targets.0, yOffset: targets.1, glow: targets.2, dt: dt)
        visual.glyph.scale = scale
        visual.glyph.yOffset = y
        visual.glyph.glow = glow
    }

    private func stepLetters(_ syllable: SweetPreparedSyllable, _ letters: [SweetPreparedLetter], _ store: inout SweetSyllableSprings,
                             _ visual: inout SweetSyllableVisual, time: Double, dt: Double, snap: Bool) {
        let wordState = SweetElementState(time, syllable.start, syllable.end)

        var activeLetter = -1
        var activeProgress = 0.0
        if wordState == .active {
            for (i, letter) in letters.enumerated() where SweetElementState(time, letter.start, letter.end) == .active {
                activeLetter = i
                activeProgress = progress(time, letter.start, letter.end)
                break
            }
        }

        let scaleCurve = simple ? SweetCurves.simpleLetterScale : SweetCurves.letterScale
        let yCurve = simple ? SweetCurves.simpleLetterYOffset : SweetCurves.letterYOffset
        let strength = syllable.end - syllable.start > SweetCurves.simpleLongerThan ? SweetCurves.simpleLonger : SweetCurves.simpleShorter
        // Simple mode scales the letter curves and drives them by the whole word's progress.
        let wordProgress = progress(time, syllable.start, syllable.end)
        let restScale = scaleCurve.at(0)
        let restY = yCurve.at(0)
        let restGlow = SweetCurves.glow.at(0)
        let unlit = simple ? -0.5 : -0.2

        for k in letters.indices {
            let letter = letters[k]
            let letterState = SweetElementState(time, letter.start, letter.end)
            var targetScale = restScale, targetY = restY, targetGlow = restGlow
            let gradient: Double

            switch wordState {
            case .notSung:
                gradient = unlit
            case .sung:
                targetScale = scaleCurve.at(1)
                targetY = yCurve.at(1)
                targetGlow = SweetCurves.glow.at(1)
                gradient = 1
            case .active:
                if activeLetter >= 0 {
                    // Proximity falloff around the letter being sung.
                    let count = simple ? wordProgress : activeProgress
                    let baseScale = scaleCurve.at(count) * (simple ? strength.scale : 1)
                    let baseY = yCurve.at(count) * (simple ? strength.yOffset : 1)
                    let baseGlow = SweetCurves.glow.at(count) * (simple ? strength.glow : 1)
                    let d = Double(abs(k - activeLetter))
                    let falloff = max(0, 1 / (1 + pow(d, 2.8)))
                    let glowFalloff = max(0, 1 / (1 + d * 0.9))
                    targetScale = restScale + (baseScale - restScale) * falloff
                    targetY = restY + (baseY - restY) * falloff
                    targetGlow = restGlow + (baseGlow - restGlow) * glowFalloff
                }
                switch letterState {
                case .notSung:
                    if !simple {
                        targetScale = restScale
                        targetY = restY
                        targetGlow = restGlow
                    }
                    gradient = unlit
                case .sung:
                    if activeLetter == -1 { targetGlow = SweetCurves.sungLetterGlow }
                    gradient = 1
                case .active:
                    gradient = k == activeLetter ? unlit + 1.2 * SweeteaseSinOut(activeProgress) : unlit
                }
            }

            var springs = store.letters[k]
            if snap {
                springs.scale.setGoal(targetScale, replacePosition: true)
                springs.yOffset.setGoal(targetY, replacePosition: true)
                springs.glow.setGoal(targetGlow, replacePosition: true)
            }
            let (scale, y, glow) = springs.step(scale: targetScale, yOffset: targetY, glow: targetGlow, dt: dt)
            store.letters[k] = springs
            visual.letters[k] = SweetGlyphVisual(scale: scale, yOffset: y * 2, glow: glow, gradient: gradient, opacity: 1)
        }
    }

    // MARK: Construction

    private static func makeSprings(_ line: SweetPreparedLine) -> SweetLineSprings {
        func syllableSprings(_ words: [SweetPreparedWord]) -> [[SweetSyllableSprings]] {
            words.map { word in
                word.syllables.map { syllable in
                    SweetSyllableSprings(
                        glyph: SweetGlyphSprings(scale: SweetCurves.scale.at(0), yOffset: SweetCurves.yOffset.at(0), glow: SweetCurves.glow.at(0)),
                        letters: (syllable.letters ?? []).map { _ in
                            SweetGlyphSprings(scale: SweetCurves.letterScale.at(0), yOffset: SweetCurves.letterYOffset.at(0), glow: SweetCurves.glow.at(0))
                        }
                    )
                }
            }
        }

        var lead: [[SweetSyllableSprings]] = []
        var background: [[SweetSyllableSprings]] = []
        var dots: [SweetDotSprings] = []
        switch line.kind {
        case .syllable(let l, let b):
            lead = syllableSprings(l)
            background = syllableSprings(b)
        case .interlude(let d):
            dots = d.map { _ in
                SweetDotSprings(
                    glyph: SweetGlyphSprings(scale: SweetCurves.dotScale.at(0), yOffset: SweetCurves.dotYOffset.at(0), glow: SweetCurves.dotGlow.at(0),
                                        scaleFrequency: 0.7, scaleDamping: 0.6, yFrequency: 1.25, yDamping: 0.4,
                                        glowFrequency: 1, glowDamping: 0.5),
                    opacity: SweetSpring(SweetCurves.dotOpacity.at(0), frequency: 1, damping: 0.5)
                )
            }
        default:
            break
        }
        let opacity: SweetTween
        switch line.kind {
        case .interlude:
            opacity = SweetTween(0, duration: SweetCurves.interludeOpacity.duration, easing: SweetCurves.interludeOpacity.easing)
        case .line:
            opacity = SweetTween(SweetCurves.notSungOpacity, duration: SweetCurves.lineSynced.duration, easing: SweetCurves.lineSynced.easing)
        default:
            opacity = SweetTween(SweetCurves.notSungOpacity, duration: SweetCurves.lineOpacity.duration, easing: SweetCurves.lineOpacity.easing)
        }
        return SweetLineSprings(
            opacity: opacity,
            scale: SweetTween(1, duration: SweetCurves.lineSynced.duration, easing: SweetCurves.lineSynced.easing),
            glow: SweetSpring(0, frequency: 1, damping: 0.5),
            lead: lead,
            background: background,
            dots: dots
        )
    }

    private static func makeVisual(_ line: SweetPreparedLine) -> SweetLineVisual {
        var visual = SweetLineVisual()
        func syllableVisuals(_ words: [SweetPreparedWord]) -> [[SweetSyllableVisual]] {
            words.map { word in
                word.syllables.map { syllable in
                    let rest = SweetGlyphVisual(scale: SweetCurves.scale.at(0), yOffset: SweetCurves.yOffset.at(0), glow: 0, gradient: -0.2)
                    let letterRest = SweetGlyphVisual(scale: SweetCurves.letterScale.at(0), yOffset: SweetCurves.letterYOffset.at(0) * 2, glow: 0, gradient: -0.2)
                    return SweetSyllableVisual(glyph: rest, letters: (syllable.letters ?? []).map { _ in letterRest })
                }
            }
        }
        switch line.kind {
        case .syllable(let lead, let background):
            visual.lead = syllableVisuals(lead)
            visual.background = syllableVisuals(background)
        case .interlude(let dots):
            visual.dots = dots.map { _ in SweetGlyphVisual(scale: SweetCurves.dotScale.at(0), yOffset: 0, glow: 0, gradient: 1, opacity: SweetCurves.dotOpacity.at(0)) }
            visual.presence = 0
            visual.opacity = 0
        case .static:
            visual.opacity = 1
            visual.line.gradient = 1
        case .line:
            break
        }
        return visual
    }
}
