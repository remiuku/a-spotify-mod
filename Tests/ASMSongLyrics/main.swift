import Foundation
extension String { var localized: String { self } }
extension Notification.Name { static let eeveeKaraokeLyricsChanged = Notification.Name("testLyricsChanged") }
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
let suite = "asm.songLyrics.tests." + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let preferences = ASMSongLyricsPreferences(store: defaults)
var profile = ASMSongLyricsPreference()
profile.source = 1; profile.offsetMs = 750; profile.targetLanguage = "es"; profile.recordingID = 128; profile.recordingLabel = "Studio recording"
check(preferences.set(profile, track: "TrackA"), "Save song preference")
check(ASMSongLyricsPreferences(store: defaults).get("TrackA") == profile, "Complete preferences survive relaunch")
check(preferences.get("TrackB") == ASMSongLyricsPreference(), "Another song retains global defaults")
profile.source = 5; profile.offsetMs = 20000; profile.targetLanguage = "../../bad"
check(preferences.set(profile, track: "TrackB"), "Save normalized preference")
check(preferences.get("TrackB").offsetMs == 10000 && preferences.get("TrackB").recordingID == nil
      && preferences.get("TrackB").targetLanguage == nil, "Bound timing and clear incompatible recording / malformed language")
check(!preferences.set(profile, track: "../TrackC") && !ASMSongLyricsPolicy.validID(""), "IDs cannot escape storage directory")
preferences.reset("TrackB")
check(preferences.get("TrackB") == .init() && preferences.get("TrackA").recordingID == 128, "Reset is isolated to one song")
check(ASMSongLyricsPolicy.displayPosition(1000, offset: 750) == 1750
      && ASMSongLyricsPolicy.seekPosition(1750, offset: 750) == 1000, "Display timing and seek are inverse operations")
check(ASMSongLyricsPolicy.seekPosition(200, offset: 750) == 0 && ASMSongLyricsPolicy.displayPosition(200, offset: -750) == 0,
      "Early timestamps clamp at playback start")
let signature = ASMSongLyricsPolicy.signature(source: 1, recording: 128, configuration: Data("config".utf8))
check(signature == ASMSongLyricsPolicy.signature(source: 1, recording: 128, configuration: Data("config".utf8)), "Stable identity across launches")
check(signature != ASMSongLyricsPolicy.signature(source: 1, recording: 129, configuration: Data("config".utf8))
      && signature != ASMSongLyricsPolicy.signature(source: 5, recording: 128, configuration: Data("config".utf8))
      && signature != ASMSongLyricsPolicy.signature(source: 1, recording: 128, configuration: Data("changed".utf8)),
      "Source, recording and provider configuration each invalidate incompatible downloads")
let syllable = KaraokeSyllableDto(text: "Hello", startMs: 1000, endMs: 1400, isPartOfWord: false, romanized: "hello")
let line = KaraokeLineDto(syllables: [syllable], startMs: 1000, endMs: 2000, oppositeAligned: true,
                          backgroundGroups: [[syllable]], sweetSyllables: [syllable], pronunciation: "hello", translation: "Hola")
let lyrics = KaraokeLyricsDto(lines: [line], songWriters: ["Writer"], providerCode: "spicy", providerName: "Spicy Lyrics",
    uploaderName: "Uploader", uploaderUrl: "https://example.com/u", makerName: "Maker", makerUrl: "https://example.com/m",
    uploaderAvatarUrl: "https://example.com/u.png", makerAvatarUrl: "https://example.com/m.png", creditOrigin: "spicy", creditProviderName: "Spicy Lyrics")
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ASMSongLyricsTests-" + UUID().uuidString, isDirectory: true)
defer { try? FileManager.default.removeItem(at: directory) }
let library = ASMLyricsOfflineLibrary(directory: directory, maximumEntries: 1)
let entry = ASMLyricsOfflineEntry(trackID: "TrackA", signature: signature, title: "Studio", artist: "Artist", lyrics: lyrics)
try library.save(entry)
let reloaded = ASMLyricsOfflineLibrary(directory: directory)
let saved = reloaded.load("TrackA", signature: signature)!
check(saved.lyrics.makerAvatarUrl == lyrics.makerAvatarUrl && saved.lyrics.uploaderName == "Uploader"
      && saved.lyrics.creditOrigin == "spicy" && saved.lyrics.songWriters == ["Writer"], "Attribution and real profile URLs round-trip")
