# Appearance presets

These are local settings recipes for a spotify mod. Neither spoti.pw's nor
Vitrine's full replacement interface is imported by this feature.

- Spotify: visual overrides off, stock accent, stock player background and cards.
- spoti.pw style: the existing glass surfaces and new-player flags, rounded
  covers, album-tinted bars, and album-following Home/Library/Search gradients.
- Vitrine style: the existing glass surfaces and new-player flags, black base
  surfaces, lime accent (#37F200), rounded covers, neutral bars, larger playlist
  covers with dividers, and fewer promotional/player/artist details.
- My current look: captures the user's appearance before the first switch.

The glass recipes require iOS 26+. They map ideas onto the existing Eevee-based
layout; page composition, animations and layouts do not exactly reproduce the
upstream interfaces. Animated/video covers remain off in factory recipes and
can be enabled separately for each saved style. No lyric viewer, provider,
lyric effect, audio processing, playback gesture, account token or feature-flag
setting is changed. Old numbered slots also restore only appearance keys.

Edits to the active style are saved when switching away. Returning restores
those edits. Reset this style restores its factory appearance only. Numbered
save slots remain available. Relaunch Spotify after switching: theme and hook
groups are selected once per process. Selecting a preset does not quit playback.

Appearance references (inspected source, no Vitrine code/assets copied):
- spoti.pw GPL v0.21.1, a08b38b9e293f0893e92ff7a9b7b9d92f903431a:
  https://github.com/skopevoj/spoti.pw/tree/v0.21.1
- Vitrine by Clone5030 and upstream My-Name-Is-Jeff, GPL-3.0,
  7c3067f65b8b11f56fcf4a0e12f3a70b8f0a9947:
  https://github.com/Clone5030/vitrine/tree/7c3067f65b8b11f56fcf4a0e12f3a70b8f0a9947
  The lime colour comes from SGRAccent.h; black surfaces and artwork/card
  styling are documented by SGRAmoled.x, SGRTokens.m and AGENTS.md.
