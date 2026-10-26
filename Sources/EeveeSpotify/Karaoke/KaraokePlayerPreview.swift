import SwiftUI
import UIKit

/// One shared custom-source card with a bounded use of Sweet's existing renderer.
/// It reuses KaraokeLookupModel's coalesced requests instead of fetching through
/// Spotify's native has_lyrics gate or starting another renderer/audio engine.
@available(iOS 15.0, *)
private struct KaraokePlayerPreview: View {
    @StateObject private var model = KaraokeLookupModel()
    @State private var options = UserDefaults.karaokeOptions
    @State private var mild = UserDefaults.mildLyricsOptions
    let visible: () -> Bool
    var body: some View {
        Button { KaraokeOverlayPresenter.present() } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ASMText("Lyrics").font(.system(size: 15, weight: .semibold)).opacity(0.8)
                    Spacer()
                    ASMImage(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .semibold)).opacity(0.8)
                }
                switch model.phase {
                case .ready(let lyrics): KaraokePlayerPreviewLines(lyrics: lyrics, options: options, mild: mild, visible: visible)
                case .loading:
                    status("Looking for lyrics…", detail: "Tap to open your lyrics viewer.")
                case .missing:
                    status("No lyrics found", detail: "Tap to retry or choose another source.")
                case .failed:
                    status("Lyrics couldn't load", detail: "Tap to open your viewer and retry.")
                case .noTrack:
                    status("Play a song to see lyrics", detail: "")
                }
            }.foregroundColor(.white).padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: CGFloat(KaraokePlayerPreviewPolicy.contentHeight), alignment: .topLeading)
                .background(LinearGradient(colors: [.white.opacity(0.10), .black.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .ignoresSafeArea(.container)
            .accessibilityHint("Open the selected custom lyrics viewer")
            .onAppear { model.sync() }
            .onReceive(NotificationCenter.default.publisher(for: .eeveeKaraokeLyricsChanged)) { _ in model.sync() }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)) { _ in
                options = UserDefaults.karaokeOptions
                mild = UserDefaults.mildLyricsOptions
                model.sync()
            }
    }
    private func status(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ASMText(title).font(.system(size: 23, weight: .bold))
            if !detail.isEmpty { ASMText(detail).font(.system(size: 13)).opacity(0.6) }
        }.frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
}

@available(iOS 15.0, *)
private struct KaraokePlayerPreviewLines: View {
    let options: KaraokeOptions
    let mild: MildLyricsOptions
    let prepared: SweetPreparedLyrics
    @StateObject private var clock: KaraokePreviewClock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(lyrics: KaraokeLyricsDto, options: KaraokeOptions, mild: MildLyricsOptions, visible: @escaping () -> Bool) {
        var cardOptions = options; cardOptions.textAlignment = .leading
        self.options = cardOptions
        // Mild belongs to Sweet; the other selected viewers keep the neutral compact style.
        var compactOptions = mild
        if options.renderer != .sweetLyrics { compactOptions.flags["enabled"] = false }
        self.mild = compactOptions
        let document = SweetLyricsAdapter.document(from: lyrics)
        var prepared = SweetPreparedLyrics(document: compactOptions.flag("enabled")
            ? MildRenderPolicy.document(document, options: compactOptions) : document,
            romanized: false, simple: options.sweetSimpleLyrics)
        prepared.lines.removeAll { $0.isInterlude || $0.isBackground || $0.plainText.isEmpty }
        self.prepared = prepared
        _clock = StateObject(wrappedValue: KaraokePreviewClock(visible: visible))
    }
    var body: some View {
        let position = Double(clock.sample.position) / 1000 + (mild.flag("enabled") ? mild.number("offset") : 0)
        let window = KaraokePreviewAnimationPolicy.window(prepared, position: position)
        KaraokePreviewAnimatedWindow(lyrics: window, sample: clock.sample, position: position,
            options: options, mild: mild, reduceMotion: reduceMotion)
            .id(window.lines)
            .frame(maxWidth: .infinity, alignment: .top)
            .onAppear { clock.start() }
            .onDisappear { clock.stop() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                .receive(on: DispatchQueue.main)) { _ in clock.stop() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .receive(on: DispatchQueue.main)) { _ in clock.start() }
    }
}

