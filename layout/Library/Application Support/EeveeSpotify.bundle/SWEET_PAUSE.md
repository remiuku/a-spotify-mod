# Sweet Lyrics pause fix and queued UI changes

This candidate includes the pending pinned credits and compact Sound control changes.

## Pause behavior
The Spotify 9.1.88 binary exposes isPaused (BOOL), isPlaying (BOOL), isLoading (BOOL), position (double), positionAsOfTimestamp (double), and playbackSpeed (double) on SPTPlayerState. The clock previously read only isPlaying and the computed position. The verified upstream player adapter explicitly uses positionAsOfTimestamp when isPaused is true.

The shared clock now gives pause/nonplaying/loading states precedence over an active playing/rate value, uses the stored positionAsOfTimestamp while held, and accepts a new stored timestamp for a seek while paused. Repeated paused callbacks with a computed position that keeps increasing cannot advance highlighting. Speed changes while paused preserve the held position. Resuming uses the live reported position and corrected audio rate. Missing state getters retain the compatible fallback; no new private selector is hooked.

Sweet samples playing state and position atomically each frame. Paused rendering disables presentation-latency lead while letting springs settle at the held word; seeking remains responsive. This also corrects paused clock reads for the other custom viewers and lock-screen lyrics.

## Included UI changes
- Source/community/maker/uploader credits pin at the bottom right, using Spicy Mobile's wording, font family/weights, spacing and circular profile pictures where supplied. See THIRD_PARTY_SPICY_CREDITS.md for exact ratios and provenance.
- The full-width lyric toolbar and in-view renderer picker are removed. Sound is a compact circular button next to close. Viewer selection and presets stay in settings; imported inline viewers keep Quick sound in their options menu.
- Sweet's extra renderer-brand footer is removed; project notices remain in Resources & credits.

## Verification
Regression coverage reproduces pause=true with playing=true and an increasing computed position, repeated paused callbacks, speed changes, paused seeks, resume, loading, missing getter fallbacks, and Sweet focus/lead behavior. Existing credit, metadata, source, audio-hook and interface regressions are retained. Build/package results are recorded in pause-build-inspection.json.

Phone verification is still required: play in Sweet Lyrics, pause for 10 seconds (current word/line must stay held), tap a later lyric while paused (it must jump there and stay), then resume (highlighting and following must move with the audio). Repeat at a changed speed. Confirm the pinned credits and header Sound icon, and that the bottom selector bar is absent. Import the new candidate as a LiveContainer update, preserving the previous IPA.
