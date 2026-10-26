import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
typealias I = KaraokePreviewAnchorPolicy.Index
func items(_ values: Int...) -> Set<I> { Set(values.map { I(0, $0) }) }

// Section 0: 0 artwork, 1 controls, 2 lyrics, 3 events, 4 about the artist, 5 credits.
func seen() -> KaraokePreviewAnchorPolicy.State {
    var state = KaraokePreviewAnchorPolicy.State()
    state.observe(lyrics: I(0, 2), controls: I(0, 1), visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false)
    return state
}

var state = seen()
check(state.replacing && state.lyrics == I(0, 2) && state.offsetFromControls == 1, "A visible lyrics card is replaced and its position recorded")
check(!state.observe(lyrics: nil, controls: nil, visible: items(3, 4, 5), counts: [6], replacedCellReconfigured: false) && state.replacing,
      "Scrolling the card away keeps replacement")

// Regression: unrelated cards added or removed while the card is off screen.
check(!state.observe(lyrics: nil, controls: nil, visible: items(4, 5, 6), counts: [7], replacedCellReconfigured: false) && state.replacing,
      "An unrelated card inserted off screen does not revoke replacement")
check(!state.observe(lyrics: nil, controls: nil, visible: items(3, 4), counts: [5], replacedCellReconfigured: false) && state.replacing,
      "An unrelated card removed off screen does not revoke replacement")
check(!state.observe(lyrics: nil, controls: nil, visible: items(2, 3), counts: [6], replacedCellReconfigured: false) && state.replacing,
      "After the section changed, the old index on screen is not evidence the card is gone")

state = seen()
// An unrelated card inserted above the controls shifts both: controls 2, card 3.
check(!state.observe(lyrics: nil, controls: I(0, 2), visible: items(1, 2), counts: [7], replacedCellReconfigured: false) && state.replacing,
      "An insertion above the controls doesn't revoke replacement while the card's new position is off screen")
check(!state.observe(lyrics: I(0, 3), controls: I(0, 2), visible: items(2, 3), counts: [7], replacedCellReconfigured: false)
      && state.replacing && state.lyrics == I(0, 3), "Seeing the card again re-syncs its position")

state = seen()
// An unrelated card inserted between the controls and the card: card moves to 3.
check(!state.observe(lyrics: nil, controls: I(0, 1), visible: items(0, 1, 2), counts: [7], replacedCellReconfigured: false) && state.replacing,
      "The candidate range widens by possible insertions, so a card pushed just off screen is kept")

// Specific evidence that the card itself is gone.
state = seen()
state.observe(lyrics: nil, controls: nil, visible: items(3, 4), counts: [5], replacedCellReconfigured: false)
check(state.observe(lyrics: nil, controls: I(0, 1), visible: items(0, 1, 2), counts: [5], replacedCellReconfigured: false) && !state.replacing,
      "Card removed off screen: every position it could occupy after the controls is visible without it")
state = seen()
check(state.observe(lyrics: nil, controls: nil, visible: items(2, 3), counts: [6], replacedCellReconfigured: false) && !state.replacing,
      "With the section unchanged, the card's own index on screen without it is evidence")
state = seen()
check(state.observe(lyrics: nil, controls: nil, visible: items(4), counts: [6], replacedCellReconfigured: true) && !state.replacing,
      "The replaced cell on screen hosting something else is evidence")
state = seen()
check(state.observe(lyrics: nil, controls: I(0, 1), visible: items(0, 1), counts: [2], replacedCellReconfigured: false) && !state.replacing,
      "No position left after the controls means the card is gone")
state = KaraokePreviewAnchorPolicy.State()
check(!state.observe(lyrics: nil, controls: I(0, 1), visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false) && !state.replacing,
      "Nothing is revoked before a card was ever replaced")
print("PASS preview anchor: unrelated insertions/removals keep replacement; only card-specific evidence revokes it")
