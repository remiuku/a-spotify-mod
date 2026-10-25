import SwiftUI

struct ASMMenuLink: View {
    let route: ASMMenuRoute
    var body: some View {
        Button {
            ASMActivityRecorder.store.record("settings.open", ["page": route.rawValue])
            SettingsNavigator.push(ASMMenuDestination(route: route), title: route.titleKey.localized)
        } label: {
            SettingsLabel(title: route.titleKey.localized, subtitle: route.subtitleKey.localized,
                          icon: route.symbol, color: EeveeTheme.accent, chevron: true)
        }
    }
}

struct ASMMenuPage: View {
    let route: ASMMenuRoute
    var body: some View {
        List {
            Section { ForEach(route.children) { ASMMenuLink(route: $0) } }
            if route == .advanced {
                Section {
                    ASMText(":3").font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1.5) {
                            if #available(iOS 15.0, *) {
                                SettingsNavigator.push(ASMDancerSettingsView(), title: "Dancing boykisser")
                            }
                        }
                }
            }
            SpacerView()
        }.eeveeSettingsStyle()
    }
}

struct ASMMenuDestination: View {
    let route: ASMMenuRoute
    @ViewBuilder var body: some View {
        switch route {
        case .root, .look, .layout, .advanced: ASMMenuPage(route: route)
        case .lyrics: EeveeLyricsSettingsView()
        case .sound: ASMAudioSettingsView()
        case .about: ASMResourcesView()
        case .presets: ASMCustomizationView()
        case .interface: ASMInterfaceSettingsView()
        case .viewers: ASMViewerSettingsView()
        case .theme: AppearanceSettingsView()
        case .covers: ASMArtworkSettingsView()
        case .player: PlayerSettingsView()
        case .nowPlayingBar: NowPlayingBarSettingsView()
        case .tabs: TabBarSettingsView()
        case .home: HomeSettingsView()
        case .playlist: PlaylistSettingsView()
        case .artist: ArtistSettingsView()
        case .background: BackgroundColorView()
        case .glass: LiquidGlassSettingsView()
        case .appIcon: EeveeAppIconPickerView()
        case .patching: EeveePatchingSettingsView()
        case .features: SpotifyFeaturesView()
        case .flags: FlagBrowserView()
        case .experiments: EeveeExperimentsSettingsView()
        case .privacy: EeveeMiscellaneousSettingsView()
        case .troubleshooting: ASMSettingsMaintenanceView(reset: false)
        case .reset: ASMSettingsMaintenanceView(reset: true)
        case .sponsorBlock: SponsorBlockSettingsView()
        case .mildDisplay: MildLyricsSettingsView(page: .display)
        case .mildSources: MildLyricsSettingsView(page: .sources)
        case .funLyrics: MildLyricsSettingsView(page: .playful)
        case .lyricColours: EeveeUISettingsView(showPopups: false)
        }
    }
}
