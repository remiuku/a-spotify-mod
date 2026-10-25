# Dancing boykisser

Open **Advanced**, then hold the small **:3** row at the bottom for 1.5 seconds.
The hidden page has an off-by-default master switch, animation picker, tempo
sync, manual/fallback BPM, per-animation beats per loop, and beat alignment.
It is separate from global Boykisserfication text/image replacement.

A noninteractive 64-point dancer (44 in landscape) sits at the right, 6 points
above the pinned credits. It is an overlay: no extra footer height or reduced
lyric viewport. The dancer is attached inside the full lyric surface, above the credits,
including the imported spoti.pw/Vitrine hosts. It does not depend on footer overflow. Credit text, links and pfps
remain unchanged. It is only present on ready custom lyric surfaces with credits.

## Supplied animation timing

| Selection | Frames | Original duration | Default beats/loop | Calibrated cadence |
| --- | ---: | ---: | ---: | ---: |
| Side-to-side dance | 52 | 4.16 s | 8 | 115.38 BPM |
| Tiny bounce | 25 | 0.50 s | 1 | 120 BPM |
| Explosion | 12 | 0.24 s | 1 | 250 BPM |
| Bounce GIF | 25 | 0.50 s | 1 | 120 BPM |

Duration is measured from actual frame delays. These media files have no
intrinsic musical BPM. Cadences assume the listed number of beats per loop,
which is adjustable for each animation. They are not a verified dance beat grid.
The fourth Discord attachment initially returned HTTP 404, then downloaded
successfully through the user's refreshed signed link on 2026-10-19. All four
choices are available. The three original animated WebP files and the GIF are
bundled unchanged; URLs,
SHA-256 hashes, sizes and attribution limits are in `DancingBoykisser/origin.json`.
The URLs did not identify their artists. These are user-provided media, not new
assets attributed to the Boykisserfication extension or an asserted new licence.
No Discord downloads occur while using the app. The signed download token is
not stored in the bundled provenance file. The GIF has a 48-by-364 transparent
canvas with a roughly 23-by-24 sprite. Runtime alpha bounds isolate that sprite
and compress its vertical travel into the 64-point overlay at a consistent
scale, preserving the original bounce phase without making the sprite tiny.
This is a display transform; the supplied GIF bytes remain unchanged.

## Song tempo and synchronization

Spotify's own Mix UI displays BPM/key for mixed playlists:
https://support.spotify.com/us/article/mixed-playlists/
New public Web API integrations cannot assume access to Audio Features/Analysis:
https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api

The supplied Spotify 9.1.88 binary confirms `SPTPlayerTrack.metadata` and the
`automix.fade_in_cuepoint.tempo` / `automix.fade_out_cuepoint.tempo` keys. The
observer reads that dictionary defensively only with the dancer enabled. It
accepts finite 30–300 BPM values from `tempoBpm`, `bpm`, `tempo`, then mix cues.
The first three are candidate field names; their population in player metadata
is not confirmed. Mix-cue tempo is explicitly labelled as such in settings,
not claimed as whole-track analysis. Values are bound to the actual observed
track and cleared on item changes. Queued lyrics lookups cannot supply tempo.
If metadata is absent, the Spicetify DJ Info 2.4.2 audio-features JSON lookup
is attempted with the existing native session. See THIRD_PARTY_DJ_INFO.md and
DJInfo-LICENSE.txt. Authorization and availability can vary; status shows
failure rather than claiming every song is supported. Successful tempo values
are cached for seven days, bounded to 128 tracks.

When enabled and local audio is playing, a second fallback captures 100 Hz
scalar onset strengths in a fixed C atomic ring through the existing output
tap. The original audio is never modified or stored. A utility worker analyzes
8-16 seconds of strengths with bounded autocorrelation once a second. Two
consistent results are needed, and estimates are explicitly labelled. Rate
conversion prevents applying playback speed twice. Remote Spotify Connect
audio cannot be analyzed. Silence or uncertain beats keep manual fallback.
No microphone or audio upload is used.

The current-song status shows the actual available source or says that manual
fallback is in use. This does not guarantee automatic BPM for every song, or
access to AI DJ internals. Metadata availability needs phone validation.

Animation phase derives from the shared playback position, so pause holds,
seeks select the corresponding frame and audio speed is applied once. Tempo
sync maps calibrated loop beats to song BPM; original-speed mode uses the real
loop duration. There is no verified downbeat map: a manual beat offset permits
alignment by ear. Reduce Motion holds the first frame, inactive scenes stop
animation, and there is no audio output modification or microphone access.
The original animation files are preserved alongside 114 composited PNG frames
and a validated duration/bounds manifest. PNG pixels are checked against each
original decoded frame. A utility queue decodes these independent frames with
a 6 MiB cache budget; the UIKit CALayer renderer preserves variable delays at
up to 30 Hz. It does not rely on animated-WebP thumbnail support or a conditional
SwiftUI task. CGImage rendering avoids global image substitution. Settings
include an always-mounted preview and a human-readable decode status.

## Validation

29 regression suites cover shared timing, pause/seek, metadata and DJ Info JSON
normalization, malformed/wrong-track responses, all nine 60-200 BPM synthetic
PCM cases through the actual C collector and Swift estimator, audio immutability,
visualizer coexistence and existing lyric/audio features. Original animation
hashes and all 114 composited pixels are verified. The full iOS SDK build and
IPA package report are recorded separately. Device rendering, real music
estimation and authenticated endpoint success still require phone validation.

## Completed final turn

The pinned side-to-side source still has its original 52 frames (4.16 seconds).
Playback appends its existing opposite-side pose from frame 44 after the last
back-facing pose, completing the final turn before restarting. This makes 53
pose intervals and a 4.24-second playback loop. All original artwork and frame
files remain unchanged. The hidden settings cadence uses the playback duration.
See DANCER_LOOP.md.
