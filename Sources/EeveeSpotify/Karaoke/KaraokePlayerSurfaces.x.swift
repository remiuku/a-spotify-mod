import Orion
import UIKit

struct KaraokePlayerCardGroup: HookGroup {}
struct KaraokePlayerCanvasGroup: HookGroup {}
struct KaraokePlayerInlineGroup: HookGroup {}
struct KaraokeIndependentPreviewGroup: HookGroup {}

class KaraokeIndependentPlayerHook: ClassHook<UIViewController> {
    typealias Group = KaraokeIndependentPreviewGroup
    static let targetName = "_TtC19NowPlaying_ViewImpl24NowPlayingViewController"
    func viewDidLayoutSubviews() {
        orig.viewDidLayoutSubviews()
        if #available(iOS 15.0, *) { KaraokeIndependentPreview.updatePlayer(target) }
    }
    func viewDidAppear(_ animated: Bool) {
        orig.viewDidAppear(animated)
        if #available(iOS 15.0, *) { KaraokeIndependentPreview.updatePlayer(target) }
    }
}

class KaraokeIndependentCardCellHook: ClassHook<UICollectionViewCell> {
    typealias Group = KaraokeIndependentPreviewGroup
    static let targetName = "_TtC12Element_List18CollectionViewCell"
    func prepareForReuse() {
        if #available(iOS 15.0, *) { KaraokeIndependentPreview.prepareForReuse(target) }
        orig.prepareForReuse()
    }
    func layoutSubviews() {
        orig.layoutSubviews()
        if #available(iOS 15.0, *) { KaraokeIndependentPreview.updateCell(target) }
    }

}

// Only associated Now Playing lists receive adjusted copies of native attributes.
class KaraokeIndependentLayoutHook: ClassHook<UICollectionViewCompositionalLayout> {
    typealias Group = KaraokeIndependentPreviewGroup
    func layoutAttributesForElementsInRect(_ rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard #available(iOS 15.0, *) else { return orig.layoutAttributesForElementsInRect(rect) }
        let query = KaraokeIndependentPreview.queryRect(rect, layout: target)
        return orig.layoutAttributesForElementsInRect(query)?.compactMap { KaraokeIndependentPreview.adjusted($0, layout: target) }
    }
    func layoutAttributesForItemAtIndexPath(_ index: IndexPath) -> UICollectionViewLayoutAttributes? {
        let result = orig.layoutAttributesForItemAtIndexPath(index)
        if #available(iOS 15.0, *) { return KaraokeIndependentPreview.adjusted(result, layout: target) }
        return result
    }
    func layoutAttributesForSupplementaryViewOfKind(_ kind: String, atIndexPath index: IndexPath) -> UICollectionViewLayoutAttributes? {
        let result = orig.layoutAttributesForSupplementaryViewOfKind(kind, atIndexPath: index)
        if #available(iOS 15.0, *) { return KaraokeIndependentPreview.adjusted(result, layout: target) }
        return result
    }
    func collectionViewContentSize() -> CGSize {
        let size = orig.collectionViewContentSize()
        if #available(iOS 15.0, *) { return KaraokeIndependentPreview.contentSize(size, layout: target) }
        return size
    }
}

class KaraokePlayerCardHook: ClassHook<UIView> {
    typealias Group = KaraokePlayerCardGroup
    static let targetName = "_TtC22Lyrics_CardElementImpl8CardView"
    func layoutSubviews() {
        orig.layoutSubviews()
        if #available(iOS 15.0, *) { KaraokePlayerSurfaces.updateCard(target) }
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        if #available(iOS 15.0, *) { KaraokePlayerSurfaces.updateCard(target) }
    }
}

class KaraokePlayerCanvasHook: ClassHook<UIView> {
    typealias Group = KaraokePlayerCanvasGroup
    static let targetName = "_TtC17Canvas_CommonImpl26CanvasNowPlayingLyricsView"
    func layoutSubviews() {
        orig.layoutSubviews()
        if #available(iOS 15.0, *) { KaraokePlayerSurfaces.updateCanvas(target) }
    }
}

class KaraokePlayerInlineHook: ClassHook<UIView> {
    typealias Group = KaraokePlayerInlineGroup
    static let targetName = "_TtC22Lyrics_NPVContainerKit19LyricsContainerView"
    func setHidden(_ hidden: Bool) {
        if #available(iOS 15.0, *) { orig.setHidden(KaraokePlayerSurfaces.resolveInlineHidden(target, requested: hidden)) }
        else { orig.setHidden(hidden) }
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        if #available(iOS 15.0, *) { KaraokePlayerSurfaces.updateInline(target) }
    }
}

func activateKaraokePlayerSurfaces() {
    guard #available(iOS 15.0, *), ASMInterfaceMode.active == .spotify else { return }
    if NSClassFromString(KaraokePlayerCardHook.targetName) != nil { KaraokePlayerCardGroup().activate() }
    if NSClassFromString(KaraokePlayerCanvasHook.targetName) != nil { KaraokePlayerCanvasGroup().activate() }
    if NSClassFromString(KaraokePlayerInlineHook.targetName) != nil { KaraokePlayerInlineGroup().activate() }
    if NSClassFromString(KaraokeIndependentPlayerHook.targetName) != nil,
       NSClassFromString(KaraokeIndependentCardCellHook.targetName) != nil { KaraokeIndependentPreviewGroup().activate() }
}
