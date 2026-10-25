import Foundation
func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.00003 }
struct Fixtures: Decodable {
    struct Flight: Decodable { let speed: Double, position: Double, lift: Double, opacity: Double, scale: Double }
    struct Jelly: Decodable {
        struct Letter: Decodable { let lift: Double, scale: Double }
        let text: String, duration: Double, position: Double
        let last: Bool
        let letters: [Letter]
    }
    let floats: [Flight], jelly: [Jelly]
}
let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: URL(fileURLWithPath: "Tests/MildPlayful/fixtures.json")))
for fixture in fixtures.floats {
    let value = MildPlayfulEffects.flight(start: 2, position: fixture.position, speed: fixture.speed, fontHeight: 30)
    check(near(value.lift, fixture.lift) && near(value.opacity, fixture.opacity) && near(value.scale, fixture.scale), "Float diverges from pinned Mild: \(fixture)")
}
var config = MildPlayfulConfiguration(); config.jelly = 1
for fixture in fixtures.jelly {
    let count = Double(fixture.text.count)
    let letters = fixture.text.enumerated().map { i, c in
        SweetPreparedLetter(text: String(c), start: 1 + fixture.duration * Double(i) / count, end: 1 + fixture.duration * Double(i + 1) / count)
    }
    let word = SweetPreparedWord(syllables: [.init(text: fixture.text, start: 1, end: 1 + fixture.duration, letters: letters)])
    for i in letters.indices {
        let value = MildPlayfulEffects.jelly(word: word, letterIndex: i, position: fixture.position, lastWord: fixture.last, configuration: config, fontHeight: 30)
        check(near(value.lift, fixture.letters[i].lift) && near(value.scale, fixture.letters[i].scale), "Jelly diverges from pinned Mild: \(fixture.text) \(fixture.position) \(i): \(value) vs \(fixture.letters[i])")
    }
}
check(MildPlayfulEffects.spin(start: 1, end: 2, position: 1.25, turns: 1) == 90, "Spin must rotate the active word through one full turn over its own duration")
check(MildPlayfulEffects.spin(start: 2, end: 3, position: 1.25, turns: 1) == 0, "Future words must not spin")
check(MildPlayfulEffects.spin(start: 1, end: 2, position: 2, turns: 1) == 0, "Finished words return to rest")
check(MildPlayfulEffects.spin(start: 1, end: 2, position: 1.5, turns: 2) == 360, "Spin intensity is turns, not wobble amplitude")
let paused = MildPlayfulEffects.flight(start: 1, position: 1.2, speed: 1, fontHeight: 30)
check(paused == MildPlayfulEffects.flight(start: 1, position: 1.2, speed: 1, fontHeight: 30), "Playback-driven effects must hold exactly on pause")
check(MildPlayfulEffects.flight(start: 1, position: 0.5, speed: 1, fontHeight: 30) == .init(), "Seeking backward restores a word")
let dotStart = (0..<3).map { MildPlayfulEffects.dotDeparture(start: 0, end: 10, index: $0, speed: 1) }
check(dotStart[0] < dotStart[1] && dotStart[1] < dotStart[2] && dotStart[2] == 9, "Interlude dots leave in order and finish at the next lyric")
let state = MildWordDrift.State(x: 90, y: 70, vx: 50, vy: 60, angle: 10, angularVelocity: 20)
let bounced = MildWordDrift.integrate(state, dt: 0.05, speed: 2, width: 100, height: 80, wordWidth: 10, wordHeight: 10)
check(bounced.x == 90 && bounced.y == 70 && bounced.vx == -50 && bounced.vy == -60 && bounced.angle == 12, "No-gravity words coast, rotate and bounce on viewport edges")
let engine = MildWordDrift(), viewport = CGSize(width: 390, height: 600)
func candidate(_ key: String = "word", end: Double = 1, y: Double = 100) -> MildWordDrift.Candidate {
    .init(key: key, frame: CGRect(x: 100, y: y, width: 40, height: 25), end: end)
}
check(!MildWordDrift.hasFinished(start: 0, end: 1, position: 0.99)
      && MildWordDrift.hasFinished(start: 0, end: 1, position: 1), "Keep active words in the readable lyric line until their end")
check(!MildWordDrift.hasFinished(start: 1, end: 1, position: 2), "Invalid word spans cannot detach")
check(engine.update(candidates: [candidate()], viewport: viewport, now: 0, position: 0.99,
                    isPlaying: true, speed: 1).isEmpty, "Future/active words must not enter physics")
let at = engine.update(candidates: [candidate()], viewport: viewport, now: 0.01, position: 1,
                       isPlaying: true, speed: 1)[0]
