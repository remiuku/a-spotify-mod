# Boykisser mode

Tap the large `:3` at the top of the **a spotify mod** menu to enable or disable
the visual mode. Opening the menu through Spotify's `:3` entry still opens
settings normally. The header says how to restore the normal appearance.
The mode always starts off after restarting the app.

While enabled, supported visible labels use the supplied Firefox extension's
uwu rules, stutters and decorations. Images choose among its seven original
boykisser variants, bundled for offline use. Choices remain stable on redraw;
toggling off and on chooses a new seed. The native hooks cover UILabel and UIImageView, including
attributed labels, highlighted images and image attachments. Display adapters
also cover this patch's SwiftUI text, image and standard control labels, custom
lyrics, and lyric artwork backgrounds. Animated cover videos yield to the cat
image until the mode is disabled. This does not modify account data, typed text,
search queries, song identifiers, stored lyrics, timings or saved artwork.

Disabling restores each native view's latest original value and refreshes the
custom view roots. Text entry, keyboard views and their descendants are excluded.
Custom-drawn Spotify components that bypass UILabel/UIImageView may retain their
normal appearance; their behavior needs testing on the phone. The text transform
targets English/ASCII letters and preserves other UTF-8 bytes. Timed lyric
fragments use letter conversion without stutters or extra suffixes on each
individual letter/syllable. Numeric/symbol-only labels and clocks stay readable.

Variant 1 is animated. Large UIKit images can show its loop with at most 48
downsampled frames. Small icons and Reduce Motion show a still; changes to
Reduce Motion reapply the native image choice. SwiftUI images and shader
backgrounds use still frames. Original image dimensions and hit targets remain
unchanged; the source artwork fills the existing image rectangle.

## Inspiration and artwork

Based on the user-supplied **Boykisserfication.zip**, version 0.67, and
[boykisserfication for Firefox](https://addons.mozilla.org/en-US/firefox/addon/boykisserfication/).
The seven original WebP files replace the previous local placeholder drawing.
See `THIRD_PARTY_BOYKISSER.md` for the README's Spikerko/NaeNae credits, original
URLs, provenance and the native-port differences. The browser extension is not
installed or executed in Spotify.

## Validation status

The text tests compare 14 base outputs and 1,792 seeded outputs with the actual
function in the supplied extension. They also check UTF-8, stable redraws,
measurement/write agreement and buffer sentinels for capacities 0–95.
Platform build/package results are recorded with each release under eevee-dev.
Phone validation of image rendering, animation and restoration is still needed.
The earlier IPAs remain separate; this version uses
`a-spotify-mod-boykisser-extension-9.1.88.ipa`.

Phone check: toggle on, navigate Home/Search/Library and lyrics, change tracks,
check text input, toggle off and confirm the latest labels/covers return. Repeat
the toggle and restart the app to confirm the recovery path. Check button sizes,
lyric wrapping and seek/highlighting behavior with the longer transformed text.
