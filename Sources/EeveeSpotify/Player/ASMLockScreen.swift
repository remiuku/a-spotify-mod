import UIKit
import MediaPlayer
import AVFoundation
import EeveeSpotifyC

enum ASMLockMode: String, Codable, CaseIterable {
    case off, artwork, lyrics, combined
    var title: String { switch self { case .off: return "Off"; case .artwork: return "Animated album artwork"; case .lyrics: return "Lyrics on cover"; case .combined: return "Lyrics over animated artwork" } }
    var hasLyrics: Bool { self == .lyrics || self == .combined }
    var hasVideo: Bool { self == .artwork || self == .combined }
}
extension UserDefaults {
    @UserDefault(key: "asm.lock.mode", defaultValue: ASMLockMode.off) static var asmLockMode
}

/// Optional and independent of the selected interface. The hook only decorates
/// matching metadata; the host never changes titles, playback commands or audio.
@objc(ASMLockScreenHost)
final class ASMLockScreenHost: NSObject {
    private static var timer: DispatchSourceTimer?
    private static var info: [String: Any] = [:]
    private static var identity = ""
    private static var shown = ""
    private static var video: URL?
    private static var image: UIImage?
    private static var export: AVAssetExportSession?
    private static var preparing = ""
    private static var revision = 0
    private static var observer: NSObjectProtocol?
    static private(set) var status = "Off"
    static func start() {
        ASMLockScreenInstall()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 0.5, leeway: .milliseconds(40))
        source.setEventHandler { tick() }; source.resume(); timer = source
        observer = NotificationCenter.default.addObserver(forName: .asmArtworkChanged, object: nil, queue: nil) { _ in
            DispatchQueue.main.async { identity = ""; tick() }
        }
    }
    @objc static func receive(_ value: NSDictionary?) {
        info = value as? [String: Any] ?? [:]
        tick()
    }
    private static var title: String { info[MPMediaItemPropertyTitle] as? String ?? "" }
    private static var artist: String { info[MPMediaItemPropertyArtist] as? String ?? "" }
    static func tick() {
        let mode = UserDefaults.asmLockMode
        guard mode != .off, !title.isEmpty, let track = KaraokePlaybackTracker.shared.playerReportedTrackId(),
              KaraokePlaybackTracker.shared.matchesNowPlaying(title: title) else {
            if !shown.isEmpty || !identity.isEmpty {
                revision += 1; export?.cancelExport(); export = nil; video = nil; image = nil; identity = ""; shown = ""; preparing = ""
                ASMLockScreenPublish([:], "", "")
            }
            status = "Off"; return
        }
        let animate = !UIAccessibility.isReduceMotionEnabled && !(UserDefaults.asmArtworkOptions.lowPowerStill && ProcessInfo.processInfo.isLowPowerModeEnabled)
        let key = track + "/" + title + "/" + artist + "/" + mode.rawValue + "/" + String(animate)
        if key != identity {
            revision += 1; export?.cancelExport(); export = nil; preparing = ""
            identity = key; shown = ""; video = nil
            image = (info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)?.image(at: CGSize(width: 600, height: 600))
            ASMLockScreenPublish([:], title, artist)
            if mode.hasVideo, animate, ASMLockScreenAnimationAvailable(), let album = ASMArtworkAlbum.current() {
                status = "Finding album video…"
                ASMArtworkRepository.shared.lookup(album, options: UserDefaults.asmArtworkOptions) { url in
                    guard identity == key, let url else { return }
                    prepareVideo(url, identity: key)
                }
            }
        }
        if image == nil {
            image = (info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)?.image(at: CGSize(width: 600, height: 600))
        }
        guard let image else { status = "Waiting for Spotify cover artwork"; return }
        let lyrics = mode.hasLyrics ? KaraokeLyricsStore.shared.lyrics(forTrackId: track) : nil
        if mode.hasLyrics && lyrics == nil { ASMInterfaceHost.requestLyrics(track) }
        let position = KaraokePlaybackTracker.shared.currentPositionMs()
        let line = lyrics?.lines.last { $0.startMs <= position && $0.endMs > position }
        let text = line?.plainText ?? ""
        let displayKey = key + "/" + text + "/" + String(video != nil)
        guard displayKey != shown else { return }
        shown = displayKey
        let preview = mode.hasLyrics && !text.isEmpty ? draw(image, text: text) : image
        var extras: [String: Any] = [:]
        if mode.hasLyrics && !text.isEmpty { extras[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: preview.size) { _ in preview } }
        if let video {
            if mode == .combined && !text.isEmpty { compose(video, text: text, preview: preview, key: displayKey) }
            else { extras.merge(ASMLockScreenAnimated(video, preview, displayKey) as? [String: Any] ?? [:]) { _, new in new } }
        }
        ASMLockScreenPublish(extras, title, artist)
        status = mode.hasVideo && !ASMLockScreenAnimationAvailable() ? "Animated artwork needs iOS 26; lyric cover fallback active" : video == nil && mode.hasVideo ? "Album video unavailable or preparing; using cover" : "Active · phone verification required in LiveContainer"
    }
    private static var cache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ASMLockArtwork", isDirectory: true)
    }
    private static func trim() {
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let urls = (try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        var total = 0
        for url in urls.sorted(by: { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }) {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if total > 120 * 1024 * 1024 && url != video { try? FileManager.default.removeItem(at: url) }
        }
    }
    private static func prepareVideo(_ url: URL, identity key: String) {
        guard preparing != key else { return }; preparing = key
        trim()
        let asset = AVURLAsset(url: url, options: [AVURLAssetAllowsCellularAccessKey: !UserDefaults.asmArtworkOptions.wifiOnly,
                                                 AVURLAssetAllowsExpensiveNetworkAccessKey: !UserDefaults.asmArtworkOptions.wifiOnly,
                                                 AVURLAssetAllowsConstrainedNetworkAccessKey: false])
        let token = revision
        asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) {
            DispatchQueue.main.async {
                guard identity == key, revision == token, asset.statusOfValue(forKey: "tracks", error: nil) == .loaded,
                      let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else { return }
                let output = cache.appendingPathComponent(UUID().uuidString + ".mp4")
                session.outputURL = output; session.outputFileType = .mp4; session.shouldOptimizeForNetworkUse = true
                let seconds = CMTimeGetSeconds(asset.duration)
                guard seconds.isFinite, seconds > 0 else { return }
                session.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: min(seconds, 8), preferredTimescale: 600))
                export = session
                session.exportAsynchronously {
                    DispatchQueue.main.async {
                        guard identity == key, revision == token else { try? FileManager.default.removeItem(at: output); return }
                        export = nil
                        if session.status == .completed { video = output; shown = ""; tick() }
                        else { status = "Video export unavailable; using cover"; try? FileManager.default.removeItem(at: output) }
                    }
                }
            }
        }
    }
    private static func draw(_ cover: UIImage, text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600))
        return renderer.image { context in
            let scale = max(600 / max(1,cover.size.width), 600 / max(1,cover.size.height))
            let size = CGSize(width: cover.size.width * scale, height: cover.size.height * scale)
            cover.draw(in: CGRect(x: (600-size.width)/2, y: (600-size.height)/2, width: size.width, height: size.height))
            UIColor.black.withAlphaComponent(0.5).setFill(); context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            (text as NSString).draw(in: CGRect(x: 36, y: 350, width: 528, height: 220), withAttributes: [.font: UIFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph])
        }
    }
    private static func compose(_ url: URL, text: String, preview: UIImage, key: String) {
        // One bounded export at a time. A newer line invalidates the completion;
        // the still lyric cover is already visible while the clip is prepared.
        guard export == nil else { return }
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first,
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else { return }
        let composition = AVMutableVideoComposition(propertiesOf: asset)
        let size = composition.renderSize
        let root = CALayer(); root.frame = CGRect(origin: .zero, size: size)
        let picture = CALayer(); picture.frame = root.bounds; root.addSublayer(picture)
        let label = CATextLayer(); label.frame = CGRect(x: size.width * 0.06, y: size.height * 0.08, width: size.width * 0.88, height: size.height * 0.36)
        label.string = text; label.font = UIFont.boldSystemFont(ofSize: size.width * 0.055).fontName as CFString; label.fontSize = size.width * 0.055
        label.alignmentMode = .center; label.isWrapped = true; label.foregroundColor = UIColor.white.cgColor
        label.shadowColor = UIColor.black.cgColor; label.shadowOpacity = 1; label.shadowRadius = 5; label.contentsScale = 2
        root.addSublayer(label)
        composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: picture, in: root)
        _ = track // asset track validates that the composition has picture content.
        let output = cache.appendingPathComponent(UUID().uuidString + ".mp4")
        session.outputURL = output; session.outputFileType = .mp4; session.videoComposition = composition; session.shouldOptimizeForNetworkUse = true
        let token = revision; export = session
        session.exportAsynchronously {
            DispatchQueue.main.async {
                guard revision == token else { try? FileManager.default.removeItem(at: output); return }
                export = nil
                guard shown == key else {
                    try? FileManager.default.removeItem(at: output); shown = ""; tick(); return
                }
                guard session.status == .completed else { try? FileManager.default.removeItem(at: output); status = "Animated lyric export unavailable; using lyric cover"; return }
                ASMLockScreenPublish(ASMLockScreenAnimated(output, preview, key), title, artist)
                trim()
            }
        }
    }
}
