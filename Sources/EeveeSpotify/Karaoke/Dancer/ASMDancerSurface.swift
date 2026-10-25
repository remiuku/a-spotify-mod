import UIKit

private final class ASMDancerDisplayTarget: NSObject {
    weak var view: ASMDancerSurface?
    init(_ view: ASMDancerSurface) { self.view = view }
    @objc func update() { view?.render() }
}
/// Direct layer rendering bypasses global :3 UIImage replacement.
final class ASMDancerSurface: UIView {
    private let preview: Bool
    private let bitmap = CALayer()
    private var options = ASMDancerOptions.load()
    private var asset: ASMDancerFrames?
    private var loading: ASMDancerAnimation?
    private var failed: ASMDancerAnimation?
    private var revision = 0
    private var link: CADisplayLink?
    private var observers: [NSObjectProtocol] = []
    private var frameIndex = -1
    private let started = CACurrentMediaTime()
    private let tempoOwner = UUID()
    private var lastTempoTick = -Double.infinity
    init(preview: Bool = false) {
        self.preview = preview
        super.init(frame: .zero)
        backgroundColor = .clear; isOpaque = false; isUserInteractionEnabled = false; accessibilityElementsHidden = true
        bitmap.contentsGravity = .resizeAspect; bitmap.contentsScale = UIScreen.main.scale; layer.addSublayer(bitmap)
        for name in [UserDefaults.didChangeNotification, UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification] {
            observers.append(ASMMainNotificationDelivery.observe(forName: name) { [weak self] _ in self?.reloadOptions() })
        }
        reloadOptions()
    }
    required init?(coder: NSCoder) { fatalError("Programmatic view") }
    deinit { link?.invalidate(); observers.forEach(NotificationCenter.default.removeObserver); ASMDancerTempoService.shared.removeOwner(tempoOwner) }
    override func didMoveToWindow() { super.didMoveToWindow(); reloadOptions() }
    override func layoutSubviews() { super.layoutSubviews(); frameIndex = -1; render() }
    func reloadOptions() {
        let previous = options.animation
        options = ASMDancerOptions.load()
        isHidden = !preview && !options.enabled
        if previous != options.animation { asset = nil; loading = nil; failed = nil; frameIndex = -1; bitmap.contents = nil; revision += 1 }
        let mounted = window != nil && !isHidden
        let visible = mounted && UIApplication.shared.applicationState != .background
        if mounted, asset == nil, loading != options.animation, failed != options.animation {
            loading = options.animation; revision += 1; let token = revision
            ASMDancerAssets.load(options.animation) { [weak self] frames, status in
                guard let self, self.revision == token else { return }
                self.asset = frames; self.loading = nil; self.frameIndex = -1
                if frames == nil { self.failed = self.options.animation }
                UserDefaults.standard.set(status, forKey: "asm.lyrics.dancer.mediaStatus")
                self.render()
            }
        }
        if visible, link == nil {
            let display = CADisplayLink(target: ASMDancerDisplayTarget(self), selector: #selector(ASMDancerDisplayTarget.update))
            display.preferredFramesPerSecond = 30; display.add(to: .main, forMode: .common); link = display
        } else if !visible { link?.invalidate(); link = nil; ASMDancerTempoService.shared.removeOwner(tempoOwner) }
        render()
    }
    fileprivate func render() {
        guard !isHidden, window != nil else { return }
        let snapshot = KaraokePlaybackTracker.shared.dancerSnapshot(), now = CACurrentMediaTime()
        if now - lastTempoTick >= 0.5 {
            lastTempoTick = now
            ASMDancerTempoService.shared.update(owner: tempoOwner, snapshot: snapshot, options: options, active: UIApplication.shared.applicationState == .active)
        }
        guard let asset, !asset.frames.isEmpty else { return }
        let selected = options.estimateBPM ? ASMDancerTempoService.shared.tempo(for: snapshot) : snapshot.tempo ?? ASMDJInfoTempoClient.shared.cached(snapshot.trackId)
        let bpm = options.sync && !preview ? (options.forceManual ? options.fallbackBPM : selected?.bpm ?? options.fallbackBPM) : nil
        let milliseconds = preview ? Int((now - started) * 1000) : snapshot.positionMs
        let phase = UIAccessibility.isReduceMotionEnabled ? 0 : ASMDancerTiming.phase(positionMs: milliseconds,
            loopSeconds: asset.ends.last ?? 1, bpm: bpm, beats: options.beats, offsetBeats: preview ? 0 : options.offsetBeats, tempoScale: options.tempoScale.factor)
        let index = ASMDancerTiming.frame(phase: phase, ends: asset.ends)
        guard index != frameIndex else { return }; frameIndex = index
        let rect = asset.placements[index]
        CATransaction.begin(); CATransaction.setDisableActions(true)
        bitmap.frame = CGRect(x: bounds.width * rect.minX, y: bounds.height * rect.minY, width: bounds.width * rect.width, height: bounds.height * rect.height)
        bitmap.contents = asset.frames[index]; CATransaction.commit()
    }
}
