import Foundation

/// Decides when the independent preview stops replacing the native lyrics card.
///
/// Ownership of a card can't be proven (Spotify may refill the same card view in place),
/// so a visible lyrics card is always replaced. Replacement is revoked only on evidence
/// about that specific item, never because unrelated cards were added or removed:
/// - the replaced cell is on screen but now hosts something else;
/// - its index path is on screen without a lyrics card, while nothing in its section
///   has been inserted or removed since it was last seen (so the index is still valid);
/// - every position the card could now occupy after the controls is on screen and
///   none of them is a lyrics card. The range widens by every possible insertion.
enum KaraokePreviewAnchorPolicy {
    struct Index: Hashable {
        let section: Int
        let item: Int
        init(_ section: Int, _ item: Int) { self.section = section; self.item = item }
    }

    struct State: Equatable {
        private(set) var replacing = false
        /// Where the card was last seen and the item counts at that moment.
        private(set) var lyrics: Index?
        private(set) var counts: [Int] = []
        /// Items between the controls and the card when both were seen in one section.
        private(set) var offsetFromControls: Int?
        /// Upper bound on items inserted into the card's section since it was seen.
        private(set) var possibleInserts = 0
        /// Any insertion or removal in the card's section (or a section-count change).
        private(set) var sectionChanged = false

        init() {}

        /// Feeds one layout pass. Returns true when replacement was revoked by this pass.
        @discardableResult
        mutating func observe(lyrics seen: Index?, controls: Index?, visible: Set<Index>,
                              counts current: [Int], replacedCellReconfigured: Bool) -> Bool {
            if let seen {
                replacing = true; lyrics = seen; counts = current
                possibleInserts = 0; sectionChanged = false
                if let controls, controls.section == seen.section, controls.item < seen.item {
                    offsetFromControls = seen.item - controls.item
                }
                return false
            }
            guard replacing, let last = lyrics else { return false }

            if current.count != counts.count || last.section >= current.count {
                sectionChanged = true
            } else {
                let before = counts[last.section], now = current[last.section]
                if now != before { sectionChanged = true }
                possibleInserts += max(0, now - before)
            }
            counts = current

            var removed = replacedCellReconfigured
            if !removed, !sectionChanged, visible.contains(last) { removed = true }
            if !removed, let offset = offsetFromControls, let controls, controls.section == last.section,
               controls.section < current.count {
                let first = controls.item + 1
                let last = min(controls.item + offset + possibleInserts, current[controls.section] - 1)
                // No position left after the controls, or every candidate is visible without the card.
                removed = first > last || (first...last).allSatisfy { visible.contains(Index(controls.section, $0)) }
            }
            if removed { self = State() }
            return removed
        }
    }
}
