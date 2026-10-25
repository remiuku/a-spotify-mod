import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

// Out-of-order songs and changing sources may finish after the user has moved
// on. A retry of the same song is a new visit too, not the old request's owner.
var selection = KaraokeLookupSelection<String>()
let songA = selection.begin("song-a/mild")
let songB = selection.begin("song-b/mild")
require(!selection.accepts("song-a/mild", revision: songA), "previous song accepted")
require(selection.accepts("song-b/mild", revision: songB), "current song rejected")
let newSource = selection.begin("song-b/lrclib")
require(!selection.accepts("song-b/mild", revision: songB), "previous source accepted")
let retry = selection.begin("song-b/lrclib")
require(!selection.accepts("song-b/lrclib", revision: newSource), "previous attempt accepted")
require(selection.accepts("song-b/lrclib", revision: retry), "retry rejected")
_ = selection.begin(nil)
require(!selection.accepts("song-b/lrclib", revision: retry), "podcast/closed selection accepted")

enum TestError: Error { case offline }
let requests = KaraokeLookupRequests<String, Int>(deliver: { $0() })
let started = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
let completed = DispatchSemaphore(value: 0), otherCompleted = DispatchSemaphore(value: 0)
let lock = NSLock()
var operations = 0, values: [Int] = []
let completion: (Result<Int, Error>) -> Void = { result in
    lock.lock(); values.append((try? result.get()) ?? -1); lock.unlock()
    completed.signal()
}
requests.request("same-song", operation: {
    lock.lock(); operations += 1; lock.unlock()
    started.signal()
    require(release.wait(timeout: .now() + 5) == .success, "operation not released")
    return 42
}, completion: completion)
require(started.wait(timeout: .now() + 5) == .success, "request did not start")
for _ in 0..<20 {
    requests.request("same-song", operation: { fatalError("duplicate network operation") }, completion: completion)
}
// A different song is not held up by an older song's slow request.
requests.request("other-song", operation: { 7 }, completion: {
    require((try? $0.get()) == 7, "other song failed")
    otherCompleted.signal()
})
require(otherCompleted.wait(timeout: .now() + 5) == .success, "slow previous song blocked current lookup")
release.signal()
for _ in 0..<21 { require(completed.wait(timeout: .now() + 5) == .success, "missing coalesced completion") }
require(operations == 1 && values == Array(repeating: 42, count: 21), "coalescing lost a subscriber")

let failed = DispatchSemaphore(value: 0)
requests.request("offline", operation: { throw TestError.offline }, completion: {
    if case .success = $0 { fatalError("error lost") }
    failed.signal()
})
require(failed.wait(timeout: .now() + 5) == .success, "failure not delivered")
requests.request("offline", operation: { 99 }, completion: {
    require((try? $0.get()) == 99, "retry reused failure")
    failed.signal()
})
require(failed.wait(timeout: .now() + 5) == .success, "retry did not complete")

// Source integration checks protect the original regression: button/presenter
// must allow an uncached track, and must enter the independent lookup shell.
let base = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func source(_ path: String) -> String {
    try! String(contentsOf: base.appendingPathComponent("Sources/EeveeSpotify/" + path), encoding: .utf8)
}
let presenter = source("Karaoke/KaraokeOverlayPresenter.swift")
let gate = presenter.components(separatedBy: "static func isAvailableForCurrentTrack()").last!.components(separatedBy: "/// Walks").first!
require(!gate.contains("lyrics(forTrackId:"), "uncached songs are still hidden")
require(!gate.contains("has_lyrics"), "Spotify's flag still gates access")
require(presenter.contains("KaraokeLookupView(onDismiss:"), "presenter bypasses lookup states")
require(!source("Karaoke/KaraokeLyricsViewModel.swift").contains("prefetchLyricsIfNeeded"), "renderer still starts competing retries")
print("PASS lookup: stale song/source/retry rejection, 21 coalesced callers, independent tracks, offline retry, uncached access wiring")
