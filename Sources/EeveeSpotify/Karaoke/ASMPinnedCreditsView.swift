import UIKit
import SwiftUI

/// A separate footer instance for each imported UIKit lyric surface. Changes
/// come from the shared store, never its per-frame highlighting callbacks.
@objc(ASMPinnedCreditsView)
final class ASMPinnedCreditsView: UIView {
    private let hosting = UIHostingController(rootView: AnyView(EmptyView()))
    private let dancer = ASMDancerSurface()
    private var observer: NSObjectProtocol?
    private weak var owner: UIViewController?
    private var rows: [KaraokeCreditPolicy.Row] = []
    private var lyrics: KaraokeLyricsDto?
    private var hasContent = false
    private var measuredWidth: CGFloat = -1
    private var measuredCompact = false
    private var measuredHeight: CGFloat = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        // The optional dancer is an overlay above the footer, not extra
        // reserved height. The lyric surface still clips its whole viewport.
        clipsToBounds = false
        backgroundColor = .clear
        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false
        hosting.view.clipsToBounds = false
        addSubview(hosting.view)
        observer = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }
    deinit { dancer.removeFromSuperview(); if let observer { NotificationCenter.default.removeObserver(observer) } }
    private func refresh() {
        let lyrics = KaraokePlaybackTracker.shared.currentTrackId().flatMap {
            KaraokeLyricsStore.shared.validatedLyrics(trackId: $0, signature: ASMSongLyricsContext.signature($0))
        }
        let next = lyrics.map(KaraokeCreditPolicy.rows) ?? []
        guard next != rows else { return }
        self.lyrics = lyrics; rows = next; hasContent = !next.isEmpty; measuredWidth = -1
        hosting.rootView = lyrics.map { AnyView(KaraokeCreditsFooterView(lyrics: $0)) } ?? AnyView(EmptyView())
        invalidateIntrinsicContentSize(); setNeedsLayout(); superview?.setNeedsLayout()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { refresh(); connectController() }
        else { dancer.removeFromSuperview(); detachController() }
    }
    override func willMove(toSuperview next: UIView?) {
        if next !== superview { dancer.removeFromSuperview() }
        super.willMove(toSuperview: next)
    }
    private func connectController() {
        guard owner == nil else { return }
        var responder: UIResponder? = superview
        while let current = responder {
            if let controller = current as? UIViewController {
                controller.addChild(hosting); hosting.didMove(toParent: controller); owner = controller; return
            }
            responder = current.next
        }
    }
    private func detachController() {
        guard owner != nil else { return }
        hosting.willMove(toParent: nil); hosting.removeFromParent(); owner = nil
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard hasContent, size.width > 0 else { return CGSize(width: size.width, height: 0) }
        let compact = traitCollection.verticalSizeClass == .compact
        if measuredWidth != size.width || measuredCompact != compact {
            if let lyrics { hosting.rootView = AnyView(KaraokeCreditsFooterView(lyrics: lyrics, viewportWidth: size.width, compact: compact)) }
            let result = hosting.sizeThatFits(in: CGSize(width: size.width, height: .greatestFiniteMagnitude))
            measuredWidth = size.width; measuredCompact = compact; measuredHeight = ceil(result.height)
        }
        return CGSize(width: size.width, height: measuredHeight)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass else { return }
        measuredWidth = -1
        invalidateIntrinsicContentSize(); setNeedsLayout(); superview?.setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews(); hosting.view.frame = bounds; connectController()
        guard let parent = superview, window != nil else { return }
        if dancer.superview !== parent { parent.addSubview(dancer) }
        let footer = convert(bounds, to: parent)
        let side: CGFloat = traitCollection.verticalSizeClass == .compact ? 44 : 64
        dancer.frame = CGRect(x: footer.maxX - 24 - side, y: max(parent.bounds.minY, footer.minY - side - 6), width: side, height: side)
        parent.bringSubviewToFront(dancer)
    }
}
