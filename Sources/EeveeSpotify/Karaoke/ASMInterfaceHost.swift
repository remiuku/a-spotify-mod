import UIKit
import SwiftUI
import EeveeSpotifyC

/// Objective-C boundary shared by the two isolated ports. No port owns the
/// source chain, seek validation or audio processing a second time.
@objc(ASMInterfaceHost)
final class ASMInterfaceHost: NSObject {
    private static var payloads: [String: NSDictionary] = [:]
    private static var requesting = Set<KaraokeLookupKey>()
    private static var requested = Set<KaraokeLookupKey>()
    private static let requests = KaraokeLookupRequests<KaraokeLookupKey, Bool>()
    private static var observer: NSObjectProtocol?

    private static var launchObservers: [NSObjectProtocol] = []
    static func start() {
        _ = ASMInterfaceMode.active // Decide recovery before either module installs hooks.
        ASMLockScreenHost.start()
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.didEnterBackgroundNotification, UIApplication.willTerminateNotification] {
            launchObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
                DispatchQueue.main.async {
                    if notification.name != UIApplication.didBecomeActiveNotification { ASMInterfaceMode.finishLaunch(); return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                        guard UIApplication.shared.applicationState == .active,
                              WindowHelper.shared.rootViewController.viewIfLoaded?.window != nil else { return }
                        ASMInterfaceMode.finishLaunch()
                    }
                }
            })
        }

        observer = NotificationCenter.default.addObserver(forName: .eeveeKaraokeLyricsChanged, object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                payloads.removeAll()
                NotificationCenter.default.post(name: Notification.Name("ASMInterfaceLyricsChanged"), object: nil)
            }
        }
        launchObservers.append(NotificationCenter.default.addObserver(forName: Notification.Name("ASMSongLyricsChanged"), object: nil, queue: .main) { note in
            guard let track = note.object as? String else { return }
            requested = requested.filter { $0.trackId != track }
            payloads[track] = nil
            requestLyrics(track)
        })
    }

    @objc static func trackID() -> String? { KaraokePlaybackTracker.shared.currentTrackId() }
    @objc static func renderer() -> String { UserDefaults.karaokeOptions.renderer.rawValue }
    @objc static func selectRenderer(_ value: String) {
        guard let choice = KaraokeRenderer(rawValue: value) else { return }
        ASMActivityRecorder.store.record("settings.lyrics", ["viewer": value, "origin": "imported_interface"])
        var options = UserDefaults.karaokeOptions; options.renderer = choice
        UserDefaults.karaokeOptions = options
        ASMInterfaceCloseInlineLyrics(ASMInterfaceMode.active.rawValue)
        NotificationCenter.default.post(name: Notification.Name("ASMViewerChanged"), object: nil)
        if !KaraokeOverlayPresenter.isPresented {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { KaraokeOverlayPresenter.present() }
        }
    }

    @objc static func positionMs() -> Int { KaraokePlaybackTracker.shared.currentLyricPositionMs() }
    @objc static func seek(_ milliseconds: Int) {
        _ = KaraokePlaybackTracker.shared.seek(toLineStartMs: milliseconds, trackId: trackID())
    }
    @objc static func makeCreditsView() -> UIView { ASMPinnedCreditsView(frame: .zero) }
    @objc static func customLyricsAvailable() -> Bool { KaraokeOverlayPresenter.isAvailableForCurrentTrack() }
    @objc static func presentLyrics() { KaraokeOverlayPresenter.present() }
    @objc static func openSettings() {
        let nav = UINavigationController()
        let page = EeveeSettingsViewController(nav.view.frame, settingsView: AnyView(EeveeSettingsView(navigationController: nav)), navigationTitle: ASMBrand.name)
        nav.setViewControllers([page], animated: false)
        nav.overrideUserInterfaceStyle = .dark
        var top: UIViewController? = WindowHelper.shared.rootViewController
        while let next = top?.presentedViewController { top = next }
        top?.present(nav, animated: true)
    }
    @objc static func openQuickSound() {
        var top: UIViewController? = WindowHelper.shared.rootViewController
        while let next = top?.presentedViewController { top = next }
        let page = UIHostingController(rootView: ASMAudioQuickView())
        page.overrideUserInterfaceStyle = .dark
        top?.present(page, animated: true)
    }
    @objc static func openSoundSettings() {
        let nav = UINavigationController()
        SettingsNavigator.navigationController = nav
        let page = EeveeSettingsViewController(nav.view.frame, settingsView: AnyView(ASMAudioSettingsView()), navigationTitle: "Sound")
        nav.setViewControllers([page], animated: false)
        nav.overrideUserInterfaceStyle = .dark
        var top: UIViewController? = WindowHelper.shared.rootViewController
        while let next = top?.presentedViewController { top = next }
        top?.present(nav, animated: true)
    }
    @objc static func isLooking(_ track: String) -> Bool { requesting.contains(KaraokeLookupKey(trackId: track)) }

    @objc static func requestLyrics(_ track: String) {
        let key = KaraokeLookupKey(trackId: track)
        guard ASMSongLyricsContext.source(track).supportsCustomLyricsView,
              !requested.contains(key), !requesting.contains(key) else { return }
        requested.insert(key)
        if KaraokeLyricsStore.shared.validatedLyrics(trackId: track, signature: key.signature) != nil { return }
        requesting.insert(key)
        requests.request(key, operation: {
            _ = try loadCustomLyricsForTrackId(track, updatesNativeState: false)
            guard key == KaraokeLookupKey(trackId: track) else { return false }
            return KaraokeLyricsStore.shared.validatedLyrics(trackId: track, signature: key.signature) != nil
        }) { _ in
            requesting.remove(key)
            NotificationCenter.default.post(name: Notification.Name("ASMInterfaceLyricsChanged"), object: nil)
        }
    }

    @objc static func lyrics(_ track: String) -> NSDictionary? {
        if let payload = payloads[track] { return payload }
        guard let lyrics = KaraokeLyricsStore.shared.validatedLyrics(trackId: track, signature: ASMSongLyricsContext.signature(track)) else { return nil }
        func words(_ syllables: [KaraokeSyllableDto]) -> [[String: Any]] {
            var joined = false
            return syllables.map { syllable in
                defer { joined = syllable.isPartOfWord }
                return ["text": syllable.text, "start": syllable.startMs, "end": syllable.endMs, "joined": joined]
            }
        }
        let lines: [[String: Any]] = lyrics.lines.map { line in
            let syllables = line.sweetSyllables ?? line.syllables
            var value: [String: Any] = ["words": words(syllables), "start": line.startMs, "end": line.endMs,
                    "align": line.oppositeAligned ? 1 : 0,
                    "timing": line.endMs == 0 ? 2 : (syllables.contains { $0.endMs > $0.startMs } ? 0 : 1),
                    "backing": line.backgroundGroups.map { ["words": words($0), "start": $0.first?.startMs ?? line.startMs, "end": $0.last?.endMs ?? line.endMs] }]
            if let translation = line.translation { value["translation"] = translation }
            if let pronunciation = line.pronunciation { value["pronunciation"] = pronunciation }
            return value
        }
        let payload: NSDictionary = ["lines": lines, "credit": lyrics.providerName ?? "", "revision": UUID().uuidString]
        payloads[track] = payload
        return payload
    }
}
