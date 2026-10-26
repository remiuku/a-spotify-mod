import UIKit

/// A positive-coordinate layout gap; native item counts and scroll insets stay intact.
@available(iOS 15.0, *)
enum KaraokeIndependentPreview {
    private static var hostKey: UInt8 = 0
    private static var nativeFrameKey: UInt8 = 0
    private static var reuseKey: UInt8 = 0
    private final class WeakHost {
        weak var value: Host?
        init(_ host: Host) { value = host }
    }
    private static let roots = NSHashTable<UIViewController>.weakObjects()
    private static let pending = NSHashTable<UIViewController>.weakObjects()
    private static var scheduled = false

    private final class Host {
        weak var list: UICollectionView?
        let view = UIView()
        let content = KaraokePlayerCardHost()
        let height = CGFloat(KaraokePlayerPreviewPolicy.contentHeight)
        var seam: CGFloat?
        var occupied: CGFloat = 0
        weak var nativeCell: UICollectionViewCell?
        var nativeAlpha: CGFloat = 1
        var nativeInteractive = true
        var nativeAccessibility = false
        // Anchor mode never flips because a cell left `visibleCells`.
        // true: native lyrics card replaced; false: gap under controls.
        var latchedReplacing: Bool?
        // Ownership of a lyrics card can't be proven (Spotify may refill the same card view
        // in place), so any visible lyrics card is replaced and kept hidden: the preview never
        // sits beside a revealed native card. Replacement is revoked only when Spotify removes
        // the card: its slot is on screen without one, or the item set changed while it was off.
        var replacedIndex: IndexPath?
        var itemSignature: [Int] = []
        var reservation: CGFloat { CGFloat(KaraokePlayerPreviewPolicy.headerReservation(contentHeight: Double(height))) }
        var delta: CGFloat { seam == nil ? 0 : reservation - occupied }
        init(_ list: UICollectionView) { self.list = list }
        func restoreCell() {
            nativeCell?.alpha = nativeAlpha
            nativeCell?.isUserInteractionEnabled = nativeInteractive
            nativeCell?.accessibilityElementsHidden = nativeAccessibility
            if let cell = nativeCell { objc_setAssociatedObject(cell, &reuseKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            nativeCell = nil
        }
        func update() {
            guard let list else { return }
            let previousSeam = seam, previousDelta = delta
            let cells = list.visibleCells
            let controlIDs: Set<String> = ["SPTNowPlayingPlayButton", "QueueButtonNowPlaying", "ShareButtonNowPlayingView", "Components.ConnectButtonOutputSwitcher"]
            func hasControls(_ cell: UICollectionViewCell) -> Bool {
                cell.eeveeFirst(UIView.self, where: { controlIDs.contains($0.accessibilityIdentifier ?? "") }) != nil
            }
            // Never replace a cell that also hosts playback controls; hiding it would disable them.
            let lyrics = cells.first { $0.eeveeContainsClass("Lyrics_CardElementImpl") && !hasControls($0) }
            let controls = cells.filter(hasControls).max { first, second in
                func bottom(_ cell: UICollectionViewCell) -> CGFloat {
                    guard let index = list.indexPath(for: cell), let attributes = list.collectionViewLayout.layoutAttributesForItem(at: index) else { return 0 }
                    return KaraokeIndependentPreview.nativeFrame(attributes).maxY
                }
                return bottom(first) < bottom(second)
            }
            let signature = (0..<list.numberOfSections).map { list.numberOfItems(inSection: $0) }
            if let lyrics, let index = list.indexPath(for: lyrics) {
                // A native lyrics card is a one-way upgrade; scrolling it offscreen keeps the mode.
                latchedReplacing = true; replacedIndex = index; itemSignature = signature
            } else if latchedReplacing == true {
                // Scrolled away: slot off screen and item set unchanged, so keep the geometry.
                // Removed: slot on screen without a lyrics card, or items changed while it was off.
                let slotVisible = replacedIndex.map { list.indexPathsForVisibleItems.contains($0) } ?? false
                if slotVisible || signature != itemSignature {
                    // The card is gone: keep the preview at its old seam as a plain gap
                    // (nothing native is revealed) until the controls can anchor it.
                    latchedReplacing = nil; replacedIndex = nil; restoreCell(); occupied = 0
                    ASMActivityRecorder.store.record("preview.gap_unlatched", ["slot_visible": String(slotVisible)])
                }
            }
            if latchedReplacing == nil, controls != nil { latchedReplacing = false }
            let anchor: UICollectionViewCell? = latchedReplacing == true ? lyrics : (latchedReplacing == false ? controls : nil)
            if let anchor, let index = list.indexPath(for: anchor),
               let attributes = list.collectionViewLayout.layoutAttributesForItem(at: index) {
                let frame = KaraokeIndependentPreview.nativeFrame(attributes)
                let replacing = latchedReplacing == true
                seam = replacing ? frame.minY : frame.maxY
                occupied = replacing ? frame.height : 0
                if replacing && nativeCell !== anchor {
                    restoreCell()
                    nativeCell = anchor
                    objc_setAssociatedObject(anchor, &reuseKey, WeakHost(self), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    nativeAlpha = anchor.alpha
                    nativeInteractive = anchor.isUserInteractionEnabled
                    nativeAccessibility = anchor.accessibilityElementsHidden
                } else if !replacing { restoreCell() }
            }
            guard let seam else { return }
            if let cell = nativeCell, !cell.eeveeContainsClass("Lyrics_CardElementImpl") { restoreCell() }
            if let nativeCell, let native = nativeCell.eeveeFirst(UIView.self, where: { NSStringFromClass(type(of: $0)).contains("Lyrics_CardElementImpl") }) {
                KaraokePlayerSurfaces.updateCard(native)
            }
            nativeCell?.alpha = 0
            nativeCell?.isUserInteractionEnabled = false
            nativeCell?.accessibilityElementsHidden = true
            if view.superview !== list {
                list.addSubview(view)
                ASMActivityRecorder.store.record("preview.gap_attached")
            }
            view.frame = CGRect(x: 16, y: seam + 8, width: max(0, list.bounds.width - 32), height: reservation - 16)
            content.update(view, enabled: true)
            list.bringSubviewToFront(view)
            if previousSeam != self.seam || abs(previousDelta - delta) > 0.5 {
                list.collectionViewLayout.invalidateLayout()
                ASMActivityRecorder.store.record("preview.gap_geometry", ["seam": String(Double(seam)),
                    "occupied": String(Double(occupied)), "reserved": String(Double(reservation))])
            }
        }
        func restore() { restoreCell(); content.restore(); view.removeFromSuperview() }
        deinit { restore() }
    }
    static func updatePlayer(_ controller: UIViewController) {
        roots.add(controller); pending.add(controller)
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async {
            scheduled = false
            let controllers = pending.allObjects; pending.removeAllObjects()
            for controller in controllers { performUpdate(controller) }
        }
    }
    private static func performUpdate(_ controller: UIViewController) {
        guard let root = controller.viewIfLoaded, root.window != nil else { return }
        var queue = [root], remaining = 500
        while let view = queue.popLast(), remaining > 0 {
            remaining -= 1
            if let list = view as? UICollectionView, isCardsList(list) {
                let existing = objc_getAssociatedObject(list, &hostKey) as? Host
                if KaraokePlayerSurfaces.wantsIndependentPreview {
                    let host = existing ?? Host(list)
                    objc_setAssociatedObject(list, &hostKey, host, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    host.update()
                } else if let existing {
                    existing.restore()
                    objc_setAssociatedObject(list, &hostKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    list.collectionViewLayout.invalidateLayout()
                }
            }
            queue.append(contentsOf: view.subviews)
        }
    }
    private static func isCardsList(_ list: UICollectionView) -> Bool {
        guard list.collectionViewLayout is UICollectionViewCompositionalLayout else { return false }
        var ancestor = list.superview
        while let view = ancestor {
            if view is UICollectionViewCell { return false }
            ancestor = view.superview
        }
        return list.visibleCells.contains { NSStringFromClass(type(of: $0)).contains("Element_List") }
    }
    static func updateCell(_ cell: UICollectionViewCell) {
        var responder: UIResponder? = cell
        while let current = responder {
            if let controller = current as? UIViewController,
               NSStringFromClass(type(of: controller)).contains("NowPlaying_ViewImpl") {
                updatePlayer(controller); return
            }
            responder = current.next
        }
    }
    static func prepareForReuse(_ cell: UICollectionViewCell) {
        (objc_getAssociatedObject(cell, &reuseKey) as? WeakHost)?.value?.restoreCell()
    }
    static func refresh() { for root in roots.allObjects { updatePlayer(root) } }
    static func owns(_ view: UIView) -> Bool {
        var ancestor: UIView? = view
        while let current = ancestor {
            if let list = current as? UICollectionView {
                return (objc_getAssociatedObject(list, &hostKey) as? Host)?.seam != nil
            }
            ancestor = current.superview
        }
        return false
    }
    private static func host(_ layout: UICollectionViewLayout) -> Host? {
        guard let list = layout.collectionView else { return nil }
        return objc_getAssociatedObject(list, &hostKey) as? Host
    }
    private static func nativeFrame(_ attributes: UICollectionViewLayoutAttributes) -> CGRect {
        (objc_getAssociatedObject(attributes, &nativeFrameKey) as? NSValue)?.cgRectValue ?? attributes.frame
    }
    static func adjusted(_ attributes: UICollectionViewLayoutAttributes?, layout: UICollectionViewLayout) -> UICollectionViewLayoutAttributes? {
        guard let attributes, let host = host(layout), let seam = host.seam else { return attributes }
        let original = nativeFrame(attributes)
        let shift = KaraokePlayerPreviewPolicy.shiftAfterGap(y: Double(original.minY), seam: Double(seam), occupied: Double(host.occupied))
        guard let result = attributes.copy() as? UICollectionViewLayoutAttributes else { return attributes }
        objc_setAssociatedObject(result, &nativeFrameKey, NSValue(cgRect: original), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        result.frame = shift ? original.offsetBy(dx: 0, dy: host.delta) : original
        return result
    }
    static func queryRect(_ rect: CGRect, layout: UICollectionViewLayout) -> CGRect {
        guard let host = host(layout) else { return rect }
        return rect.union(rect.offsetBy(dx: 0, dy: -host.delta))
    }
    static func contentSize(_ size: CGSize, layout: UICollectionViewLayout) -> CGSize {
        guard let host = host(layout) else { return size }
        return CGSize(width: size.width, height: max(0, size.height + host.delta))
    }
}
