import Foundation
struct LyricsOptions {}
struct TestLine { var content: String }
struct TestLyrics { var lines: [TestLine] }
class LrclibLyricsRepository {
    static let shared = LrclibLyricsRepository()
    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> TestLyrics { fatalError("Disabled/fetched sources must not be contacted by Mild uncensor") }
}
typealias LyricsRepository = LrclibLyricsRepository
typealias MusixmatchLyricsRepository = LrclibLyricsRepository
typealias GeniusLyricsRepository = LrclibLyricsRepository
func check(_ value: @autoclosure () -> Bool, _ label: String) { if !value() { fatalError(label) } }
let syllables = [KaraokeSyllableDto(text:"hello",startMs:100,endMs:300,isPartOfWord:false),
                 KaraokeSyllableDto(text:"****",startMs:400,endMs:900,isPartOfWord:false)]
var original = KaraokeLineDto(syllables:syllables,startMs:100,endMs:1000,oppositeAligned:true,backgroundGroups:[syllables],sweetSyllables:syllables)
let filled = LyricsUncensorFill.fillKaraokeFromCandidates(lines:[original], candidates:[["hello world"]])[0]
check(filled.plainText == "hello world" && filled.syllables[1].startMs == 400 && filled.syllables[1].endMs == 900, "Matched full masks retain word timing")
check(filled.sweetSyllables?.plainText == "hello world" && filled.oppositeAligned && filled.backgroundGroups.count == 1, "Keep Sweet timing and vocal metadata")
let mismatch = LyricsUncensorFill.fillKaraokeFromCandidates(lines:[original],candidates:[["different world"],["hello big world"]])[0]
check(mismatch.plainText == "hello ****", "Do not guess from word-count or contextual mismatches")
original.syllables[1].text = "w**ld"; original.sweetSyllables = original.syllables
check(LyricsUncensorFill.fillKaraokeFromCandidates(lines:[original],candidates:[["hello world"]])[0].plainText == "hello w**ld", "Retain partial masks")
print("Mild uncensor matching, disabled-source isolation, timing and metadata checks passed")
