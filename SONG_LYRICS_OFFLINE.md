# Song lyrics and offline library

## Controls

Open **Lyrics > Lyrics viewers > Song lyrics & offline**. In a custom lyric
viewer, holding the existing Sound button opens a context menu with the same
page. Normal tapping still opens audio controls; no new toolbar is added.

- Each Spotify song remembers an optional source, a -10 to +10 second offset,
  a Sweet translation target, and an explicit LRCLIB recording ID/label.
- Positive offset advances highlighting; lyric taps seek with the inverse
  adjustment. Eevee, Sweet, previews and imported custom viewers share this
  timing. Dancer tempo retains the raw audio clock.
- Choose another recording searches LRCLIB timed results and displays title,
  artist, album and duration. An explicit choice is fetched by its exact ID,
  not matched again by a title. Clearing it restores automatic matching.
  Search is an explicit online action. No timed match means no invented timing.
- Reset affects only the selected song. Audio, global sources, lyrics display
  choices and other songs remain unchanged.

## Offline content

Save current lyrics after opening the custom viewer and waiting for lookup.
The snapshot preserves syllables, overlap/backing vocals, translations and
pronunciation supplied by the source, writers, provider/maker/uploader metadata,
links and avatar URLs. Prepared machine translations are included if ready;
translations completing after a save update that saved song automatically.
Saving lyrics does not download audio, avatars or artwork.

Application Support/ASMLyricsOffline/v1 stores atomic, versioned JSON files,
limited to 100 songs, 50 MiB total and 2 MiB per song. Saves at the limit fail
visibly; explicit downloads are never silently evicted. Entries are removable
individually. Malformed files and path-unsafe track IDs are rejected.

The shared native/custom source loader uses a matching snapshot before any
metadata or lyric network request. A stable identity binds it to the effective
source, recording ID and provider configuration; mismatched snapshots stay in
Saved lyrics but are not played as the new selection. Mild source sets are
sorted for identities; fun effects and appearance don't invalidate downloads.
Timing and target-language edits don't invalidate the original lyric document.
Fetch fresh lyrics bypasses offline storage. Save again updates the download.
Prepared translation dictionaries are target-language and source-identity bound;
up to four languages per saved song. Source credits remain the originals.

## Translation display and screen sleep

Lyrics viewers has **Translation display - Sweet**: original, bilingual, or
translation only. Translation-only uses line-level timing and normal text for
the translated line; there are no invented word timings. A line without a usable
translation keeps its original text. Existing source/on-device translation
switches still control where translated text comes from. Original-only skips
on-device work. Language preparation remains an explicit setup action; automatic
translation cannot open download prompts. Saved machine translations can be
shown without repeating language downloads or inference.

Keep lyrics screen awake is optional, shared by full-screen custom viewers and
active only while a music song plays with lyrics visible and Spotify active.
Pause, dismissal and backgrounding release the request. A shared owner set
restores the previous idle-timer state when the last owner releases it.

## Dancing boykisser

All four user-provided media files are bundled unchanged. Advanced's small :3
row unlocks controls with a 1.5-second hold. Off by default. The dancer overlays
above pinned credits, freezes with playback and respects Reduce Motion.
Half-time, normal and double-time scale its song-tempo synchronization without
changing audio speed or overwriting per-animation beat calibration. Song tempo
uses available Spotify track/mix-cue metadata, otherwise the labelled manual
fallback. No general automatic BPM or downbeat availability is claimed.
See DANCING_BOYKISSER.md for measured loops, calibration and media provenance.

## This build also includes pending source changes

Compact two-row landscape credits; row-independent no-gravity word lifetimes;
silent opt-in installed-language translation in Sweet; custom-source player
preview replacing duplicate stock surfaces; and preserved Library/Search header
protection. These were previously source-only. Each needs real-phone validation.

## Validation and sources

Foundation regressions cover persistence, source/version identities, metadata
round-trip, translation isolation and storage bounds/corruption, inverse seeks,
recording parsing, old-settings migration, display fallback, all 32 wake-policy
states and half/double-time boundaries. The full source suite and device SDK
compile/package inspection are required for the release; they cannot confirm
phone layout, live LRCLIB connectivity or Spotify tempo availability.

LRCLIB API documentation: https://lrclib.net/docs
Existing LRCLIB repository transport is reused for /search?q= and /get/{id}.
No new third-party code/library was copied for these features. Existing project
licences and attribution are retained; new local behavior is described here.
