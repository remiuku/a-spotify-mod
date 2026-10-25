# Completed final dancer turn

Local build: dance-loop 1.

The original side-to-side WebP has all 52 frames, each 80 ms. Its final turn
ends front -> side -> back, then wraps directly to the starting front pose.
No bundled or shipped PNG was missing; all 52 source frames matched the last IPA.

For this exact source hash and frame count, the decoded playback sequence now
reuses frame 44 (zero-based), the opposite-facing side pose from the first full
turn, after frame 51. This closes front -> side -> back -> opposite side -> front.
It is an existing decoded bitmap reference, so no new image decode/allocation is
needed. All 52 original frames remain in order. Original media, frame manifest,
114 PNG resources and provenance hashes remain unchanged. Other dances are
untouched. A different source hash or frame count does not get this repair.

Playback now has 53 pose intervals and lasts 4.24 seconds at original speed.
The settings cadence uses that playback duration. The original file remains
4.16 seconds. With BPM synchronization, the completed loop still occupies the
configured number of beats; pause, seek and Reduce Motion retain the same clock.

The actual timing policy tests preserve source order, check the closing sequence
and its full frame interval, verify wrap-to-start and reject unrelated clips.
The final appearance still needs confirmation on the phone.
