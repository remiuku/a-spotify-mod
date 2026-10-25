import Foundation
var sourceIdentityA = MildLyricsOptions()
sourceIdentityA.disabledSources = ["apple", "qq", "genius"]
var sourceIdentityB = sourceIdentityA
sourceIdentityB.disabledSources = Set(["genius", "qq", "apple"])
check(sourceIdentityA.sourceSelectionData == sourceIdentityB.sourceSelectionData, "Source identity survives Set insertion-order changes across launches")
sourceIdentityB.numbers["spin"] = 2
sourceIdentityB.choices["background"] = "glass"
check(sourceIdentityA.sourceSelectionData == sourceIdentityB.sourceSelectionData, "Fun effects and appearance do not invalidate offline lyric content")
sourceIdentityB.flags["uncensor"] = !sourceIdentityA.flag("uncensor")
check(sourceIdentityA.sourceSelectionData != sourceIdentityB.sourceSelectionData, "Source-affecting uncensor control invalidates a different lyric result")
func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
func s(_ text: String, _ start: Int, _ end: Int, _ join: Bool = false) -> KaraokeSyllableDto { .init(text: text, startMs: start, endMs: end, isPartOfWord: join) }
func line(_ syllables: [KaraokeSyllableDto]) -> KaraokeLineDto { .init(syllables: syllables, startMs: syllables.first!.startMs, endMs: syllables.last!.endMs) }
func doc(_ lines: [KaraokeLineDto]) -> KaraokeLyricsDto { .init(lines: lines, songWriters: [], providerCode: nil) }

let donor = [s("hello", 1000, 1800), s("world", 2100, 2900)]
let relay = MildLyricsBlend.relay(text: "Hello, world!", donor: donor)!
check(relay.plainText == "Hello, world!", "Blending must retain base case, punctuation and word gaps")
check(relay.map(\.startMs) == [1000,2100] && relay.map(\.endMs) == [1800,2900], "Never invent uniform word timestamps")
check(MildLyricsBlend.relay(text: "Something unrelated", donor: donor) == nil, "Reject unrelated text")
let joined = MildLyricsBlend.relay(text: "Hello world", donor: [s("hel", 1000,1200,true),s("lo",1200,1800),s("world",2100,2900)])!
check(joined.plainText == "Hello world" && joined[0].isPartOfWord && !joined[1].isPartOfWord, "Retain intra-word joins")

let base = doc([line([s("Hello, world!",0,4000)])])
let split = doc([line([s("hel",1000,1200,true),s("lo",1200,1800)]),line([s("wor",2100,2300,true),s("ld",2300,2900)])])
let regroup = MildLyricsBlend.blend(base: base, donors: [split], baseName: "base", donorNames: ["donor"])!
check(regroup.lines[0].plainText == "Hello, world!" && regroup.lines[0].syllables.count == 4, "Regroup donor lines without replacing the base line breaks")
let splitBase = doc([line([s("Hello",0,1000)]),line([s("world",1000,2000)])])
let regroup2 = MildLyricsBlend.blend(base: splitBase, donors: [doc([line(donor)])], baseName: "base", donorNames: ["donor"])!
check(regroup2.lines.map(\.plainText) == ["Hello","world"] && regroup2.lines.map(\.startMs) == [1000,2100], "Split a donor line at existing word boundaries")
check(MildLyricsBlend.blend(base: base, donors: [doc([line([s("Hello world",1000,3000)])])], baseName: "base", donorNames: ["line-only"]) == nil, "Line timing is not word timing")
let earlyBase = doc([line([s("Opening",0,500)]),line([s("Hello world",1000,3000)])])
let earlyDonor = doc([line([s("Hello",100,300),s("world",400,600)])])
let early = MildLyricsBlend.blend(base: earlyBase, donors:[earlyDonor],baseName:"base",donorNames:["donor"])!
check(early.lines.flatMap(\.syllables).allSatisfy { $0.startMs >= 0 && $0.endMs >= $0.startMs }, "Retiming unmatched openings must not produce negative positions")

