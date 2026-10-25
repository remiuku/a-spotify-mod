// Spotify's App Shortcuts: what Siri answers to, what the Shortcuts app shows under Spotify before any
// shortcut is made, and what the Action button lists under Shortcut > Spotify. An app has one provider, and
// Spotify 9.1.78 has none of its own. Tweak only: the system reads it from the App Intents metadata
// scripts/build-extension.sh makes for Spotify, and a widget extension may not carry one.
// Every phrase names the app; the system's own media commands already own "next song" and "pause".
import AppIntents

@available(iOS 17.0, *)
struct ASMVitrineAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ASMVitrineLikeIntent(), phrases: [
            "Like this song in \(.applicationName)",
            "Add this song to Liked Songs in \(.applicationName)",
        ], shortTitle: "Like This Song", systemImageName: "heart")
        AppShortcut(intent: ASMVitrinePlayPauseIntent(), phrases: [
            "Play or pause \(.applicationName)",
        ], shortTitle: "Play or Pause", systemImageName: "playpause")
        AppShortcut(intent: ASMVitrineNextTrackIntent(), phrases: [
            "Skip this song in \(.applicationName)",
            "Next track in \(.applicationName)",
        ], shortTitle: "Next Track", systemImageName: "forward")
        AppShortcut(intent: ASMVitrinePreviousTrackIntent(), phrases: [
            "Previous track in \(.applicationName)",
        ], shortTitle: "Previous Track", systemImageName: "backward")
        AppShortcut(intent: ASMVitrineSingIntent(), phrases: [
            "\(\.$mode) Karaoke in \(.applicationName)",
            "Sing along in \(.applicationName)",
        ], shortTitle: "Karaoke", systemImageName: "music.mic")
        AppShortcut(intent: ASMVitrineSleepTimerIntent(), phrases: [
            "Set a sleep timer in \(.applicationName)",
            "Sleep timer \(\.$length) in \(.applicationName)",
        ], shortTitle: "Sleep Timer", systemImageName: "moon.zzz")
    }
}
