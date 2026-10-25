import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) { precondition(condition(), message) }
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
let defaults = UserDefaults(suiteName: "asm.dancer.tests")!
let legacy = try JSONDecoder().decode(ASMDancerOptions.self, from: Data("{\"enabled\":true,\"animation\":\"bounce\",\"manualBPM\":90}".utf8))
check(legacy.enabled && legacy.animation == .bounce && legacy.manualBPM == 90 && legacy.tempoScale == .normal,
      "Adding half/double time preserves previously saved dancer settings")
let half = ASMDancerTiming.phase(positionMs: 250, loopSeconds: 0.5, bpm: 120, beats: 1, offsetBeats: 0, tempoScale: 0.5)
let double = ASMDancerTiming.phase(positionMs: 250, loopSeconds: 0.5, bpm: 120, beats: 1, offsetBeats: 0, tempoScale: 2)
check(near(half, 0.25) && near(double, 0), "Half and double time scale tempo independently of audio speed")
check(near(ASMDancerTiming.phase(positionMs: 50, loopSeconds: 0.5, bpm: 300, beats: 1, offsetBeats: 0, tempoScale: 2), 0.5),
      "Double-time remains valid above the original BPM input limit")
defaults.removePersistentDomain(forName: "asm.dancer.tests")
defer { defaults.removePersistentDomain(forName: "asm.dancer.tests") }
var options = ASMDancerOptions.load(from: defaults)
check(!options.enabled && options.animation == .dance, "Dancer is opt-in and separate from global boykisser mode")
options.enabled = true; options.beatCounts["dance"] = 4; options.manualBPM = 96
options.save(to: defaults)
check(ASMDancerOptions.load(from: defaults) == options && defaults.bool(forKey: ASMDancerOptions.enabledKey), "Selection and decoder gate persist together")
options.animation = .tiny
check(options.beats == 1, "Each animation retains its own beat calibration")
options.beatCounts["tiny"] = .nan
check(options.beats == 1, "Invalid calibration cannot poison playback phase")
check(ASMDancerTempo.read(["tempo": "nan", "bpm": "infinity"]) == nil, "Reject non-finite tempo")
check(ASMDancerTempo.read(["bpm": "0", "tempo": "900"]) == nil, "Reject invalid/out-of-range tempo")
check(ASMDancerTempo.read(["bpm": "120", "automix.fade_in_cuepoint.tempo": "90"])?.bpm == 120, "Track tempo wins over a cue tempo")
let cue = ASMDancerTempo.read(["automix.fade_in_cuepoint.tempo": " 128.5 "])
check(cue?.bpm == 128.5 && cue?.source == "Spotify mix cue", "Mix cue provenance is explicit")
check(ASMDancerTempo.read([:]) == nil, "Missing Spotify metadata remains unavailable, not a guessed song tempo")
func phase(_ ms: Int, bpm: Double? = 120, beats: Double = 1, offset: Double = 0) -> Double {
    ASMDancerTiming.phase(positionMs: ms, loopSeconds: 4.16, bpm: bpm, beats: beats, offsetBeats: offset)
}
check(near(phase(250), 0.5) && near(phase(500), 0), "One animation cycle per beat at 120 BPM")
check(near(phase(2000, beats: 8), 0.5) && near(phase(4000, beats: 8), 0), "Multi-beat dance loops stay calibrated")
check(near(phase(2080, bpm: nil), 0.5), "Original speed uses measured frame duration")
check(near(phase(0, offset: -0.25), 0.75), "Negative alignment offsets wrap correctly")
check(phase(-400) == 0 && ASMDancerTiming.phase(positionMs: 1, loopSeconds: 0, bpm: 120, beats: 1, offsetBeats: 0) == 0,
      "Malformed clocks/loops are safe")
let ends = [0.02, 0.10, 0.20]
let closing = ASMDancerLoopPolicy.closingPose(animation: .dance, sourceHash: ASMDancerLoopPolicy.sourceHash, frameCount: 52)
check(closing == 44, "Close the final back-facing pose with the existing opposite-facing side pose")
let completedSequence = Array(0..<52) + [closing!]
check(Array(completedSequence.prefix(52)) == Array(0..<52) && completedSequence.count == 53,
      "Every source frame remains in order; only the return-side pose is appended")
