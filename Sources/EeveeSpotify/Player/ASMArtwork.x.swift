import UIKit
import EeveeSpotifyC
import AVFoundation
import Orion

struct ASMArtworkGroup: HookGroup {}

class ASMArtworkTiltHook: ClassHook<UIView> {
    typealias Group = ASMArtworkGroup
    static let targetName = "_TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView"
    func layoutSubviews() {
        orig.layoutSubviews()
        guard target.bounds.width >= 200, PlayerPlacement.contains(target) else { return }
        ASMArtworkAttachment.attach(to: target)
    }
    func didMoveToWindow() {
        orig.didMoveToWindow()
        ASMArtworkAttachment.existing(on: target)?.refresh()
    }
}

func activateASMArtwork() {
    guard NSClassFromString(ASMArtworkTiltHook.targetName) != nil else { return }
    ASMArtworkGroup().activate()
}

/// A bounded overlay on the existing cover. It never supplies an intrinsic size,
/// steals touches, changes the audio session, or replaces native player controls.
final class ASMArtworkAttachment: NSObject {
    private static var key: UInt8 = 0
    private weak var tilt: UIView?
    private weak var cover: UIView?
    private let video = ASMArtworkVideoView()
    private var player: AVPlayer?
    private var ready: NSKeyValueObservation?
    private var failure: NSKeyValueObservation?
    private var observers: [NSObjectProtocol] = []
    private var endObserver: NSObjectProtocol?
    private var identity = ""
    private var revision = 0
    private var animationIdentity = ""
    private var styled = false
    private var originalRadius: CGFloat = 0
    private var originalClip = false
    private var originalShadow: (Float, CGFloat, CGSize, CGColor?, CGPath?)?

