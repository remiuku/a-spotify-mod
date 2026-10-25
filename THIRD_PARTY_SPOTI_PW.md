# spoti.pw adaptations in a spotify mod

Upstream: https://github.com/skopevoj/spoti.pw

Only the GPL-3.0 release **v0.21.1**, commit `a08b38b9e293f0893e92ff7a9b7b9d92f903431a`, is used. Copyright Vojtěch Škopek and the upstream contributors. Its complete GPL text is bundled as `SpotiPW-GPL-3.0.txt`. No code from the later PolyForm Strict revision is imported.

Adapted files under `Sources/EeveeSpotifyC/SpotiAudio/`:

- `SpeedPitch.m`, from `Shared/Player/SpeedPitch.x`: the mixer-to-RemoteIO input hook, pitch fallback, format handling and rate controls.
- `SGTimePitch.h/.m`, `SpeedPitch.h`: Apple's time/pitch Audio Unit wrapper.
- `Core/SGRebind.h/.m`: executable-only import rebinding.
- `JamesDSP.h`, `JamesDSPEngine.h`, `JamesDSP.m` (from `JamesDSP.x`), `JamesDSPSettings.m`, `JamesDSPFiles.m`, `SGDSPEngine.h/.m`: the realtime JamesDSP adapter, bounded configuration, file libraries, diagnostics and presets.

Local changes replace Logos startup/hooks with host adapters and an ABI-checked player-clock replacement, supply minimal logging/preferences helpers, namespace new preference keys under `asm.`, use `Documents/a spotify mod/JamesDSP`, clamp non-finite speed/pitch values, check time-pitch availability before enabling speed, and notify the host lyric clock at audio-rate boundaries. Audio Unit replacements are installed in a fixed order. The native SwiftUI control pages are local implementations. Default speed is 1, pitch is 0 and every DSP effect is disabled until selected.

The vendored library `vendor/libjamesdsp/` retains its original source paths, assets, licences and notices. Its upstream `README.md`, bundled as `JamesDSP-UPSTREAM-NOTICES.md`, records these origins:

- James Fung's JamesDSP engine: https://github.com/james34602/JamesDSPManager
- Audio4Linux/JDSP4Linux, commit `eb848bf507325ecbe765569d37c163d3b7c6fd11`: engine subtree and extensions, including ThePBone/JamesDSPManager's `extensions` branch.
- timschneeb/RootlessJamesDSP, commit `60d25ae8a53c6f4691c090673df290a73c6b6357`: 40 Liveprog scripts and three DDC presets. The upstream GPL-3.0 text is retained, as are individual source/asset notices. Convolver sample audio is not bundled.

The library Makefile accepts a Linux-hosted Apple cross-compiler and LLVM archive tool. A separate Linux headless test uses only a monotonic-clock shim around the actual C engine. This tests processing math and buffering, not iPhone Audio Unit hookup or sound quality.

The import rebinder also accepts Spotify's executable when LiveContainer loads
it as MH_DYLIB. It selects the exact guest path when available, or one unique
Spotify app executable, and never falls back to the LiveContainer host.
Startup retries retain existing hooks and avoid wrapping the player clock
twice. Speed/pitch selections remain queued when the output has not started;
the lyric-clock multiplier stays neutral until speed processing actually runs.
The native audio pickers use menus within the UIKit navigation host.

Cover styling follows the GPL release's approach of modifying only the cover inside the now-playing tilt view, while retaining native layout and controls. Configurable motion, strict album matching, Apple Music public-page video parsing, muted looping video, local album overrides and appearance save slots are local implementations. These original artwork controls remain local implementations. The independent interface modules now also include the GPL release's redesigned player and lyric renderer; see INTERFACES.md. Authentication, inspector, Live Activity and newer restricted spoti.pw code are not enabled by this port.

Apple Music / iTunes supply available video artwork from their public album pages and catalogue search. Original artwork remains owned by its respective rightsholders. The patch does not bundle those videos; it streams them when enabled. An exact normalized artist/album match is required for automatic lookup. Missing or changed metadata falls back to Spotify's still artwork.

EeveeSpotify Reincarnated remains the base patch. Its original notices, configuration keys and internal resource names are preserved. Sweet Lyrics, Mild Lyrics, lyric catalogue and build-tool credits are accessible in **Resources & credits** at the bottom of the settings menu. Renaming the personal patch does not imply endorsement by those projects or by Spotify/Apple.