check(Array(completedSequence.suffix(4)) == [49, 50, 51, 44], "Final turn follows front, side, back, opposite side, then wraps to front")
var completedEnds: [Double] = [], end = 0.0
for _ in completedSequence { end += 0.08; completedEnds.append(end) }
check(near(end, 4.24) && near(ASMDancerAnimation.dance.playbackSeconds!, end), "Actual playback and displayed cadence include the closing pose")
check(near(ASMDancerAnimation.dance.measuredSeconds!, 4.16), "Original source timing remains accurately labelled in provenance")
check(ASMDancerTiming.frame(phase: 4.20 / end, ends: completedEnds) == 52,
      "The closing pose gets a full visible frame interval")
check(ASMDancerTiming.frame(phase: 0, ends: completedEnds) == 0, "The next loop returns to the source's first frame")
check(ASMDancerLoopPolicy.closingPose(animation: .tiny, sourceHash: ASMDancerLoopPolicy.sourceHash, frameCount: 52) == nil &&
      ASMDancerLoopPolicy.closingPose(animation: .dance, sourceHash: "different clip", frameCount: 52) == nil &&
      ASMDancerLoopPolicy.closingPose(animation: .dance, sourceHash: ASMDancerLoopPolicy.sourceHash, frameCount: 51) == nil,
      "Never append an arbitrary pose to another animation or a changed source")
check(near(ASMDancerAnimation.tiny.playbackSeconds!, 0.5), "Other animations keep their existing playback timing")
check(ASMDancerTiming.frame(phase: 0.05, ends: ends) == 0 && ASMDancerTiming.frame(phase: 0.1, ends: ends) == 1,
      "Honor variable delay boundaries")
check(ASMDancerTiming.frame(phase: 0.99, ends: ends) == 2 && ASMDancerTiming.frame(phase: .nan, ends: ends) == 0,
      "Final frame and non-finite phase stay in bounds")
var clock = ASMPlaybackClock()
clock.receive(position: 1.1, reportedSpeed: 1, audioRate: 1, playing: true, now: 10)
clock.receive(position: clock.position(at: 10.1), reportedSpeed: 1, audioRate: 1, playing: false, now: 10.1)
let frozen = phase(Int(clock.position(at: 10.1) * 1000))
check(near(frozen, phase(Int(clock.position(at: 40) * 1000))), "Paused playback freezes dancer phase indefinitely")
clock.receive(position: 0.1, reportedSpeed: 1, audioRate: 1, playing: false, now: 40)
check(near(phase(Int(clock.position(at: 50) * 1000)), 0.2), "Paused seeks deterministically select the new animation frame")
clock.receive(position: 0, reportedSpeed: 1, audioRate: 1, playing: true, now: 50)
clock.changeAudioRate(2, at: 50.1)
check(near(phase(Int((clock.position(at: 50.2) * 1000).rounded())), 0.6), "Speed changes enter through the shared clock once")
let sprites = ASMDancerSpritePolicy.placements(bounds: [CGRect(x: 11, y: 327, width: 22, height: 24),
    CGRect(x: 14, y: 11, width: 22, height: 24), CGRect(x: 11, y: 285, width: 22, height: 24)])
check(sprites.count == 3 && sprites[0].midY > sprites[1].midY && sprites[2].midY > sprites[1].midY,
      "Tall canvas keeps the original bounce direction and phase")
check(sprites.allSatisfy { $0.minX >= 0 && $0.maxX <= 1 && $0.minY >= 0 && $0.maxY <= 1 && near(Double($0.height), 0.5) },
      "Tall-canvas sprite remains readable at one consistent scale and fits the overlay")
print("PASS dancer: safe opt-in persistence, real tempo validation/provenance, loop calibration, variable frame timing, pause/seek/rate")
