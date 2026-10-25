# Spicy Lyrics Mobile pinned credit layout

Reference: https://github.com/spicylyrics/mobile
Inspected revision: d8feda5bca5cff1075e96c3fa347743d02757448.

The pinned footer adapts the contributor ordering/text policy and measurement ratios from app/src/main/java/com/tx24/spicyplayer/lyrics/spicy/models/ParsedLyrics.kt and lyrics/spicy/canvas/LyricsFooterRows.kt. These files are part of Spicy Lyrics Mobile under GNU AGPL-3.0. The original project and all contributors retain their copyright. Full terms are bundled as SpicyMobile-LICENSE.txt.

This implementation uses native SwiftUI/UIKit, keeping community/source/contributor rows outside the scrolling timeline in all four custom viewers. It preserves avatar/profile metadata from Spicy Lyrics, AMLL and Unison, original provider provenance through Mild blends, and genuine source-specific contributor roles. Songwriters remain in Eevee/Sweet's scrolling document. Source rows are never fabricated for missing data.

The reference font metadata identifies BlinkMacSystemFont / Apple's San Francisco family. The iOS implementation uses the native San Francisco system font at the reference weights; no Android font files are copied or bundled. Metrics: L=clamp(width*0.07,29.6,56), provider/contributor=0.34L*1.15, community=0.35L*1.15, circular avatar=1.4x contributor text, two-point avatar gap, five-percent horizontal insets. Provider alpha .55; community .65 bold; contributor prefix .6 and name .75, bold and underlined. The screenshot's block is pinned to the physical right edge, including RTL songs. Writer credits use their existing scroll placement.

Landscape adaptation: the compact footer groups source/community and contributors into two trailing-aligned rows, with a 3pt vertical gap and 10pt horizontal separation. Provider/community text is capped at 10.5pt, with avatars retaining the 1.4x text ratio. Portrait retains the reference measurements. Long names and source text may wrap rather than being removed.

Exact source wording: Provided by: <origin>; These lyrics have been provided by our community; Made by @<maker>; Uploaded by @<uploader> when there is a maker, otherwise Made by for Spicy community uploads or Submitted by for other catalogues. Missing avatars leave a reserved circular placeholder while an HTTPS image loads; absent avatar metadata adds no invented profile picture.

The viewer toolbar is removed. A compact circular Sound button sits beside the close button; viewer selection and presets stay in settings. Embedded viewers keep Quick sound in their options menu, without a viewer selector. Sweet's renderer-brand link remains credited through Resources & credits rather than duplicating labels at the lyric footer. Mild's Credits on top preference now places songwriter credits; the source/community footer remains pinned as requested.

Validation: the KaraokeCredits suite checks source parsing/casing, avatar propagation, exact labels/roles, blend provenance, missing-data behavior, profile/asset URL handling and sizing goldens. The queued footer/header changes are included in the Sweet pause candidate; see SWEET_PAUSE.md and pause-build-inspection.json. Final visual/rotation/link behavior requires phone verification.
