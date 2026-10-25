# Track-change notification watchdog fix

The iPhone report LiveContainer-2026-10-23-010134.ips records SIGKILL with
FRONTBOARD 0x8BADF00D: the process failed to exit gracefully after 5 seconds.
Main is blocked in Spotify's synchronous queue access. The MobiusController
Model queue is blocked in Foundation notification posting / NSOperation
waitUntilFinished, reached through the mod's notification probe and the
sideload defaults-write hook. The Eevee image UUID matches the previous
album-controls IPA: 4c4c44cf-5555-3144-a1bc-8d2da3e958b2.
This is a captured queue deadlock, not evidence of a Jetsam memory kill.

The player preview and dancer previously registered preference notifications
with OperationQueue.main. Foundation can synchronously wait for that queue
before returning to a background preferences writer. When main waits for
Spotify's player queue and that queue writes preferences, both queues wait.

ASMMainNotificationDelivery observes on the posting thread with queue:nil,
then asynchronously schedules UI work on the main dispatch queue. It never
waits for main, coalesces bursts into one current-state refresh and calls UI
code outside its short lock. Even a write from main is deferred so UIKit is
not entered recursively inside a preferences write. Existing notification
observer tokens still use the normal removal API.

The player preview and Sweet Lyrics' Combine preferences subscribers also
schedule/debounce their UI updates on main, avoiding background SwiftUI state
updates. Other lyric, audio and native control behavior stays in place.
Resources & credits identifies this candidate as Local build: track-change 1.

33 suites passed. The new regression runs the real background-player/main
queue dependency: the original OperationQueue.main registration deadlocks
and is stopped by the test harness; the asynchronous observer completes,
coalesces 1000 writes, defers a nested UI write and honors observer removal.
Full iOS SDK/package checks are recorded separately. A new phone run is still
required to confirm the reported Liked Songs freeze is resolved.
