# player preview update

Current local build: preview-stable 1, Spotify 9.1.94.

The preview uses custom lyric sources independently of Spotify's native lyrics
availability. It shows three rows using the existing Sweet word renderer, with
bounded font/fill/glow, pause/seek handling and reduced-motion support.

A positive-coordinate layout gap places it after player controls or at the
native lyrics card. Following attributes are copied and adjusted without
changing Spotify item counts, snapshots, scroll offsets or insets. Native
visibility is restored on reuse or when replacement is disabled.

The card has a fixed 236-point content area, three 50-point row slots and a
252-point reservation including spacing. Live SwiftUI height measurement was
removed after a phone run showed the reserved height changing during startup.
The embedded hosting view ignores window safe-area changes to avoid clipping
and reflow while scrolling.

Settings uses the existing :3 navigation button rather than inserting an extra
row and changing the native list during layout. Player declutter checks are
scoped to the player and no longer force nested collection layout during sizing.
These remove unsafe interactions; the exact earlier intermittent settings
assertion was not established and its elimination is not proven.

Validation: 37 personal-build regression suites, real iOS SDK compilation,
package/resource checks and full device-copy verification passed. The user
confirmed the preview is visible and accepted the latest update. Wider runtime
coverage remains incomplete. The publication runner skips the bootstrap test
because its private binary inputs are intentionally absent.

Credits and licence notices remain in CREDITS.md, LICENSING.md and the source
resources. No app IPA, SDK, signing/pairing material or device logs are included.
