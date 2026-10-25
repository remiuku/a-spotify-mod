# Simplified mod menu

The main menu now has five entries. All feature pages retain their controls,
preference keys, defaults and stored values. No automatic reset or preset is
applied by this navigation change.

- Lyrics: original source/renderer controls; Fun lyrics effects; Lyric display
  & motion (Text, Motion, Background, Timing); Lyric sources & blends; Lyric colours.
- Sound & playback: complete speed/pitch and JamesDSP controls, plus SponsorBlock.
- Look & feel: Style presets and saved looks; Theme & colours; Cover artwork;
  Layout (Player, Now playing bar, Tab bar, Home, Playlist, Artist).
- Advanced: Patching; Spotify features; Flags; Experiments; Privacy & links;
  Troubleshooting (common issues, logs and export); Reset (both original reset
  actions, with their existing confirmations).
- About & credits: existing version, project resources, lyric catalogues,
  notices, licences, contributor/dev notes and support links.

Theme & colours keeps the background colour and Liquid glass surface pages,
adds the existing accent palettes and App icon entry, and owns Dark popups.
Lyric colours keeps all three legacy lyric-colour controls. Style presets no
longer repeats the theme/layout/cover links. Saved looks keep their original
numbered slots and appearance-only storage.

Fun lyrics effects exposes the existing four independent controls: Word spin,
No gravity, Float away and Jelly lines. It also exposes the shared Mild master
switch so these effects can be enabled directly. Reset Mild controls remains
in Lyric display & motion and retains its existing reset-all behavior.

These are the full native settings pages, not the reduced controls used by the
interactive menu preview. Navigation uses the existing UIKit SettingsNavigator.
Mild pickers use menus, and source-priority handles remain editable in the
source page. The :3 visual mode and the existing settings hero are retained.
