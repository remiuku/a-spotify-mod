import UIKit
import SwiftUI
import EeveeSpotifyC

/// Presents the custom karaoke lyrics view as a full-screen modal, on top
/// of whatever screen is currently shown — the "overlay" approach (Option D)
/// rather than replacing Spotify's native LyricsViewControllerImplementation,
/// since that would need a live-runtime hook point we weren't able to find
/// safely (Spotify's anti-instrumentation protections crash on Frida attach
/// before enumeration/hooking can happen).
final class KaraokeOverlayPresenter {
    private static var presentation = ASMLyricsPresentationState()
    private static weak var presentedController: UIViewController?
    static var isPresented: Bool { presentation.isPresented }

    static func present() {
        ASMActivityRecorder.store.record("lyrics.open", ["viewer": UserDefaults.karaokeOptions.renderer.rawValue])
        guard !isPresented else { return }
        if UserDefaults.karaokeOptions.renderer == .spotify {
            if !ASMOpenSpotifyLyrics() {
                let alert = UIAlertController(title: "Spotify lyrics", message: "Spotify hasn't provided a native lyrics page for this track. You can choose a custom viewer to search your other lyric sources.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                topVC()?.present(alert, animated: true)
            }
            return
        }
        guard UserDefaults.karaokeOptions.enabled, ASMSongLyricsContext.source(KaraokePlaybackTracker.shared.currentTrackId()).supportsCustomLyricsView else {
            writeDebugLog("[Karaoke] present() skipped: custom lyrics view disabled in settings or unsupported by the lyrics source")
            return
        }
        guard #available(iOS 15.0, *) else {
            writeDebugLog("[Karaoke] present() skipped: requires iOS 15+")
            return
        }
        guard let host = topVC() else {
            writeDebugLog("[Karaoke] present() called but no top view controller found")
            return
        }
        guard isAvailableForCurrentTrack() else { return }

        guard let token = presentation.begin() else { return }
        let dismiss: () -> Void = { dismissOwned(token) }
        let hosting = ASMLyricsHostingController(rootView: KaraokeLookupView(onDismiss: dismiss).modifier(ASMWhimsyRefresh()))
        hosting.onRemoved = { removed(token) }
        hosting.overrideUserInterfaceStyle = .dark
        let mild = UserDefaults.mildLyricsOptions
        let glass = KaraokeBackdropPolicy.presentsTransparently(
            isSweet: UserDefaults.karaokeOptions.renderer == .sweetLyrics,
            mildEnabled: mild.flag("enabled"), mildBackground: mild.choice("background"),
            glassEnabled: KaraokeGlass.isEnabled)
        hosting.modalPresentationStyle = glass ? .overFullScreen : .fullScreen
        hosting.view.backgroundColor = glass ? .clear : .black

        presentedController = hosting
        host.present(hosting, animated: true)
    }

    static func switchToSpotify() {
        guard let token = presentation.token else { present(); return }
        dismissOwned(token) { present() }
    }

    private static func dismissOwned(_ token: UInt64, completion: (() -> Void)? = nil) {
        guard presentation.beginDismiss(token) else { return }
        ASMActivityRecorder.store.record("lyrics.close")
        guard let owned = presentedController else {
            removed(token); completion?(); return
        }
        // Dismiss this lyrics controller and its sheets, even when Sound or
        // settings is currently on top. Never dismiss an unrelated top page.
        owned.dismiss(animated: true) {
            removed(token)
            completion?()
        }
    }

    private static func removed(_ token: UInt64) {
        if presentation.finish(token) { presentedController = nil }
    }

    /// Access depends on the playing music track and settings, never Spotify's
    /// has_lyrics flag or whether a previous native request filled the cache.
    static func isAvailableForCurrentTrack() -> Bool {
        guard UserDefaults.karaokeOptions.enabled,
              UserDefaults.karaokeOptions.renderer == .spotify || ASMSongLyricsContext.source(KaraokePlaybackTracker.shared.currentTrackId()).supportsCustomLyricsView else { return false }
        return KaraokePlaybackTracker.shared.currentTrackId() != nil
    }

    /// Walks from WindowHelper's captured-at-launch root view controller
    /// (NOT a fresh `UIApplication.shared...windows` lookup) down to
    /// whatever's actually topmost right now.
    private static func topVC() -> UIViewController? {
        var top = WindowHelper.shared.rootViewController
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class ASMLyricsHostingController<Content: View>: UIHostingController<Content> {
    var onRemoved: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { onRemoved?() }
    }
}