@available(iOS 15.0, *)
private final class KaraokePreviewAnimatorBox: ObservableObject {
    let animator: SweetLyricsAnimator
    init(lyrics: SweetPreparedLyrics, simple: Bool) { animator = SweetLyricsAnimator(lyrics: lyrics, simple: simple) }
}

@available(iOS 15.0, *)
private struct KaraokePreviewAnimatedWindow: View {
    @StateObject private var box: KaraokePreviewAnimatorBox
    private var animator: SweetLyricsAnimator { box.animator }
    let sample: KaraokePreviewClock.Sample
    let position: Double
    let options: KaraokeOptions
    let mild: MildLyricsOptions
    let reduceMotion: Bool
    init(lyrics: SweetPreparedLyrics, sample: KaraokePreviewClock.Sample, position: Double,
         options: KaraokeOptions, mild: MildLyricsOptions, reduceMotion: Bool) {
        // StateObject's autoclosure runs once per view identity, not on every parent update.
        _box = StateObject(wrappedValue: KaraokePreviewAnimatorBox(lyrics: lyrics, simple: options.sweetSimpleLyrics))
        self.sample = sample; self.position = position; self.options = options
        self.mild = mild; self.reduceMotion = reduceMotion
    }
    var body: some View {
        animator.step(position: position, now: sample.now, blurEnabled: false, isPlaying: sample.playing)
        let visuals = animator.visuals // Pass value state to rows on every frame, as the full viewer does.
        let focus = animator.lyrics.lines.indices.contains(animator.focusIndex)
            ? animator.lyrics.lines[animator.focusIndex].id : 0
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(animator.lyrics.lines.enumerated()), id: \.element.id) { index, original in
                let line = aligned(mild.flag("enabled") ? MildRenderPolicy.line(original, position: position, options: mild) : original)
                let visual = mild.flag("enabled") ? MildRenderPolicy.visual(visuals[index], line: original,
                    focus: focus, position: position, options: mild, reduceMotion: reduceMotion) : visuals[index]
                SweetLyricLineView(line: line, visual: KaraokePreviewAnimationPolicy.compact(visual, reduceMotion: reduceMotion),
                    typography: typography)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: CGFloat(KaraokePlayerPreviewPolicy.rowHeight), alignment: .top).clipped()
            }
        }.transaction { $0.animation = nil }
    }
    private func aligned(_ original: SweetPreparedLine) -> SweetPreparedLine {
        var line = original
        if options.textAlignment != .center { line.oppositeAligned = options.textAlignment == .trailing }
        return line
    }
    private var typography: SweetLyricsTypography {
        var style = SweetLyricsTypography(fontSize: 21)
        style.weight = .semibold
        style.cqw = 0; style.blurScale = 0
        style.centered = options.textAlignment == .center
        style.simple = options.sweetSimpleLyrics
        if mild.flag("enabled") {
            style.fontSize *= max(0.8, min(1.2, mild.number("font_scale")))
            style.font = SweetLyricsFontChoice(stored: mild.choice("font_name"))
            style.glowScale = min(1, mild.number("glow_scale"))
            style.fillSoftness = mild.number("edge")
        }
        // The default playful context stays disabled even if full-view effects are enabled.
        return style
    }
}

@available(iOS 15.0, *)
private final class KaraokePreviewDisplayTarget: NSObject {
    weak var clock: KaraokePreviewClock?
    @objc func tick(_ link: CADisplayLink) { clock?.tick(link.timestamp) }
}

