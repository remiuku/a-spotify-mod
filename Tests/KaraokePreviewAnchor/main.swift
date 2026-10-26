import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
typealias I = KaraokePreviewAnchorPolicy.Index
func items(_ values: Int...) -> Set<I> { Set(values.map { I(0, $0) }) }

// Section 0: 0 artwork, 1 controls, 2 lyrics, 3 events, 4 about the artist, 5 credits.
func seen() -> KaraokePreviewAnchorPolicy.State {
    var state = KaraokePreviewAnchorPolicy.State()
    state.observe(lyrics: I(0, 2), visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false)
    return state
}

var state = seen()
check(state.replacing && state.lyrics == I(0, 2), "A visible lyrics card is replaced and its position recorded")
check(!state.observe(lyrics: nil, visible: items(3, 4, 5), counts: [6], replacedCellReconfigured: false) && state.replacing,
      "Scrolling the card away keeps replacement")

// Unrelated cards added or removed while the card is off screen.
state.apply([.insert(I(0, 6))])
check(!state.observe(lyrics: nil, visible: items(4, 5, 6), counts: [7], replacedCellReconfigured: false)
      && state.lyrics == I(0, 2), "An unrelated card inserted below does not move or revoke the card")
state.apply([.delete(I(0, 5))])
check(!state.observe(lyrics: nil, visible: items(3, 4), counts: [6], replacedCellReconfigured: false)
      && state.lyrics == I(0, 2), "An unrelated card removed below does not move or revoke the card")

state = seen()
state.apply([.insert(I(0, 0))])
check(!state.observe(lyrics: nil, visible: items(1, 2), counts: [7], replacedCellReconfigured: false)
      && state.lyrics == I(0, 3), "An insertion above shifts the card; its old index on screen is not evidence")
check(!state.observe(lyrics: I(0, 3), visible: items(2, 3), counts: [7], replacedCellReconfigured: false)
      && state.replacing && state.lyrics == I(0, 3), "Seeing the card again re-syncs its position")

// Review regression: one batch inserts before the card and removes a later card; the count is unchanged.
state = seen()
state.apply([.insert(I(0, 2)), .delete(I(0, 4))])
check(!state.observe(lyrics: nil, visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false)
      && state.replacing && state.lyrics == I(0, 3), "An equal-count insert/remove batch keeps the card pushed off screen")
check(state.observe(lyrics: nil, visible: items(2, 3), counts: [6], replacedCellReconfigured: false) && !state.replacing,
      "The followed index on screen without the card is evidence")

state = seen()
state.apply([.delete(I(0, 0)), .move(I(0, 4), I(0, 0))])
check(!state.observe(lyrics: nil, visible: items(0), counts: [5], replacedCellReconfigured: false)
      && state.lyrics == I(0, 2), "Deletes and moves around the card are followed")
state = seen()
state.apply([.move(I(0, 2), I(0, 5))])
check(!state.observe(lyrics: nil, visible: items(2, 3, 4), counts: [6], replacedCellReconfigured: false)
      && state.lyrics == I(0, 5), "A moved card is followed to its new index")
state = seen()
state.apply([.insertSection(0)])
check(state.observe(lyrics: nil, visible: [I(1, 2)], counts: [1, 6], replacedCellReconfigured: false) && !state.replacing,
      "An inserted section shifts the card's section; its new index on screen without it is evidence")

// Specific evidence that the card itself is gone.
state = seen()
state.apply([.delete(I(0, 2))])
check(state.observe(lyrics: nil, visible: items(4, 5), counts: [5], replacedCellReconfigured: false) && !state.replacing,
      "A reported delete of the card revokes even while it is off screen")
state = seen()
state.apply([.deleteSection(0)])
check(state.observe(lyrics: nil, visible: [], counts: [], replacedCellReconfigured: false) && !state.replacing,
      "Deleting the card's section revokes")
state = seen()
check(state.observe(lyrics: nil, visible: items(2, 3), counts: [6], replacedCellReconfigured: false) && !state.replacing,
      "With no updates, the card's own index on screen without it is evidence")
state = seen()
check(state.observe(lyrics: nil, visible: items(4), counts: [6], replacedCellReconfigured: true) && !state.replacing,
      "The replaced cell on screen hosting something else is evidence")

// Changes that can't be followed: no index-based evidence until a full sweep.
state = seen()
state.loseTrack()
check(!state.observe(lyrics: nil, visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false) && state.replacing,
      "After reloadData, the old index on screen is not evidence")
state = seen()
check(!state.observe(lyrics: nil, visible: items(0, 1, 2), counts: [7], replacedCellReconfigured: false)
      && state.replacing && !state.tracked, "Counts that don't match the reported updates untrack the card")
check(!state.observe(lyrics: nil, visible: items(3, 4, 5), counts: [7], replacedCellReconfigured: false) && state.replacing,
      "A partial sweep keeps replacement")
state.apply([.insert(I(0, 0))])
check(!state.observe(lyrics: nil, visible: items(0, 6), counts: [8], replacedCellReconfigured: false) && state.replacing,
      "Any change restarts the sweep")
check(!state.observe(lyrics: nil, visible: items(1, 2, 3, 4, 5), counts: [8], replacedCellReconfigured: false) && state.replacing,
      "One unseen item keeps replacement")
check(state.observe(lyrics: nil, visible: items(7), counts: [8], replacedCellReconfigured: false) && !state.replacing,
      "Every item seen without a lyrics card while nothing changed revokes")
state = seen()
state.loseTrack()
check(!state.observe(lyrics: I(0, 4), visible: items(3, 4), counts: [6], replacedCellReconfigured: false)
      && state.tracked && state.lyrics == I(0, 4), "Seeing the card again restores tracking")

state = KaraokePreviewAnchorPolicy.State()
state.apply([.delete(I(0, 2))])
check(!state.observe(lyrics: nil, visible: items(0, 1, 2), counts: [6], replacedCellReconfigured: false) && !state.replacing,
      "Nothing is revoked before a card was ever replaced")
print("PASS preview anchor: the card is followed through batch updates; only card-specific evidence revokes it")
