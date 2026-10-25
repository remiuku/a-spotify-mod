import Foundation
extension String { var localized: String { self } }
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
var options = KaraokeOptions()
func enabled(_ options: KaraokeOptions, supported: Bool = true, music: Bool = true, native: Bool = true) -> Bool {
    KaraokePlayerPreviewPolicy.enabled(options: options, supportedSource: supported, musicTrack: music, nativeInterface: native)
}
for renderer in KaraokeRenderer.allCases {
    options.renderer = renderer
    check(enabled(options) == (renderer != .spotify), "Spotify selection preserves native surfaces; every custom viewer uses the preview")
}
options.renderer = .sweetLyrics; options.replacePlayerLyrics = false
check(!enabled(options), "The replacement switch restores native lyrics without changing selected viewer")
options.replacePlayerLyrics = true; options.enabled = false
check(!enabled(options), "Disabling custom lyrics restores native surfaces")
options.enabled = true
check(!enabled(options, supported: false) && !enabled(options, music: false) && !enabled(options, native: false),
      "Unsupported sources, non-music items and imported interfaces keep their existing surfaces")
let old = try JSONDecoder().decode(KaraokeOptions.self, from: Data("{\"renderer\":\"sweetLyrics\"}".utf8))
check(old.replacePlayerLyrics, "Existing custom-viewer settings adopt the replacement without losing other choices")
options.replacePlayerLyrics = false
let saved = try JSONDecoder().decode(KaraokeOptions.self, from: JSONEncoder().encode(options))
check(!saved.replacePlayerLyrics && saved.renderer == .sweetLyrics, "Explicit stock-card choice survives persistence")
func line(_ text: String, at start: Int) -> KaraokeLineDto {
    .init(syllables: [.init(text: text, startMs: start, endMs: start + 1000, isPartOfWord: false)], startMs: start, endMs: start + 1000)
}
let dto = KaraokeLyricsDto(lines: [line("Chorus", at: 2000), line("Intro", at: 1000), line("Chorus", at: 3000),
                                   line("", at: 0), line("Outro", at: 4000)], songWriters: [], providerCode: nil)
let rows = KaraokePlayerPreviewPolicy.rows(dto)
check(rows.map(\.text) == ["Intro", "Chorus", "Chorus", "Outro"] && Set(rows.map(\.id)).count == 4,
      "Unsorted source lines are ordered, empty entries omitted and repeated phrases retain separate identities")
check(KaraokePlayerPreviewPolicy.focus(rows, position: 2200) == 1 && KaraokePlayerPreviewPolicy.focus(rows, position: 1200) == 0,
      "Forward playback and backwards seeks select by timestamp rather than callback frequency")
check(KaraokePlayerPreviewPolicy.window(rows, position: 3500).map(\.text) == ["Chorus", "Chorus", "Outro"],
      "Only a small context window is rendered around the playing line")
check(KaraokePlayerPreviewPolicy.window(rows, position: 99999).count == 3
      && KaraokePlayerPreviewPolicy.focus([], position: 0) == nil
      && KaraokePlayerPreviewPolicy.window([], position: 0).isEmpty,
      "Late playback and missing lyrics stay bounded and safe")
var alternative = line("Eevee text", at: 0)
alternative.sweetSyllables = [.init(text: "Sweet source words", startMs: 0, endMs: 1000, isPartOfWord: false)]
check(KaraokePlayerPreviewPolicy.rows(.init(lines: [alternative], songWriters: [], providerCode: nil)).first?.text == "Sweet source words",
      "Preview uses the same richer custom-source words as the full viewer")
print("PASS player preview: custom/stock mode restoration policy, source/music/interface guards, backward-compatible preferences, duplicate identities, bounded context and seek-aware timing")

check(KaraokePlayerPreviewPolicy.headerReservation(contentHeight: 170) == 186, "Owned scroll header reserves only measured content plus separation")
check(KaraokePlayerPreviewPolicy.headerReservation(contentHeight: .nan) == 200, "Invalid sizing cannot poison scroll geometry")
check(KaraokePlayerPreviewPolicy.headerReservation(contentHeight: -5) == 156 && KaraokePlayerPreviewPolicy.headerReservation(contentHeight: 1000) == 256, "Preview size stays bounded for loading, long lyrics and large text")
print("PASS independent preview sizing: measured compact height, finite fallback and bounded scroll-header reservation")

check(!KaraokePlayerPreviewPolicy.shiftAfterGap(y: 700, seam: 800, occupied: 0), "Playback controls before seam keep native position")
check(KaraokePlayerPreviewPolicy.shiftAfterGap(y: 800, seam: 800, occupied: 0), "First following card moves when native lyrics are missing")
check(!KaraokePlayerPreviewPolicy.shiftAfterGap(y: 800, seam: 800, occupied: 300), "Replacing native lyric card does not move its own anchor")
check(KaraokePlayerPreviewPolicy.shiftAfterGap(y: 1100, seam: 800, occupied: 300), "Following cards move by only the replacement height difference")
check(!KaraokePlayerPreviewPolicy.shiftAfterGap(y: .nan, seam: 800, occupied: 0), "Invalid native positions cannot change layout")
print("PASS positive preview gap: controls preserved, source-independent insertion, replacement boundary and finite geometry")

let footprint = 3 * KaraokePlayerPreviewPolicy.rowHeight + 2 * 8 + 20 + 12 + 36
check(footprint <= KaraokePlayerPreviewPolicy.contentHeight, "Header, three two-line rows, spacing and padding fit without clipping")
check(KaraokePlayerPreviewPolicy.headerReservation(contentHeight: KaraokePlayerPreviewPolicy.contentHeight) == 252, "Loading and active lyric windows reserve one stable footprint")
print("PASS stable preview footprint: three rows, header and padding fit fixed content height")
