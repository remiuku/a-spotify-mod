# Interfaces and lyrics viewers

Look & feel > Interface selects Spotify, spoti.pw or Vitrine. Restart Spotify to
change the interface. The two overhauls require iOS 26. Their classes, C symbols,
selectors, notifications and preferences have separate namespaces. Only the
selected overhaul installs its screen hooks; Eevee's native screen hooks are
held off while an overhaul is running.

Lyrics > Lyrics viewers independently selects Spotify, Eevee, Sweet Lyrics,
spoti.pw or Vitrine. Each custom viewer has a settings link on that page. Sweet
keeps Mild's display and playful controls. Source order, blending, audio and
account settings are not changed by either selector. Spotify's own viewer still
depends on Spotify providing a native page; custom viewers use the independent
lookup, including its loading, missing and retry states.

The actual upstream redesigned screen implementations and UIKit lyric renderers
are included, not only appearance presets. The older appearance recipes and
saved look slots remain for Spotify's native interface.

Pinned sources (GPL-3.0):

* spoti.pw v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a
* Clone5030/vitrine, 7c3067f65b8b11f56fcf4a0e12f3a70b8f0a9947

The complete imported source and licences are in modules/ASMInterfaces. The
source copies retain their original layer structure and run their upstream
layer checks. App/onboarding/updater hooks and unrelated shared features are
inactive. Our existing simplified menu owns settings navigation. Our existing
LiveContainer-compatible speed/pitch and JamesDSP engine owns audio; Vitrine's
visualizer reads that output without changing it. Its neural vocal separator,
experimental lossless replacement and separate audio engine are not enabled.
The imported player menu's audio action opens our working Sound page.

Both renderers receive the host's raw word/line timing and validated seeks.
Source-specific translation/pronunciation metadata that the host's lyric model
does not carry is unavailable; their controls cannot create such source data.
Maker/uploader/provider credits stay visible in the shared overlay footer.

Build checks establish compilation, packaging, mode policy and persistence.
Phone layout, gestures and rendering must be confirmed in LiveContainer. Keep
the previous menu build available until this candidate has been tried.