    static func existing(on tilt: UIView) -> ASMArtworkAttachment? {
        objc_getAssociatedObject(tilt, &key) as? ASMArtworkAttachment
    }
    static func attach(to tilt: UIView) {
        if let existing = existing(on: tilt) { existing.refresh(); return }
        guard UserDefaults.asmArtworkOptions.enabled,
              let cover = tilt.subviews.first(where: { abs($0.bounds.width - tilt.bounds.width) < 2 && $0.bounds.height >= 200 }) else { return }
        let attachment = ASMArtworkAttachment(tilt: tilt, cover: cover)
        objc_setAssociatedObject(tilt, &key, attachment, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        attachment.refresh()
    }
    private init(tilt: UIView, cover: UIView) {
        self.tilt = tilt; self.cover = cover
        originalRadius = cover.layer.cornerRadius; originalClip = cover.clipsToBounds
        originalShadow = (tilt.layer.shadowOpacity, tilt.layer.shadowRadius, tilt.layer.shadowOffset, tilt.layer.shadowColor, tilt.layer.shadowPath)
        super.init()
        video.isUserInteractionEnabled = false; video.isHidden = true
        video.playerLayer.videoGravity = .resizeAspectFill
        for name in [Notification.Name.asmArtworkChanged, .eeveeKaraokeLyricsChanged,
                     UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification,
                     .NSProcessInfoPowerStateDidChange, UIAccessibility.reduceMotionStatusDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        }
    }
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player?.pause()
    }
    func refresh() {
        guard let cover, let tilt else { return }
        let options = UserDefaults.asmArtworkOptions
        var hidden = false
        var ancestor: UIView? = tilt
        while let view = ancestor { hidden = hidden || view.isHidden || view.alpha < 0.01; ancestor = view.superview }
        let inViewport: Bool
        if let window = tilt.window {
            let frame = tilt.convert(tilt.bounds, to: window)
            let intersection = frame.intersection(window.bounds)
            inViewport = !intersection.isNull && intersection.width * intersection.height > frame.width * frame.height * 0.8
        } else { inViewport = false }
        let active = UIApplication.shared.applicationState == .active && inViewport && !hidden
        let playing = KaraokePlaybackTracker.shared.isPlaying()
        let animate = options.animates(active: active, playing: playing,
                                       reduceMotion: UIAccessibility.isReduceMotionEnabled, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        guard options.enabled else {
            if styled {
                cover.layer.cornerRadius = originalRadius; cover.clipsToBounds = originalClip
                if let saved = originalShadow {
                    tilt.layer.shadowOpacity = saved.0; tilt.layer.shadowRadius = saved.1; tilt.layer.shadowOffset = saved.2
                    tilt.layer.shadowColor = saved.3; tilt.layer.shadowPath = saved.4
                }
                cover.layer.removeAnimation(forKey: "asm.motion"); cover.layer.removeAnimation(forKey: "asm.pause")
                styled = false
            }
            clearVideo(); identity = ""; return
        }
        styled = true
        cover.layer.cornerRadius = min(CGFloat(options.safeRadius), min(cover.bounds.width, cover.bounds.height) / 2)
        cover.layer.cornerCurve = .continuous; cover.clipsToBounds = true
        tilt.layer.shadowOpacity = Float(options.safeShadow); tilt.layer.shadowRadius = 28
        tilt.layer.shadowOffset = CGSize(width: 0, height: 10); tilt.layer.shadowColor = UIColor.black.cgColor
        tilt.layer.shadowPath = UIBezierPath(roundedRect: tilt.bounds, cornerRadius: cover.layer.cornerRadius).cgPath
        video.frame = cover.bounds
        if video.superview !== cover { cover.addSubview(video) }
        updateMotion(options, animate: animate, playing: playing, cover: cover)
        // Let the native image view show the cat while the visual toggle is on.
        guard !ASMWhimsyIsEnabled() else { clearVideo(); identity = ""; return }
        guard active else { player?.pause(); video.isHidden = true; return }
        // Do not fetch or start video when motion is suppressed by the system.
        guard !UIAccessibility.isReduceMotionEnabled,
              !(options.lowPowerStill && ProcessInfo.processInfo.isLowPowerModeEnabled) else {
            player?.pause(); video.isHidden = true; return
        }
        guard let album = ASMArtworkAlbum.current() else { clearVideo(); identity = ""; return }
        let newIdentity = album.key + "/" + String(describing: options) + "/" + ASMArtworkRepository.shared.override(for: album)
        if identity != newIdentity {
            clearVideo(); identity = newIdentity
            let token = revision
            ASMArtworkRepository.shared.lookup(album, options: options) { [weak self] url in
                guard let self, self.revision == token, self.identity == newIdentity,
                      ASMArtworkAlbum.current() == album, let url else { return }
                self.showVideo(url, options: options)
            }
        }
        if animate { player?.play() } else { player?.pause() }
        video.isHidden = !(video.playerLayer.isReadyForDisplay && player?.currentItem?.status == .readyToPlay)
    }
    private func clearVideo() {
        revision += 1
        player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
        video.playerLayer.player = nil; ready = nil; failure = nil; video.isHidden = true
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
    private func showVideo(_ url: URL, options: ASMArtworkOptions) {
        let asset = AVURLAsset(url: url, options: [AVURLAssetAllowsCellularAccessKey: !options.wifiOnly,
            AVURLAssetAllowsExpensiveNetworkAccessKey: !options.wifiOnly, AVURLAssetAllowsConstrainedNetworkAccessKey: false])
        let item = AVPlayerItem(asset: asset)
        item.preferredPeakBitRate = 2_000_000
        item.preferredForwardBufferDuration = 5
        let player = AVPlayer(playerItem: item)
        player.isMuted = true; player.volume = 0
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .none
        self.player = player; video.playerLayer.player = player
        ready = video.playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, _ in DispatchQueue.main.async { self?.refresh() } }
        failure = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async { self?.clearVideo() }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero) { [weak self] _ in DispatchQueue.main.async { self?.refresh() } }
        }
        refresh()
    }
    private func updateMotion(_ options: ASMArtworkOptions, animate: Bool, playing: Bool, cover: UIView) {
        let identity = "\(options.motion.rawValue)/\(options.safeDuration)/\(animate)/\(playing)/\(options.safePausedScale)"
        guard identity != animationIdentity else { return }
        animationIdentity = identity
        cover.layer.removeAnimation(forKey: "asm.motion"); cover.layer.removeAnimation(forKey: "asm.pause")
        if !playing && !UIAccessibility.isReduceMotionEnabled {
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = options.safePausedScale; scale.toValue = options.safePausedScale
            scale.duration = .greatestFiniteMagnitude; scale.isRemovedOnCompletion = false
            cover.layer.add(scale, forKey: "asm.pause")
        }
        guard animate, options.motion != .off else { return }
        let motion: CABasicAnimation
        switch options.motion {
        case .spin: motion = CABasicAnimation(keyPath: "transform.rotation.z"); motion.fromValue = 0; motion.toValue = Double.pi * 2
        case .breathe: motion = CABasicAnimation(keyPath: "transform.scale"); motion.fromValue = 0.96; motion.toValue = 1
        case .float: motion = CABasicAnimation(keyPath: "transform.translation.y"); motion.fromValue = -6; motion.toValue = 6
        case .tilt: motion = CABasicAnimation(keyPath: "transform.rotation.z"); motion.fromValue = -0.035; motion.toValue = 0.035
        case .off: return
        }
        motion.duration = options.safeDuration; motion.repeatCount = .infinity
        motion.autoreverses = options.motion != .spin
        motion.timingFunction = CAMediaTimingFunction(name: options.motion == .spin ? .linear : .easeInEaseOut)
        cover.layer.add(motion, forKey: "asm.motion")
    }
}

private final class ASMArtworkVideoView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