check(saved.lyrics.lines[0].backgroundGroups[0][0].endMs == 1400 && saved.lyrics.lines[0].oppositeAligned
      && saved.lyrics.lines[0].sweetSyllables?[0].romanized == "hello", "Word timings, duet/backing groups and pronunciation survive offline persistence")
check(reloaded.load("TrackA", signature: signature + "different") == nil, "Wrong-source or wrong-recording saved content is never reused")
library.storeTranslations(["Hello": "Hola", "Unrelated text": "must not save"], track: "TrackA", signature: signature, target: "es")
check(library.translations("TrackA", signature: signature, target: "es") == ["Hello": "Hola"]
      && library.translations("TrackA", signature: signature, target: "fr").isEmpty, "Saved translations are text- and language-bound")
try library.save(entry)
check(library.translations("TrackA", signature: signature, target: "es")["Hello"] == "Hola", "Updating a saved song retains its existing prepared translations")
var another = entry; another.trackID = "TrackB"
do { try library.save(another); fatalError("Full library silently evicted a saved song") } catch ASMLyricsOfflineLibrary.Failure.full {}
check(library.entries().map(\.trackID) == ["TrackA"], "Storage limits never silently evict explicit saves")
let prepared = ASMLyricsPreparedTranslations.shared
prepared.store(["Hello": "Hola"], track: "TrackA", signature: signature, target: "es")
check(prepared.get("TrackA", signature: signature)["es"]?["Hello"] == "Hola"
      && prepared.get("TrackA", signature: "stale").isEmpty, "Save handoff rejects translations from another source/recording")
let store = KaraokeLyricsStore.shared
store.set(trackId: "TrackA", lyrics: lyrics); store.validate(trackId: "TrackA", signature: signature)
check(store.validatedLyrics(trackId: "TrackA", signature: "stale") == nil, "Presentation cache obeys selection identity")
store.remove(trackId: "TrackA")
check(store.validatedLyrics(trackId: "TrackA", signature: signature) != nil, "In-flight raw provider handoffs cannot erase the complete validated document")
store.invalidateValidated("TrackA")
check(store.validatedLyrics(trackId: "TrackA", signature: signature) == nil, "Explicit refresh invalidates cached presentation")
let timed = ASMLyricRecording.timedLines("[ar:Artist]\n[00:03.50]Last\n[00:01.00][00:02.00]Repeat\n[00:60.00]Invalid")
check(timed.map(\.ms) == [1000, 2000, 3500] && timed.last?.text == "Last", "Recording parser preserves repeated timestamps and final non-newline line, rejects invalid seconds")
check(ASMLyricRecording.timedLines(String(repeating: "a", count: 1024 * 1024 + 1)).isEmpty, "Recording response parsing is bounded")
check(!ASMTranslationDisplay.original.hideOriginal(translation: "Hola") && !ASMTranslationDisplay.translated.hideOriginal(translation: nil)
      && !ASMTranslationDisplay.translated.hideOriginal(translation: " ") && ASMTranslationDisplay.translated.hideOriginal(translation: "Hola"),
      "Translation-only mode always retains the original when no translation exists")
for mask in 0..<32 {
    let flags = (0..<5).map { mask & (1 << $0) != 0 }
    check(ASMLyricsWakePolicy.active(visible: flags[0], foreground: flags[1], enabled: flags[2], playing: flags[3], musicTrack: flags[4]) == (mask == 31),
          "Wake lock only belongs to visible foreground playing lyrics with opt-in")
}
let oldOptions = try JSONDecoder().decode(KaraokeOptions.self, from: Data("{}".utf8))
check(oldOptions.translationDisplay == .bilingual, "Legacy settings preserve existing bilingual display")
try library.remove("TrackA")
check(library.entries().isEmpty, "Explicit offline removal works")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
try Data("invalid json".utf8).write(to: directory.appendingPathComponent("TrackA.json"))
check(library.load("TrackA", signature: signature) == nil, "Corrupt saved file is ignored safely")
print("PASS song lyrics: isolated persistent preferences, exact selection identity, rich offline round-trip/credits/translations, storage bounds, cache validation, recording parser, display fallback and wake lifecycle policy")
