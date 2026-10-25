# Boykisserfication resources and behavior

Reference: user-supplied **Boykisserfication.zip**, extension manifest version
**0.67**, SHA-256
`a8ed2faebe7a6e3288ee6bbedac08533ba79dc5e26c56053b5a0a48b4d660dbe`.

- [Firefox extension page](https://addons.mozilla.org/en-US/firefox/addon/boykisserfication/)
- The supplied README credits [Spikerko](https://github.com/Spikerko) for the
  original idea and code, and [NaeNae](https://github.com/NaeNaeTart) for fixes
  and packaging as an extension.
- The ZIP does not identify individual image artists or include a LICENSE file.
  These source credits do not assert that the extension authors drew the images
  or assign a new licence to the upstream assets.

The native text port follows the inspected `content.js`: r/l conversion,
case-sensitive n/vowel and ove substitutions, 15% word stuttering, 50% decoration
after punctuation, the same twelve decorations, and a 70% trailing decoration.
Native rendering uses repeatable random choices to prevent playback redraws
from continually changing text or artwork. Clocks, numeric/symbol-only labels
and text-entry content are preserved. Timed lyric fragments use the base letter
rules without adding stutters/decorations to every individual syllable or letter.

Seven original WebP files were fetched from the exact URLs configured in the
extension, inspected, and bundled unchanged in `Boykisserfication/`:

1. https://static.spikerko.org/e/bk/1.webp
2. https://static.spikerko.org/e/bk/2.webp
3. https://static.spikerko.org/e/bk/3.webp
4. https://static.spikerko.org/e/bk/4.webp
5. https://static.spikerko.org/e/bk/5.webp
6. https://static.spikerko.org/e/bk/6.webp
7. https://static.spikerko.org/e/bk/7.webp

`Boykisserfication/origin.json` records each original URL, size and SHA-256.
Runtime images are drawn from these bundled files; the app does not contact
the image host. Variant 1 contains 137 animation frames. Large UIKit image views
can show a bounded 48-frame version of its loop; small icons and Reduce Motion
use its still frame. SwiftUI image and lyric background renderers use stills.
The native port, decoding, restoration and display adapters were implemented
locally; the extension's browser scripts are not installed or run in Spotify.