let query = LyricsSearchQuery(title: "Synthetic Song", primaryArtist: "Example Artist", spotifyTrackId: "test")
check(MildLyricsParsing.recordingMatches(title: "synthetic song", artist: "Example Artist", duration: 180, query: query, expectedDuration: 180), "Match same recording")
check(!MildLyricsParsing.recordingMatches(title: "Synthetic Song (Live)", artist: "Example Artist", duration: 180, query: query, expectedDuration: 180), "Refuse other cuts")
check(!MildLyricsParsing.recordingMatches(title: "Synthetic Song", artist: "Cover Artist", duration: 180, query: query, expectedDuration: 180), "Refuse covers")
check(!MildLyricsParsing.recordingMatches(title: "Synthetic Song", artist: "Example Artist", duration: 240, query: query, expectedDuration: 180), "Refuse duration mismatches")

let lrc = MildLyricsParsing.lrc("[00:01.00][00:03.00]hello\n[00:05.00]last line", name: "test")!
check(lrc.lines.count == 3 && lrc.lines.last!.plainText == "last line", "Keep final LRC line without newline and repeated stamps")
let krc = MildLyricsParsing.words("[1000,2000]<0,800,0>Hello <1100,800,0>world", format: "krc", name: "test")!
check(krc.lines[0].syllables.map(\.startMs) == [1000,2100] && krc.lines[0].plainText == "Hello world", "KRC uses relative word offsets")
let yrc = MildLyricsParsing.words("[1000,2000](1000,800,0)Hello (2100,800,0)world", format: "yrc", name: "test")!
check(yrc.lines[0].syllables.map(\.startMs) == [1000,2100], "YRC uses absolute offsets")
let parenthesis = MildLyricsParsing.words("[1000,2000](1000,800,0)(Hello) (2100,800,0)world", format: "yrc", name: "test")!
check(parenthesis.lines[0].plainText == "(Hello) world", "Parentheses inside YRC text are not timing delimiters")
let qrc = MildLyricsParsing.words("[1000,2000]Hello (1000,800)world(2100,800)", format: "qrc", name: "test")!
check(qrc.lines[0].syllables.map(\.startMs) == [1000,2100] && qrc.lines[0].plainText == "Hello world", "QRC timestamps follow words")
let ttml = """
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata" xmlns:itunes="http://music.apple.com/lyric-ttml-internal" itunes:timing="Word"><body><div><p begin="1s" end="3s"><span begin="1s" end="1.8s">Hello </span><span begin="2.1s" end="2.9s">world</span><span ttm:role="x-bg"><span begin="2.2s" end="3s">(echo)</span></span></p></div></body></tt>
"""
let parsed = MildLyricsParsing.ttml(ttml,name:"test")!
check(parsed.lines[0].plainText == "Hello world" && parsed.lines[0].backgroundGroups.count == 1, "Preserve TTML backing vocals")

