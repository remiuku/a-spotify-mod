# Custom lyrics in the player and header protection

**Lyrics → Lyrics viewers → Use custom lyrics in the player** controls the
replacement. It defaults on for custom viewers and preserves older preferences.
Selecting Spotify, disabling custom lyrics/the replacement, using an unsupported
source or playing a non-music item restores the native surfaces. Imported
spoti.pw/Vitrine interfaces retain their own player integration.

The stock player lyrics card is replaced in place with a lightweight custom-source
preview: nearby lines follow the shared playback clock, including pause and seeks.
Tap the card to open the currently selected full viewer (Eevee, Sweet, spoti.pw or
Vitrine). It uses the same cached/coalesced lookup model as the full-screen view.
The duplicate Canvas lyric overlay is hidden and the native inline lyrics
container below the artwork is collapsed, preserving its last native visibility
request for restoration. The independent
Custom Lyrics shortcut remains available on songs for which Spotify does not
create a card. A missing native card is not fabricated by modifying Spotify's
private collection data source.

The preview is deliberately small: three context lines and line highlighting,
without another full renderer, credits footer, toolbar, translation task or audio
engine. Opening the full viewer provides its normal effects and controls.
Native card children, tap recognizers, visibility, interaction and accessibility
state are saved and restored; scrolling gestures remain enabled. Hosting
controller containment and teardown follow the card's window lifecycle.

The Library/Search gradient header correction no longer clears arbitrary sibling
header fills or hides their gradient scrims. Only the scrolling list's ancestor
backgrounds are cleared for the wash. Native top-edge effects remain visible and
the list clips to its bounds, protecting pinned titles/filter chips from scrolled
rows. The Home-specific styling path is preserved.

The existing classes were confirmed in the supplied Spotify 9.1.88 binary:
Lyrics_CardElementImpl.CardView, Canvas_CommonImpl.CanvasNowPlayingLyricsView,
Lyrics_NPVContainerKit.LyricsContainerView, and
YourLibrary_YourLibraryXImpl.YourLibraryViewController. Hooks use UIView
layout/window/visibility lifecycle methods; no new private navigation selector is invoked.

Validation: the 24 existing regression suites pass and the new player-preview
suite passes after correcting its localization test stub. The real preview UI,
Sweet renderer, no-gravity scene and translation settings typecheck against the
iOS 27.1 SDK at a 16.1 deployment target, with unrelated host adapters stubbed.
Edited hook/header source parses and new hooks pass Orion preprocessing. No IPA was built. Verify on the phone: Library
scrolling at the top, one custom card, correct song after a skip, pause/seek,
tap-to-open without also opening native lyrics, Spotify/off restoration, and
tracks with no native lyric card. Actual header/layout behavior is unconfirmed.
