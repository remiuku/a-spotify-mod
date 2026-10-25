import Foundation

extension String { var localized: String { self } }
func writeDebugLog(_ message: String) {}
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
func syllable(_ text: String, _ start: Int, _ end: Int, joins: Bool = false) -> KaraokeSyllableDto {
    .init(text: text, startMs: start, endMs: end, isPartOfWord: joins)
}

let decoder = JSONDecoder(), encoder = JSONEncoder()
let old = try decoder.decode(KaraokeOptions.self, from: Data("{\"blurIntensity\":2.3,\"textAlignment\":\"trailing\",\"reversedDirection\":true}".utf8))
check(old.renderer == .eevee && !old.sweetSimpleLyrics && old.blurIntensity == 2.3 && old.reversedDirection, "Existing Eevee settings must retain their defaults and values")
let migrated = try decoder.decode(KaraokeOptions.self, from: Data("{\"renderer\":\"spicyMobile\",\"enabled\":false}".utf8))
check(migrated.renderer == .sweetLyrics && !migrated.enabled, "The previous custom renderer choice must migrate to Sweet")
var selected = old
selected.renderer = .sweetLyrics; selected.sweetSimpleLyrics = true
let roundTrip = try decoder.decode(KaraokeOptions.self, from: encoder.encode(selected))
check(roundTrip == selected, "Sweet selection and simple mode must persist")
let unknown = try decoder.decode(KaraokeOptions.self, from: Data("{\"renderer\":\"future\",\"blurIntensity\":2}".utf8))
check(unknown.renderer == .eevee && unknown.blurIntensity == 2, "Unknown renderer must recover without resetting other choices")
for viewer in KaraokeRenderer.allCases {
    var options = old
    options.renderer = viewer
    let decoded = try decoder.decode(KaraokeOptions.self, from: encoder.encode(options))
    check(decoded == options, "Every viewer must retain the existing appearance settings across persistence")
}

var first = KaraokeLineDto(syllables: [syllable("hel", 3125, 3400, joins: true), syllable("lo", 3400, 4100)], startMs: 3125, endMs: 4100)
let entry = SpicyLyricsJSON(["Agent": "singer2", "Background": [
    ["Syllables": [["Text": "echo", "StartTime": 3.4, "EndTime": 4.6, "IsPartOfWord": false]]],
    ["Syllables": [["Text": "again", "StartTime": 4.6, "EndTime": 5.2]]]
]])
first = KaraokeVocalMetadata.decorate(first, from: entry, defaultAgent: "singer1")
check(first.oppositeAligned && first.backgroundGroups.count == 2, "Preserve duet agent and separate backing-vocal groups")
let explicit = KaraokeVocalMetadata.decorate(first, from: SpicyLyricsJSON(["Agent": "singer2", "OppositeAligned": false]), defaultAgent: "singer1")
check(!explicit.oppositeAligned, "Explicit side must override agent fallback")
let singleBackground = KaraokeVocalMetadata.decorate(first, from: SpicyLyricsJSON(["Background": ["Syllables": [["Text": "one", "StartTime": 1.0, "EndTime": 2.0]]]]), defaultAgent: nil)
check(singleBackground.backgroundGroups.count == 1, "A single background object must remain supported")
let second = KaraokeLineDto(syllables: [syllable("next", 8500, 9500)], startMs: 8500, endMs: 9500)
let dto = KaraokeLyricsDto(lines: [first, second], songWriters: ["Writer"], providerCode: "spicy", makerName: "Maker")
let document = SweetLyricsAdapter.document(from: dto)
check(document.kind == .syllable && near(document.lines[0].lead[0].start, 3.125), "Convert milliseconds to precise seconds")
check(document.lines[0].oppositeAligned && document.lines[0].backgroundVocals.count == 2 && near(document.lines[0].end, 5.2), "Backing tails must extend the group without losing separate rows")
check(document.songwriters == ["Writer"] && document.credits?.maker?.name == "Maker", "Keep attribution")
let prepared = SweetPreparedLyrics(document: document, romanized: false)
check(prepared.lines.filter(\.isInterlude).count == 2, "Insert intro and instrumental dots around the complete vocal group")
check(prepared.lines.filter(\.isBackground).count == 2, "Each backing group must become a smaller row")
let lead = prepared.lines.first { !$0.isInterlude && !$0.isBackground }!
if case .syllable(let words, _) = lead.kind { check(words.count == 1 && words[0].syllables.count == 2, "Glued syllables must remain one word") }
else { fatalError("Expected word timing") }
check(SweetLyricsAdapter.seekStartMs(for: lead) == 3125 && SweetLyricsAdapter.seekStartMs(for: prepared.lines[0]) == nil, "Interlude dots must never dispatch a seek")

