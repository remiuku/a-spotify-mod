import SwiftUI
import UIKit

/// One shared custom-source card; full rendering stays in the selected viewer.
/// It reuses KaraokeLookupModel's coalesced requests instead of fetching through
/// Spotify's native has_lyrics gate or starting another renderer/audio engine.
@available(iOS 15.0, *)
private struct KaraokePlayerPreview: View {
    @StateObject private var model = KaraokeLookupModel()
    @State private var options = UserDefaults.karaokeOptions
    var body: some View {
        Button { KaraokeOverlayPresenter.present() } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ASMText(options.renderer.displayName).font(.system(size: 18, weight: .bold))
                    Spacer()
                    ASMImage(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                switch model.phase {
                case .ready(let lyrics): KaraokePlayerPreviewLines(rows: KaraokePlayerPreviewPolicy.rows(lyrics), options: options)
                case .loading:
                    status("Looking for lyrics…", detail: "Tap to open your lyrics viewer.")
                case .missing:
                    status("No lyrics found", detail: "Tap to retry or choose another source.")
                case .failed:
                    status("Lyrics couldn't load", detail: "Tap to open your viewer and retry.")
                case .noTrack:
                    status("Play a song to see lyrics", detail: "")
                }
            }.foregroundColor(.white).padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityHint("Open the selected custom lyrics viewer")
            .onAppear { model.sync() }
            .onReceive(NotificationCenter.default.publisher(for: .eeveeKaraokeLyricsChanged)) { _ in model.sync() }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)) { _ in
                options = UserDefaults.karaokeOptions
                model.sync()
            }
    }
    private func status(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ASMText(title).font(.system(size: 23, weight: .bold))
            if !detail.isEmpty { ASMText(detail).font(.system(size: 13)).opacity(0.6) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

@available(iOS 15.0, *)
private struct KaraokePlayerPreviewLines: View {
    let rows: [KaraokePlayerPreviewPolicy.Row]
    let options: KaraokeOptions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var alignment: HorizontalAlignment {
        options.textAlignment == .center ? .center : options.textAlignment == .trailing ? .trailing : .leading
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            let position = KaraokePlaybackTracker.shared.currentLyricPositionMs()
            let focus = KaraokePlayerPreviewPolicy.focus(rows, position: position)
            VStack(alignment: alignment, spacing: 12) {
                ForEach(KaraokePlayerPreviewPolicy.window(rows, position: position)) { row in
                    let active = focus.map { rows[$0].id == row.id } == true && row.start <= position
                        && (row.end <= row.start || position < row.end)
                    ASMLyricText(row.text).font(.system(size: 23, weight: .bold))
                        .lineLimit(2).multilineTextAlignment(options.textAlignment == .center ? .center : options.textAlignment == .trailing ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                        .opacity(active ? 1 : 0.4)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: focus)
        }
    }
}

@available(iOS 15.0, *)
private final class KaraokeNativeVisibility {
    weak var view: UIView?
    let alpha: CGFloat
    let interactive: Bool
    let accessibilityHidden: Bool
    init(_ view: UIView) {
        self.view = view; alpha = view.alpha; interactive = view.isUserInteractionEnabled
        accessibilityHidden = view.accessibilityElementsHidden
    }
    func hide() { view?.alpha = 0; view?.isUserInteractionEnabled = false; view?.accessibilityElementsHidden = true }
    func restore() { view?.alpha = alpha; view?.isUserInteractionEnabled = interactive; view?.accessibilityElementsHidden = accessibilityHidden }
}

@available(iOS 15.0, *)
private final class KaraokePlayerCardHost {
    private let hosting = UIHostingController(rootView: AnyView(EmptyView()))
    private weak var owner: UIViewController?
    private var content: [KaraokeNativeVisibility] = []
    private var taps: [(recognizer: UITapGestureRecognizer, enabled: Bool)] = []
    private var installed = false
    deinit { restore() }
    func update(_ card: UIView, enabled: Bool) {
        guard enabled, card.window != nil else { restore(); return }
        if !installed {
            hosting.rootView = AnyView(KaraokePlayerPreview().modifier(ASMWhimsyRefresh()))
            hosting.view.backgroundColor = .clear; hosting.view.clipsToBounds = true
            installed = true
        }
        if owner == nil {
            var next: UIResponder? = card
            while let responder = next {
                if let controller = responder as? UIViewController {
                    controller.addChild(hosting); hosting.didMove(toParent: controller); owner = controller; break
                }
                next = responder.next
            }
        }
        if hosting.view.superview !== card { card.addSubview(hosting.view) }
        content.removeAll { $0.view == nil }
        for child in card.subviews where child !== hosting.view {
            let saved = content.first { $0.view === child } ?? {
                let saved = KaraokeNativeVisibility(child); content.append(saved); return saved
            }()
            saved.hide()
        }
        // Suppress only stock card/cell taps, leaving the collection's scrolling
        // gestures intact so one tap cannot open both native and custom pages.
        var cursor: UIView? = card
        while let view = cursor, !(view is UIScrollView) {
            for recognizer in view.gestureRecognizers ?? [] {
                guard let tap = recognizer as? UITapGestureRecognizer else { continue }
                if !taps.contains(where: { $0.recognizer === tap }) { taps.append((tap, tap.isEnabled)) }
                tap.isEnabled = false
            }
            if view is UICollectionViewCell { break }
            cursor = view.superview
        }
        if hosting.view.frame != card.bounds { hosting.view.frame = card.bounds }
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.bringSubviewToFront(hosting.view)
    }
    func restore() {
        guard installed else { return }
        content.forEach { $0.restore() }; content.removeAll()
        taps.forEach { $0.recognizer.isEnabled = $0.enabled }; taps.removeAll()
        hosting.view.removeFromSuperview()
        if owner != nil { hosting.willMove(toParent: nil); hosting.removeFromParent(); owner = nil }
        hosting.rootView = AnyView(EmptyView()); installed = false
    }
}

@available(iOS 15.0, *)
enum KaraokePlayerSurfaces {
    private static var cardKey: UInt8 = 0
    private static var canvasKey: UInt8 = 0
    private static var inlineKey: UInt8 = 0
    private static let cards = NSHashTable<UIView>.weakObjects()
    private static let canvases = NSHashTable<UIView>.weakObjects()
    private static let inlineViews = NSHashTable<UIView>.weakObjects()
    private final class InlineState {
        var nativeHidden: Bool
        var applying = false
        init(_ hidden: Bool) { nativeHidden = hidden }
    }
    private static var lastEnabled: Bool?
    private static var lastHidden: Set<PlayerPart> = []
    private static let optionsObserver = ASMMainNotificationDelivery.observe(forName: UserDefaults.didChangeNotification) { _ in refresh() }
    private static let trackObserver = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged,
        object: nil, queue: .main) { _ in refresh() }
    private static var enabled: Bool {
        KaraokePlayerPreviewPolicy.enabled(options: UserDefaults.karaokeOptions,
            supportedSource: ASMSongLyricsContext.source(KaraokePlaybackTracker.shared.currentTrackId()).supportsCustomLyricsView,
            musicTrack: KaraokePlaybackTracker.shared.currentTrackId() != nil, nativeInterface: ASMInterfaceMode.active == .spotify)
    }
    private static func refresh() {
        let hidden = Set(UserDefaults.playerOptions.hiddenParts)
        guard lastEnabled != enabled || lastHidden != hidden else { return }
        lastEnabled = enabled
        lastHidden = hidden
        for card in cards.allObjects { updateCard(card) }
        for canvas in canvases.allObjects { updateCanvas(canvas) }
        for inline in inlineViews.allObjects { updateInline(inline) }
    }
    static func updateCard(_ card: UIView) {
        _ = optionsObserver; _ = trackObserver; cards.add(card)
        let hidden = UserDefaults.playerOptions.hiddenParts
        let show = enabled && !hidden.contains(.lyricsCard) && !hidden.contains(.allCards)
        let existing = objc_getAssociatedObject(card, &cardKey) as? KaraokePlayerCardHost
        guard card.window != nil else { existing?.restore(); return }
        // Replace the whole card cell, including a stock header that can be a
        // sibling of CardView. The glass pane stays behind the content view.
        var surface = card
        var ancestor = card.superview
        while let view = ancestor {
            if let cell = view as? UICollectionViewCell { surface = cell.contentView; break }
            if view is UIScrollView { break }
            ancestor = view.superview
        }
        let saved = objc_getAssociatedObject(surface, &cardKey) as? KaraokePlayerCardHost ?? existing
        guard show else { saved?.restore(); return }
        let host = saved ?? {
            let host = KaraokePlayerCardHost()
            return host
        }()
        objc_setAssociatedObject(card, &cardKey, host, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(surface, &cardKey, host, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        host.update(surface, enabled: true)
    }
    static func updateCanvas(_ canvas: UIView) {
        _ = optionsObserver; _ = trackObserver; canvases.add(canvas)
        if enabled {
            let saved = objc_getAssociatedObject(canvas, &canvasKey) as? KaraokeNativeVisibility ?? {
                let saved = KaraokeNativeVisibility(canvas)
                objc_setAssociatedObject(canvas, &canvasKey, saved, .OBJC_ASSOCIATION_RETAIN_NONATOMIC); return saved
            }()
            saved.hide()
        } else if let saved = objc_getAssociatedObject(canvas, &canvasKey) as? KaraokeNativeVisibility {
            saved.restore(); objc_setAssociatedObject(canvas, &canvasKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if UserDefaults.playerOptions.hiddenParts.contains(.lyricsPreview) {
                canvas.alpha = 0; canvas.isUserInteractionEnabled = false; canvas.accessibilityElementsHidden = true
            }
        }
    }
    static func resolveInlineHidden(_ view: UIView, requested: Bool) -> Bool {
        _ = optionsObserver; _ = trackObserver; inlineViews.add(view)
        let saved = objc_getAssociatedObject(view, &inlineKey) as? InlineState
        if saved?.applying == true { return requested }
        if enabled {
            let state = saved ?? InlineState(requested)
            state.nativeHidden = requested
            objc_setAssociatedObject(view, &inlineKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return true
        }
        saved?.nativeHidden = requested
        return requested
    }
    static func updateInline(_ view: UIView) {
        _ = optionsObserver; _ = trackObserver; inlineViews.add(view)
        let saved = objc_getAssociatedObject(view, &inlineKey) as? InlineState
        if enabled {
            let state = saved ?? InlineState(view.isHidden)
            objc_setAssociatedObject(view, &inlineKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            state.applying = true
            if !view.isHidden { view.isHidden = true }
            state.applying = false
        } else if let saved {
            saved.applying = true
            if view.isHidden != saved.nativeHidden { view.isHidden = saved.nativeHidden }
            saved.applying = false
            objc_setAssociatedObject(view, &inlineKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
