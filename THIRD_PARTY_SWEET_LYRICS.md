# Sweet Lyrics for iOS integration

The custom renderer imports native Swift code from [Sweet Lyrics for iOS](https://github.com/sppqq/sweet-lyrics-ios), by sppq, revision `90c10d785d3187258b8cb6e3e63b790ff4900da5`. Original tester: nie4ick. It derives from Spicy Lyrics by Spikerko and contributors. Imported renderer code is AGPL-3.0; EeveeSpotify's existing GPL-3.0 license is retained. Full upstream terms and shared renderer ancestry notices are bundled in `EeveeSpotify.bundle/SweetLyrics-LICENSE.txt`.

Files were modified on October 17, 2026. Types and global helpers receive a `Sweet` prefix to avoid collisions inside Spotify. See `Sources/EeveeSpotify/Karaoke/SweetLyrics/`:

| Upstream file | Local adaptation |
| --- | --- |
| `Rendering/Spring.swift`, `Easing.swift` | Original spring, spline and easing implementations, namespaced |
| `Rendering/LyricsAnimator.swift` | Original per-frame animation state machine; empty-input guard; focus handles backing rows before their lead; CoreFoundation import for Linux logic tests |
| `Rendering/LyricsLineView.swift` | Original native word/letter layout, fills, glow, blur, backing rows and interlude dots |
| `Lyrics/LyricsModels.swift` | Original render preparation, word grouping and emphasis; romanization reads the already prepared host text instead of importing a second romanization pipeline |
| `Background/ShaderSurface.swift`, `KawarpBackground.swift`, `Shaders.metal` | Original low-resolution background and CPU cover blur; shader loads from the host resource bundle at runtime |
| `Support/MediaClock.swift` | Original display clock |
| Local `SweetLyricsAdapter.swift` | Maps Eevee's lyric DTO and credits into Sweet's model, preserving original overlapping timing and separate backing groups |
| Local `SweetLyricsOverlayView.swift` | Hosts the imported renderer with Eevee's player clock, guarded seek, source fetching, dismissal, settings, header and credits |
| Local `SweetFrameMetrics.swift` | Records periodic render callback rate and long gaps to diagnose injected-host refresh issues |

The host passes each frame's `visuals` value into the row closure, as upstream does. It uses a periodic clock and actual application lifecycle notifications in place of the standalone app's animation/scene lifecycle. This update addresses a user-reported case where only highlighting advanced roughly once every five seconds; on-phone confirmation remains required.

The standalone app's OAuth, Web API/App Remote player, translation services, cloud server, reporting, onboarding, updates, PiP, external-display scenes and imported-font manager are not included. This integration uses Eevee's existing providers and local player observer. It does not require a second Spotify login or client ID.

The superseded Android-derived implementation is archived outside the build at `../eevee-dev/archive-spicy-mobile/`. The current renderer picker contains Eevee and Sweet Lyrics; saved `spicyMobile` preferences migrate to `sweetLyrics`.
