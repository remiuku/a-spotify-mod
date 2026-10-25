# Playful effects regression tests

`fixtures.json` was generated directly from `Flow.float_of` and `Amll.emph_of` in gcoolL/mild-lyrics revision `257dce2cf696877fb50d8d3461ed4fae143adac8`. The source methods were extracted with Python AST, executed without Qt, and supplied a font metrics stub of height 30. The jelly fixtures use ASCII words, equal advance widths and both uniform short-word and held-note schedules, with the final-word multiplier on and off. The tests compare 24 flight states and 176 letter states.

The generator is saved alongside the local development workspace as `work/mild-playful-goldens.py`; the fixture file itself is included in the source patch and does not require the upstream checkout to run tests.

Additional cases check active-word spin through full turns, future/resting words, playback-driven pause/seek determinism, interlude departure order, independent viewport-based drift and boundary bounce, scroll independence, joined-script exclusion and Reduce Motion. These are animation-math tests; native glyph shaping, layout, touch and frame rate still need device validation.

No-gravity lifecycle regressions also cover release only after word completion, rejection of future/offscreen/history spawns, persistence without source anchors, stable coordinates when a source row scrolls, gradual retirement, pause/resume lifetime, seek reset/replay and bounded capacity without evicting existing bodies. The SwiftUI scene retains each admitted body's rendering payload until retirement; actual scrolling, rotation and visual smoothness still require a device check.
