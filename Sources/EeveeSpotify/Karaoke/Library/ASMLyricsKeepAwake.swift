import SwiftUI

private enum ASMLyricsWakeOwners {
    static var owners = Set<UUID>()
    static var previous: Bool?
    static func set(_ owner: UUID, active: Bool) {
        precondition(Thread.isMainThread)
        if active {
            guard owners.insert(owner).inserted else { return }
            if previous == nil { previous = UIApplication.shared.isIdleTimerDisabled }
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            guard owners.remove(owner) != nil, owners.isEmpty, let saved = previous else { return }
            UIApplication.shared.isIdleTimerDisabled = saved; previous = nil
        }
    }
}

struct ASMLyricsKeepAwake: ViewModifier {
    @State private var owner = UUID()
    @State private var visible = false
    @State private var foreground = true
    func body(content: Content) -> some View {
        content.onAppear { visible = true; foreground = UIApplication.shared.applicationState == .active; update() }
            .onDisappear { visible = false; update() }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in update() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in foreground = false; update() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in foreground = false; update() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in foreground = true; update() }
    }
    private func update() {
        ASMLyricsWakeOwners.set(owner, active: ASMLyricsWakePolicy.active(visible: visible, foreground: foreground,
            enabled: UserDefaults.standard.bool(forKey: "asm.lyrics.keepAwake"), playing: KaraokePlaybackTracker.shared.isPlaying(),
            musicTrack: KaraokePlaybackTracker.shared.currentTrackId() != nil))
    }
}
