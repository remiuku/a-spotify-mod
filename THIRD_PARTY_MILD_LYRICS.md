# Mild Lyrics integration

Upstream: https://github.com/gcoolL/mild-lyrics

Pinned revision: `257dce2cf696877fb50d8d3461ed4fae143adac8`.

Copyright gcoolL and the Mild Lyrics contributors. Mild Lyrics is GNU AGPL-3.0-or-later, with its AMLL-derived portions AGPL-3.0-only. The complete license and upstream third-party notices are included as `MildLyrics-LICENSE.txt` and `MildLyrics-UPSTREAM-NOTICES.md` in the application resource bundle.

The native additions in `Lyrics/MildLyrics/`, `MildRenderPolicy.swift`, `MildLyricsSettingsView.swift`, and `MildQRC.c` adapt the source registry, source endpoints, QRC decoder, difflib-style alignment, timing relay and settings concepts from Mild Lyrics. They do not embed Python or Qt. Rendering uses the previously credited Sweet Lyrics native engine, with native style variants and controls; the eight style names do not imply pixel-identical ports of the Qt renderers. Source matching is deliberately strict about title, artist and known duration.

Modifications: Swift models and settings persistence; native networking; bounded zlib decoding; the QQ codec port in C; text-preserving blending with line matching and regrouping; Spotify playback/seek integration; reduced-motion-aware native effects. Existing Eevee/Sweet settings and source numeric IDs are preserved. The iOS source checkout and distributable source patch accompany the test IPA.

`Karaoke/SweetLyrics/MildPlayfulEffects.swift` additionally adapts timed spin and float-away from `Flow.spin_frag`, `float_of` and `dot_flights`; the per-letter jelly schedule from `Amll.emph_of`; and word drift/bouncing from `LyricsView.drift_of` and `step_drift`. The jelly emphasis is among the AMLL-derived AGPL-3.0-only portions. Native SwiftUI word containers and a separate viewport overlay replace the desktop painter's drawing/masking machinery. Unit fixtures execute the original float/jelly functions at the pinned revision; drift uses a deterministic native seed instead of Python's process-specific hash.

Sweet's TTML parser is separately adapted and credited in `THIRD_PARTY_SWEET_LYRICS.md`. Android provider files were consulted as secondary format references; native providers use the endpoints and format rules verified in the pinned Mild source. No desktop player, OAuth server, Qt UI or Discord code is imported.

Native no-gravity lifecycle adaptation: active/future words remain in the lyric line. Completed words can release from their visible source positions within a short admission window; offscreen/history rows cannot spawn bodies at viewport edges. Each floating copy retains its drawing data independently of lazy scrolling rows, with a bounded pool and an eight-second playing lifetime (last two seconds fade). Pause holds motion and lifetime; lyric seeks, detected playback jumps, track changes and background teardown clear the scene. Physics directions are reflected inward at edges. This lifecycle is a native readability/performance change, not a claim of identical desktop behavior.
