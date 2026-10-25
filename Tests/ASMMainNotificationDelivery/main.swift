import Foundation
import Dispatch

let center = NotificationCenter()
let prefs = Notification.Name("NSUserDefaultsDidChangeNotification")
let mainKey = DispatchSpecificKey<Bool>()
DispatchQueue.main.setSpecific(key: mainKey, value: true)
let player = DispatchQueue(label: "MobiusController Model regression")
var calls = 0
var lastSequence = -1
var postedFromMain = false
let handler: (Notification) -> Void = { note in
    assert(DispatchQueue.getSpecific(key: mainKey) == true)
    calls += 1
    lastSequence = note.userInfo?["sequence"] as? Int ?? -1
    if calls == 1 {
        assert(lastSequence == 999)
        // A new preference write while refreshing UI must not recurse.
        postedFromMain = true
        center.post(name: prefs, object: nil, userInfo: ["sequence": 1000])
        assert(calls == 1)
    }
}
let token: NSObjectProtocol = CommandLine.arguments.contains("--blocking-reference")
    ? center.addObserver(forName: prefs, object: nil, queue: .main, using: handler)
    : ASMMainNotificationDelivery.observe(forName: prefs, center: center, using: handler)
let ready = DispatchSemaphore(value: 0)
let releasePlayer = DispatchSemaphore(value: 0)
player.async {
    ready.signal()
    releasePlayer.wait()
    for sequence in 0..<1000 {
        center.post(name: prefs, object: nil, userInfo: ["sequence": sequence])
    }
}
DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
    fatalError("posting player queue waited for main notification delivery")
}
DispatchQueue.main.async {
    // Actual watchdog dependency: main waits for the player, which writes
    // preferences. A synchronous main OperationQueue observer deadlocks here.
    assert(ready.wait(timeout: .now() + 2) == .success)
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { releasePlayer.signal() }
    player.sync { } // wait for the already-running player thread, not inline work
    assert(calls == 0, "UI callback ran inside native preference write")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        assert(postedFromMain && calls == 2 && lastSequence == 1000)
        center.removeObserver(token)
        player.sync { center.post(name: prefs, object: nil) }
        DispatchQueue.main.async {
            assert(calls == 2)
            print("PASS actual notification delivery: main-waits-for-player dependency, 1000 preference posts return without main, coalesced UI delivery, recursive write deferral and observer removal")
            exit(0)
        }
    }
}
dispatchMain()
