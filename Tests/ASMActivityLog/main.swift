import Foundation

let root = FileManager.default.temporaryDirectory.appendingPathComponent("asm-activity-test-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at: root) }
let store = ASMActivityLogStore(directory: root, limit: 64 << 10, pendingLimit: 32)
precondition(!store.isEnabled)
store.record("disabled", ["secret": "should never be written"])
precondition(!FileManager.default.fileExists(atPath: root.path))

func export(_ store: ASMActivityLogStore) -> Data {
    let done = DispatchSemaphore(value: 0)
    var data: Data?
    store.export { result in
        if case .success(let url) = result { data = try? Data(contentsOf: url) }
        done.signal()
    }
    precondition(done.wait(timeout: .now() + 5) == .success, "worker stalled")
    return data ?? Data()
}
func entries(_ data: Data) -> [[String: Any]] {
    data.split(separator: 10).map { try! JSONSerialization.jsonObject(with: Data($0)) as! [String: Any] }
}

store.setEnabled(true)
store.record("album.tap", ["button": "play"])
store.record("mod.error", ["message": "Bearer super-secret; access_token=private password=hidden https://person:pass@example.org/api?token=nope#hidden"])
store.record("redaction", ["message": #"{"access_token":"jsonsecret","password":"two word secret"}"#, "access_token": "fieldsecret"])
let first = export(store)
let firstText = String(decoding: first, as: UTF8.self)
for secret in ["super-secret", "private", "password=hidden", "token=nope", "person:pass", "jsonsecret", "two word secret", "fieldsecret"] {
    precondition(!firstText.contains(secret), "sensitive value survived: \(secret)")
}
precondition(firstText.contains("album.tap") && firstText.contains("https:\\/\\/example.org\\/api"))
precondition(entries(first).count == 4)
store.setEnabled(false)
store.record("after.disabled")
precondition(!String(decoding: export(store), as: UTF8.self).contains("after.disabled"))

// The real store, simultaneous producers, bounded pending memory and valid JSON
// after repeated rotation. Overflow is explicit rather than silently losing taps.
store.setEnabled(true)
DispatchQueue.concurrentPerform(iterations: 4000) { index in
    store.record("stress", ["index": String(index), "payload": String(repeating: "x", count: 400)])
}
let burst = entries(export(store))
precondition(burst.contains { $0["event"] as? String == "recording.dropped" })
for i in 0..<40 {
    for j in 0..<20 { store.record("rotation", ["index": "\(i)-\(j)", "payload": String(repeating: "y", count: 400)]) }
    _ = export(store)
}
let snapshot = export(store)
precondition(snapshot.count <= 2 * (64 << 10))
precondition(!entries(snapshot).isEmpty)
for name in ["activity-current.jsonl", "activity-previous.jsonl"] {
    let attributes = try! FileManager.default.attributesOfItem(atPath: root.appendingPathComponent(name).path)
    precondition((attributes[.size] as! NSNumber).intValue <= 64 << 10)
}

// Existing on-disk breadcrumbs survive creating a new recorder after relaunch.
let reopened = ASMActivityLogStore(directory: root)
precondition(!reopened.isEnabled && export(reopened) == snapshot)
let cleared = DispatchSemaphore(value: 0)
store.clear { result in
    if case .failure(let error) = result { preconditionFailure("clear failed: \(error)") }
    cleared.signal()
}
precondition(cleared.wait(timeout: .now() + 5) == .success)
precondition(export(store).isEmpty)
precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent("activity-export.jsonl").path))

var pulse = ASMActivityHeartbeat()
precondition(pulse.tick(at: 0) == .request)
precondition(pulse.tick(at: 1) == .none)
precondition(pulse.tick(at: 3) == .stalled)
for i in 4..<1000 { precondition(pulse.tick(at: Double(i)) == .none) }
precondition(pulse.complete(at: 1000) == 1000)
precondition(pulse.tick(at: 1001) == .request)
precondition(pulse.complete(at: 1001.1) == nil)
pulse.reset()
precondition(pulse.tick(at: 2000) == .request)
print("PASS activity recorder: off is inert, async export, secret redaction, 4000 concurrent events, overflow marker, bounded rotation, cross-launch persistence, clear and one-pulse stall/recovery")