@available(iOS 15.0, *)
private final class KaraokePreviewClock: ObservableObject {
    struct Sample { var position = 0; var playing = false; var now = CACurrentMediaTime() }
    @Published private(set) var sample = Sample()
    private let visible: () -> Bool
    private var link: CADisplayLink?
    private var target: KaraokePreviewDisplayTarget?
    init(visible: @escaping () -> Bool) { self.visible = visible }
    deinit { link?.invalidate() }
    func start() {
        guard link == nil, UIApplication.shared.applicationState == .active else { return }
        let target = KaraokePreviewDisplayTarget(); target.clock = self
        let link = CADisplayLink(target: target, selector: #selector(KaraokePreviewDisplayTarget.tick(_:)))
        link.preferredFramesPerSecond = 30
        self.target = target; self.link = link
        link.add(to: .main, forMode: .common)
        tick(CACurrentMediaTime())
    }
    func stop() { link?.invalidate(); link = nil; target = nil }
    func tick(_ now: Double) {
        guard UIApplication.shared.applicationState == .active, visible() else { return }
        let playback = KaraokePlaybackTracker.shared.lyricSnapshot()
        guard KaraokePreviewAnimationPolicy.shouldPublish(visible: true, position: playback.positionMs,
            playing: playback.isPlaying, previousPosition: sample.position, previousPlaying: sample.playing) else { return }
        link?.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 15 : 30
        sample = Sample(position: playback.positionMs, playing: playback.isPlaying, now: now)
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
final class KaraokePlayerCardHost {
    private let hosting = UIHostingController(rootView: AnyView(EmptyView()))
    private weak var owner: UIViewController?
    private var content: [KaraokeNativeVisibility] = []
    private var taps: [(recognizer: UITapGestureRecognizer, enabled: Bool)] = []
    private var installed = false
    init() {
        // This is a scrolling card, not a full-screen page. Inheriting the
        // window's changing safe-area intersection clips/reflows it on scroll.
        if #available(iOS 16.4, *) { hosting.safeAreaRegions = [] }
    }
    deinit { restore() }
    private func visible() -> Bool {
        guard installed, let window = hosting.viewIfLoaded?.window else { return false }
        var controller = owner
        while let current = controller {
            if current.presentedViewController != nil { return false }
            controller = current.parent
        }
        var rect = hosting.view.convert(hosting.view.bounds, to: window).intersection(window.bounds)
        var cursor: UIView? = hosting.view
        while let view = cursor {
            if view.isHidden || view.alpha < 0.01 { return false }
            if view.clipsToBounds { rect = rect.intersection(view.convert(view.bounds, to: window)) }
            if rect.isNull || rect.isEmpty { return false }
            cursor = view.superview
        }
        return true
    }
    func update(_ card: UIView, enabled: Bool) {
        guard enabled, card.window != nil else { restore(); return }
        if !installed {
            hosting.rootView = AnyView(KaraokePlayerPreview(visible: { [weak self] in self?.visible() ?? false }).modifier(ASMWhimsyRefresh()))
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
    private static let trackObserver = ASMMainNotificationDelivery.observe(forName: .eeveeKaraokeLyricsChanged) { _ in refresh() }
    /// Installs the refresh observers without waiting for a native card, canvas or
    /// inline view to be laid out (none may exist when Spotify has no native lyrics).
    static func startObservers() { _ = optionsObserver; _ = trackObserver }
    static var wantsIndependentPreview: Bool {
        let hidden = UserDefaults.playerOptions.hiddenParts
        return enabled && !hidden.contains(.lyricsCard) && !hidden.contains(.allCards)
    }
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
        KaraokeIndependentPreview.refresh()
        for card in cards.allObjects { updateCard(card) }
        for canvas in canvases.allObjects { updateCanvas(canvas) }
        for inline in inlineViews.allObjects { updateInline(inline) }
    }
    static func updateCard(_ card: UIView) {
        _ = optionsObserver; _ = trackObserver; cards.add(card)
        let hidden = UserDefaults.playerOptions.hiddenParts
        let show = enabled && !hidden.contains(.lyricsCard) && !hidden.contains(.allCards)
        let existing = objc_getAssociatedObject(card, &cardKey) as? KaraokePlayerCardHost
        if KaraokeIndependentPreview.owns(card) { existing?.restore(); return }
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
