# Album controls and lyric response delivery

The album header keeps its shuffle / Play / saved controls. Their native action
is forwarded on the next main turn, after the glass button's own activation.
Detached targets and references into the replacement row are rejected. Layout,
state synchronization and action dispatch reject synchronous reentry.

EeveeFireTap chooses one registered native event: primary activation when
available, otherwise touch-up-inside. It no longer sends both for one tap.
Controls without registered events can fall through to their actual tap gesture
or nested control. Gesture targets are snapshotted before dispatch so a native
navigation action cannot mutate the enumerated list. A thread-local guard
rejects recursive synthetic taps; UIKit actions stay on the main thread.

Both Spotify URLSession delegate hooks now return immediately for lyric
replacement. They never wait on a semaphore for a provider that may need main
for song metadata. A shared serial worker performs lookup; payload then native
completion are delivered together on main exactly once. An 18-second timeout
retains the native response, late provider replies cannot complete it again,
and queued work that has already timed out is skipped. Callback captures and
fallback bytes are released as soon as the response is delivered.

32 regression suites passed, including main-dependent metadata and a main-queue
heartbeat during a deliberately slow provider, timeout/late-result suppression,
expired queued work, single-event selection and 10000 reentrant tap attempts.
The full SDK/package report is separate. No device crash or watchdog trace has
been captured, so these fixes address verified code hazards; resolution of the
reported album freeze still needs testing in Spotify mode on the phone.