var options = MildLyricsOptions()
options.sourceOrder = ["qq","qq","future"]
check(options.orderedSources.first == "qq" && Set(options.orderedSources).count == 12 && options.orderedSources.count == 12, "Sanitize source order without duplicates or unknown IDs")
options.numbers["fps"] = .infinity; options.numbers["font_scale"] = 800
check(options.number("fps") == 30 && options.number("font_scale") == 1.9, "Clamp nonfinite and extreme settings")
options.choices["renderer"] = "future"
check(options.choice("renderer") == "spicy", "Unknown styles recover")
options = MildLyricsOptions(); options.flags["fold_adlibs"] = true; options.choices["roman"] = "instead"
let converted = MildRenderPolicy.document(SweetLyricsAdapter.document(from: parsed), options: options)
check(converted.lines[0].backgroundVocals.isEmpty, "Fold adlibs removes backing rows")
let prepared = SweetPreparedLyrics(document: SweetLyricsAdapter.document(from: parsed), romanized: false)
let animator = SweetLyricsAnimator(lyrics: prepared)
animator.step(position:1.3, now:1, blurEnabled:true, frameInterval:1/30)
var still = MildLyricsOptions(); still.numbers["pop"] = 3; still.numbers["rise"] = 4
let moving = MildRenderPolicy.visual(animator.visuals[0], line: prepared.lines[0], focus: 0, position: 1.3, options: still, reduceMotion: true)
check(moving.lead.flatMap { $0 }.allSatisfy { $0.glyph.scale == 1 && $0.glyph.yOffset == 0 }, "Reduce Motion disables word movement")
var preview = SweetLineVisual()
var syllableVisual = SweetSyllableVisual()
syllableVisual.glyph.scale = 1.05; syllableVisual.glyph.yOffset = -0.02; syllableVisual.glyph.glow = 1
preview.lead = [[syllableVisual], [syllableVisual]]
var amll = MildLyricsOptions(); amll.choices["renderer"] = "amll"
let amllVisual = MildRenderPolicy.visual(preview, line: prepared.lines[0], focus: 0, position: 1.3, options: amll, reduceMotion: false)
check(amllVisual.lead[0][0].glyph.scale > preview.lead[0][0].glyph.scale && amllVisual.lead[0][0].glyph.glow < 1, "AMLL style applies distinct native emphasis and glow")
amll.choices["renderer"] = "flow"
let flow = MildRenderPolicy.visual(preview, line: prepared.lines[0], focus: 0, position: 1.3, options: amll, reduceMotion: false)
check(flow.lead[0][0].glyph.scale == 1 && flow.lead[0][0].glyph.yOffset == 0, "Flow disables per-word movement")
let encoded = try JSONEncoder().encode(options)
let decoded = try JSONDecoder().decode(MildLyricsOptions.self, from: encoded)
check(decoded == options, "Settings persist")
print("Mild blend, provider-format, recording-match, persistence and motion checks passed")

let metadataTTML = """
<tt xmlns:ttm="urn:ttm" xmlns:itunes="urn:itunes" itunes:timing="Word"><head><metadata><iTunesMetadata><translations><translation xml:lang="en"><text for="L1">hello world</text></translation></translations><transliterations><transliteration xml:lang="ja-Latn"><text for="L1">konnichiwa</text></transliteration></transliterations></iTunesMetadata></metadata></head><body><div><p begin="1s" end="3s" itunes:key="L1"><span begin="1s" end="2s">こんにちは</span> <span begin="2s" end="3s">世界</span></p><p begin="4s" end="5s"><span begin="4s" end="5s">歌</span><span ttm:role="x-translation">song</span><span ttm:role="x-roman">uta</span></p></div></body></tt>
"""
let enriched = MildLyricsParsing.ttml(metadataTTML, name: "fixture")!
check(enriched.lines[0].translation == "hello world" && enriched.lines[0].pronunciation == "konnichiwa", "Head translations and Latin pronunciation survive TTML conversion")
check(enriched.lines[1].translation == "song" && enriched.lines[1].pronunciation == "uta" && enriched.lines[1].plainText == "歌", "Inline metadata never contaminates sung words")
let enrichedDocument = SweetLyricsAdapter.document(from: enriched)
check(enrichedDocument.lines[0].translation == "hello world" && enrichedDocument.lines[0].romanizedText == "konnichiwa", "Sweet adapter retains source metadata")
var languageBase = base
languageBase.lines[0].translation = "kept translation"; languageBase.lines[0].pronunciation = "kept pronunciation"
if let blendedMetadata = MildLyricsBlend.blend(base: languageBase, donors: [doc([line(donor)])], baseName: "base", donorNames: ["donor"]) {
    check(blendedMetadata.lines[0].translation == "kept translation" && blendedMetadata.lines[0].pronunciation == "kept pronunciation", "Blending preserves base language metadata")
} else { fatalError("Expected existing blend fixture") }
print("PASS source metadata: head and inline TTML, sung-text separation, Sweet adapter and blend retention")
