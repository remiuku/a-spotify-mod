import Foundation
import Dispatch

let mainKey = DispatchSpecificKey<Bool>()
DispatchQueue.main.setSpecific(key: mainKey, value: true)
var replies = [String: Int]()
var expiredProviderRan = false
var returnedImmediately = false
var heartbeat = false
func record(_ key: String, _ payload: Data, _ expected: String) {
    assert(DispatchQueue.getSpecific(key: mainKey) == true)
    assert(returnedImmediately)
    assert(payload == Data(expected.utf8), key)
    replies[key, default: 0] += 1
    assert(replies[key] == 1, "duplicate response")
}

DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
    fatalError("response deadlocked main or provider worker")
}
DispatchQueue.main.async {
    ASMLyricsResponseDelivery.resolve(original: Data("native".utf8), timeout: 2, load: {
        // This is the same dependency as reading MPNowPlayingInfoCenter from
        // a background provider. The URLSession caller must leave main free.
        DispatchQueue.main.sync { Data("custom".utf8) }
    }) { record("metadata", $0, "custom") }
    ASMLyricsResponseDelivery.resolve(original: Data("fallback".utf8), timeout: 2, load: { nil }) {
        record("failure", $0, "fallback")
    }
    ASMLyricsResponseDelivery.resolve(original: Data("timeout".utf8), timeout: 0.05, load: {
        Thread.sleep(forTimeInterval: 0.3)
        return Data("late".utf8)
    }) { record("slow", $0, "timeout") }
    ASMLyricsResponseDelivery.resolve(original: Data("queued".utf8), timeout: 0.05, load: {
        DispatchQueue.main.sync { expiredProviderRan = true }
        return Data("should not run".utf8)
    }) { record("queued", $0, "queued") }
    returnedImmediately = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { heartbeat = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        assert(heartbeat && !expiredProviderRan)
        assert(replies == ["metadata": 1, "failure": 1, "slow": 1, "queued": 1])
        print("PASS actual async lyric delivery: main-dependent metadata, responsive main queue, provider failure, timeout, late-result suppression, one ordered reply and expired queued-work cancellation")
        exit(0)
    }
}
dispatchMain()