var overlap = first
overlap.sweetSyllables = [syllable("original", 2000, 2900)]
overlap.syllables = [syllable("clamped", 6000, 6000)]
let originalDocument = SweetLyricsAdapter.document(from: .init(lines: [overlap], songWriters: [], providerCode: nil))
check(originalDocument.lines[0].lead[0].text == "original" && originalDocument.lines[0].lead[0].start == 2, "Sweet must use original overlapping timing, not Eevee's clamped copy")
let lineOnly = KaraokeLyricsDto(lines: [.init(syllables: [syllable("line", 1000, 1000)], startMs: 1000, endMs: 4000)], songWriters: [], providerCode: nil)
check(SweetLyricsAdapter.document(from: lineOnly).kind == .line, "Line-only lyrics must retain line timing")

let animator = SweetLyricsAnimator(lyrics: prepared)
animator.step(position: 8.9, now: 100, blurEnabled: true)
check(animator.snapped && animator.focusIndex == prepared.lines.count - 1, "Opening mid-song must snap to the playing line")
animator.step(position: 3.3, now: 100.016, blurEnabled: true)
check(animator.snapped && animator.focusIndex == lead.id, "Backward seek must reset old spring/scroll state")
check(animator.visuals.last?.state == .notSung, "Later lines must become unsung after seeking backward")
let previousFrame = animator.visuals
animator.step(position: 3.6, now: 100.316, blurEnabled: true)
check(animator.visuals[lead.id] != previousFrame[lead.id], "Word states must change within the same lyric line")
check(previousFrame[lead.id].state == .active, "A captured previous frame must remain an immutable value snapshot")
var early = KaraokeLineDto(syllables: [syllable("lead", 5000, 6000)], startMs: 5000, endMs: 6000)
early.backgroundGroups = [[syllable("early backing", 2500, 4000)]]
let earlyDTO = KaraokeLyricsDto(lines: [.init(syllables: [syllable("before", 0, 2000)], startMs: 0, endMs: 2000), early, second], songWriters: [], providerCode: nil)
let earlyPrepared = SweetPreparedLyrics(document: SweetLyricsAdapter.document(from: earlyDTO), romanized: false)
let earlyAnimator = SweetLyricsAnimator(lyrics: earlyPrepared)
earlyAnimator.step(position: 3, now: 1, blurEnabled: true)
let backing = earlyPrepared.lines.first(where: \.isBackground)!
check(earlyAnimator.focusIndex == backing.leadID, "A backing vocal starting before its lead must focus its own lead group")
earlyAnimator.step(position: 8.8, now: 2, blurEnabled: true)
check(earlyAnimator.focusIndex == earlyPrepared.lines.last?.id, "Older backing rows must not pull focus back from the next lead")
let empty = SweetPreparedLyrics(document: .init(kind: .line, lines: [], songwriters: [], sourceName: ""), romanized: false)
SweetLyricsAnimator(lyrics: empty).step(position: 1, now: 1, blurEnabled: false)
var spring = SweetSpring(0, frequency: 1, damping: 1)
spring.setGoal(1)
for _ in 0..<240 { _ = spring.step(1.0 / 60) }
check(near(spring.position, 1), "Imported spring must settle accurately")
var metrics = SweetFrameMetrics()
_ = metrics.record(at: 0)
var sample: SweetFrameMetrics.Sample?
for i in 1...150 { sample = metrics.record(at: Double(i) / 30) ?? sample }
check(near(sample!.ticksPerSecond, 30) && sample!.longestGap < 0.034, "Diagnostics must report a 30 Hz callback stream accurately")
metrics.reset()
_ = metrics.record(at: 10)
let stalled = metrics.record(at: 15)!
check(near(stalled.ticksPerSecond, 0.2) && stalled.longestGap == 5, "Diagnostics must distinguish a five-second stall from a smooth clock")
print("Sweet Lyrics migration, raw timing, duet/backing groups, credits, preparation, seek snaps and spring tests passed")

let heldAnimator = SweetLyricsAnimator(lyrics: prepared)
heldAnimator.step(position: 3.3, now: 1, blurEnabled: true, frameInterval: 1.0/30)
for frame in 1...150 {
    heldAnimator.step(position: 3.3, now: 1 + Double(frame) * 0.08, blurEnabled: true, frameInterval: 1.0/30, isPlaying: false)
}
check(heldAnimator.focusIndex == lead.id && heldAnimator.presentationLead == 0, "Paused Sweet focus and presentation lead stay at the held lyric")
check(heldAnimator.visuals.last?.state == .notSung, "Pausing must never advance later lines")
heldAnimator.step(position: 8.9, now: 14, blurEnabled: true, frameInterval: 1.0/30, isPlaying: false)
check(heldAnimator.snapped && heldAnimator.focusIndex == prepared.lines.last?.id, "Seeking while paused still moves Sweet to the selected line")
heldAnimator.step(position: 3.3, now: 15, blurEnabled: true, frameInterval: 1.0/30, isPlaying: true)
check(heldAnimator.snapped && heldAnimator.focusIndex == lead.id, "Resume/backward seek restores the correct line")
print("PASS Sweet pause: no focus/highlight advancement or latency lead while held; paused seeks and resume retained")