let afterScroll = engine.update(candidates: [candidate(y: 300)], viewport: viewport, now: 0.01, position: 1,
                                isPlaying: true, speed: 1)[0]
check(at.state.x == afterScroll.state.x && at.state.y == afterScroll.state.y, "Scrolling source rows must not drag loose words")
let detached = engine.update(candidates: [], viewport: viewport, now: 0.06, position: 1.05, isPlaying: true, speed: 1)
check(detached.count == 1 && detached[0].state.x != at.state.x, "Unmounting a lazy source row must not remove its moving body")
let held = engine.update(candidates: [], viewport: viewport, now: 9, position: 1.05, isPlaying: false, speed: 1)[0]
check(held.state.x == detached[0].state.x && held.state.y == detached[0].state.y
      && held.age == detached[0].age, "Pause freezes motion and lifetime even if wall time advances")
let resumed = engine.update(candidates: [], viewport: viewport, now: 9.05, position: 1.10, isPlaying: true, speed: 1)[0]
check(resumed.age > held.age && resumed.state.x != held.state.x, "Resume continues the same body")
check(engine.update(candidates: [], viewport: viewport, now: 9.1, position: 0.5, isPlaying: true, speed: 1).isEmpty,
      "Backward seeking clears the old scene")
let fresh = engine.update(candidates: [candidate(y: 300)], viewport: viewport, now: 9.6, position: 1,
                          isPlaying: true, speed: 1)
check(fresh.count == 1 && fresh[0].state.y == 300, "Replaying a word seeds it at its new visible source position")
check(engine.update(candidates: [candidate()], viewport: viewport, now: 9.65, position: 20, isPlaying: true, speed: 1).isEmpty,
      "Forward seeking clears bodies and does not repopulate old history")
let fadeEngine = MildWordDrift()
_ = fadeEngine.update(candidates: [candidate()], viewport: viewport, now: 0, position: 1, isPlaying: true, speed: 1)
var fading: [MildWordDrift.Body] = []
for i in 1...140 {
    let time = Double(i) / 20
    fading = fadeEngine.update(candidates: [], viewport: viewport, now: time, position: time + 1, isPlaying: true, speed: 1)
}
check(fading.count == 1 && fading[0].opacity > 0 && fading[0].opacity < 1,
      "Old bodies fade gradually despite absent source anchors")
let opacity = fading[0].opacity
fading = fadeEngine.update(candidates: [], viewport: viewport, now: 7.05, position: 8.05, isPlaying: true, speed: 1)
check(fading[0].opacity < opacity, "Retirement fade progresses smoothly")
for i in 142...170 {
    let time = Double(i) / 20
    fading = fadeEngine.update(candidates: [], viewport: viewport, now: time, position: time + 1, isPlaying: true, speed: 1)
}
check(fading.isEmpty, "Expired bodies are released after their fade")
let admission = MildWordDrift()
check(admission.update(candidates: [candidate(end: 5), candidate("old", end: 0), candidate("offscreen", end: 1, y: 650)],
                       viewport: viewport, now: 0, position: 1, isPlaying: true, speed: 1).isEmpty,
      "Future, old and offscreen words cannot spawn/clamp onto the bottom edge")
let crowded = admission.update(candidates: (0..<200).map { candidate("w\($0)") }, viewport: viewport,
                               now: 0.05, position: 1.05, isPlaying: true, speed: 1)
check(crowded.count <= MildWordDrift.maximumBodies, "Very fast lyrics keep a bounded physics/render workload")
let survivor = crowded[0].key
check(admission.update(candidates: [candidate("new")], viewport: viewport, now: 0.1, position: 1.1,
                       isPlaying: true, speed: 1).contains { $0.key == survivor },
      "At capacity, existing bodies are retained rather than evicted without a fade")
var opts = MildLyricsOptions(); opts.flags["enabled"] = true; opts.numbers["spin"] = 1; opts.numbers["float_up"] = 1; opts.numbers["zero_g"] = 1; opts.numbers["jelly"] = 1
check(!MildPlayfulConfiguration(options: opts, reduceMotion: true).enabled, "Reduce Motion must disable every playful effect")
check(!MildPlayfulEffects.held("مرحبا", duration: 2, threshold: 0.05), "Jelly must preserve joined RTL script shaping")
print("Direct upstream goldens: \(fixtures.floats.count) float samples, \(fixtures.jelly.count * 4) jelly letter samples")
print("Spin word timing, pause/seek restoration, interlude exits, no-gravity completed-word release, row-independent bodies, fade, pause/seek, bounded workload and Reduce Motion passed")
