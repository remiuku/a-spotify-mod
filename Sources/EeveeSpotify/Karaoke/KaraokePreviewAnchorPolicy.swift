import Foundation

/// Decides when the independent preview stops replacing the native lyrics card.
///
/// Ownership of a card can't be proven (Spotify may refill the same card view in place),
/// so a visible lyrics card is always replaced. Item counts can't prove that nothing was
/// inserted (one batch may insert and remove), so the card's index is followed through the
/// native batch updates themselves. Replacement is revoked only on evidence about that card:
/// - a reported update deleted the card (or its section);
/// - the replaced cell is on screen but now hosts something else;
/// - the card's tracked index is on screen without a lyrics card.
/// When a change can't be followed (reloadData, or counts that don't match the reported
/// updates), the index is untracked; replacement is then revoked only after every item has
/// been seen without a lyrics card while nothing changed.
enum KaraokePreviewAnchorPolicy {
    struct Index: Hashable {
        let section: Int
        let item: Int
        init(_ section: Int, _ item: Int) { self.section = section; self.item = item }
    }

    /// One native batch-update item. Deletes and reloads use indices from before the
    /// batch, inserts use indices after it, and moves go from before to after.
    enum Update: Equatable {
        case insert(Index), delete(Index), reload(Index), move(Index, Index)
        case insertSection(Int), deleteSection(Int), reloadSection(Int), moveSection(Int, Int)
    }

    struct State: Equatable {
        private(set) var replacing = false
        /// The card's current index; nil while replacing means the index is untracked.
        private(set) var lyrics: Index?
        /// Expected item count of the card's section, when known.
        private(set) var sectionCount: Int?
        /// A reported update deleted the card.
        private(set) var deleted = false
        /// Untracked: items seen without a lyrics card while the counts stayed `sweepCounts`.
        private(set) var swept: Set<Index> = []
        private(set) var sweepCounts: [Int] = []

        init() {}

        var tracked: Bool { lyrics != nil }

        /// Feeds one native batch update, as reported to the layout.
        mutating func apply(_ updates: [Update]) {
            guard replacing else { return }
            swept = []
            guard let card = lyrics else { return }
            var section = card.section, item = card.item, count = sectionCount
            if updates.contains(.deleteSection(card.section)) || updates.contains(.delete(card)) { deleted = true; return }
            if updates.contains(.reloadSection(card.section)) { loseTrack(); return }
            if updates.contains(where: { if case .moveSection(let from, let to) = $0 { return from == card.section || to == card.section } else { return false } }) {
                loseTrack(); return
            }

            // Sections: rank among surviving sections, then shift past inserted ones.
            section -= updates.filter {
                switch $0 {
                case .deleteSection(let s), .moveSection(let s, _): return s < card.section
                default: return false
                }
            }.count
            for target in updates.compactMap({ (update: Update) -> Int? in
                switch update {
                case .insertSection(let s), .moveSection(_, let s): return s
                default: return nil
                }
            }).sorted() where target <= section { section += 1 }

            if let moved = updates.lazy.compactMap({ (update: Update) -> Index? in
                if case .move(card, let to) = update { return to } else { return nil }
            }).first {
                lyrics = moved; sectionCount = nil; return
            }

            // Items: rank among surviving items of the old section, then shift past
            // items inserted or moved into the new section at or before that position.
            let leaving = updates.compactMap { (update: Update) -> Int? in
                switch update {
                case .delete(let index), .move(let index, _): return index.section == card.section ? index.item : nil
                default: return nil
                }
            }
            let arriving = updates.compactMap { (update: Update) -> Int? in
                switch update {
                case .insert(let index), .move(_, let index): return index.section == section ? index.item : nil
                default: return nil
                }
            }.sorted()
            item -= leaving.filter { $0 < card.item }.count
            for target in arriving where target <= item { item += 1 }
            count = count.map { $0 - leaving.count + arriving.count }
            lyrics = Index(section, item); sectionCount = count
        }

        /// A change that can't be followed, such as reloadData.
        mutating func loseTrack() {
            guard replacing else { return }
            lyrics = nil; sectionCount = nil; swept = []
        }

        /// Feeds one layout pass. Returns true when replacement was revoked by this pass.
        @discardableResult
        mutating func observe(lyrics seen: Index?, visible: Set<Index>, counts: [Int],
                              replacedCellReconfigured: Bool) -> Bool {
            if let seen {
                self = State()
                replacing = true; lyrics = seen
                sectionCount = seen.section < counts.count ? counts[seen.section] : nil
                return false
            }
            guard replacing else { return false }

            var revoked = deleted || replacedCellReconfigured
            if !revoked, let card = lyrics {
                if card.section >= counts.count || (sectionCount.map { $0 != counts[card.section] } ?? false) {
                    // Counts moved without matching updates: something wasn't reported.
                    loseTrack()
                } else if visible.contains(card) {
                    revoked = true
                }
            }
            if !revoked, lyrics == nil {
                if counts != sweepCounts { swept = []; sweepCounts = counts }
                swept.formUnion(visible)
                revoked = counts.enumerated().allSatisfy { section, count in
                    (0..<count).allSatisfy { swept.contains(Index(section, $0)) }
                }
            }
            if revoked { self = State() }
            return revoked
        }
    }
}
