import Orion
import UIKit

struct KaraokePlayerCardGroup: HookGroup {}
struct KaraokePlayerCanvasGroup: HookGroup {}
struct KaraokePlayerInlineGroup: HookGroup {}

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
}
