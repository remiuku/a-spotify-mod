import Foundation
import FoundationNetworking

let customize = URL(string: "https://spclient.wg.spotify.com/ucs/v1/customize")!
let bootstrap = URL(string: "https://spclient.wg.spotify.com/ucs/v1/bootstrap")!
// The old implementation returned a blocked (empty) body after 30 seconds,
// including warm launches where the patched configuration exists only on disk.
for age in [0.0, 29.9, 30.1, 3_600.0] {
    tweakInitTime = Date().addingTimeInterval(-age)
    for persisted in [nil, Data([9])] as [Data?] {
        UserDefaults.persisted = persisted
        precondition(!SpotifyResponsePatcher.shouldBlock(customize))
        precondition(SpotifyResponsePatcher.shouldModify(customize))
    }
}
precondition(SpotifyResponsePatcher.shouldBlock(URL(string: "https://spclient.wg.spotify.com/ads/v1/slot")!))
precondition(!SpotifyResponsePatcher.shouldBlock(bootstrap))

// Defaults notifications may synchronously reenter the cache getter.
var observerFired = false
UserDefaults.cacheWriteObserver = {
    precondition(SpotifyResponsePatcher.cachedCustomizeData == Data([8]))
    observerFired = true
}
SpotifyResponsePatcher.cachedCustomizeData = Data([8])
precondition(observerFired)
UserDefaults.cacheWriteObserver = nil

// Two real URLSessions both assign identifier 1 to their first task.
let s1 = URLSession(configuration: .ephemeral)
let s2 = URLSession(configuration: .ephemeral)
let t1 = s1.dataTask(with: customize), t2 = s2.dataTask(with: customize)
precondition(t1.taskIdentifier == t2.taskIdentifier)
SpotifyResponsePatcher.markCustomizeTaskHandled(t1)
precondition(!SpotifyResponsePatcher.consumeCustomizeTask(t2))
precondition(SpotifyResponsePatcher.consumeCustomizeTask(t1))
precondition(!SpotifyResponsePatcher.consumeCustomizeTask(t1))
s1.invalidateAndCancel(); s2.invalidateAndCancel()

// Never cache a server-error envelope as a successful configuration.
let good = try SpotifyResponsePatcher.patch(url: customize, buffer: Data([1]))!
precondition(good.data == Data([2]))
let serverError = try SpotifyResponsePatcher.patch(url: customize, buffer: Data([0]))
precondition(serverError == nil)
precondition(SpotifyResponsePatcher.cachedCustomizeData == good.data)
UserDefaults.patchType = .disabled
precondition(!SpotifyResponsePatcher.shouldModify(customize))
let disabled = try SpotifyResponsePatcher.patch(url: customize, buffer: Data([1]))
precondition(disabled == nil)
precondition(SpotifyResponsePatcher.cachedCustomizeData == good.data)
print("PASS configuration refresh: cold/disk-only cache, elapsed-time boundary, session identity, defaults reentry, error envelope, disabled patch")

UserDefaults.patchType = .requests
SpotifyResponsePatcher.cachedCustomizeData = nil
UserDefaults.persisted = Data([1])
var writes = 0
UserDefaults.cacheWriteObserver = { writes += 1 }
precondition(SpotifyResponsePatcher.customizeReplayData() == Data([2]))
precondition(UserDefaults.persisted == Data([2]) && writes == 1)
precondition(SpotifyResponsePatcher.customizeReplayData() == Data([2]) && writes == 1)
UserDefaults.cacheWriteObserver = nil
SpotifyResponsePatcher.cachedCustomizeData = nil
UserDefaults.persisted = Data([0])
precondition(SpotifyResponsePatcher.customizeReplayData() == nil)
precondition(UserDefaults.persisted == Data([0]))
UserDefaults.patchType = .disabled
UserDefaults.persisted = Data([1])
precondition(SpotifyResponsePatcher.customizeReplayData() == nil)
print("PASS persisted 304 migration: current rules applied once before replay, reentrant-safe persistence, invalid cache preserved, disabled mode respected")
