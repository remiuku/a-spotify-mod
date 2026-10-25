import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @State private var amoled = UserDefaults.amoled
    @AppStorage("eeveeAccent", store: UserDefaults.container) private var accent = -1
    @State private var roundedArtwork = UserDefaults.roundedArtwork
    @State private var glass = UserDefaults.liquidGlassOptions
    @State private var gradient = UserDefaults.homeGradient
    @State private var darkPopups = UserDefaults.darkPopUps
    private let colors: [(String, Int)] = [("Mint", 0x1ED760), ("Rose", 0xF78FB3), ("Lilac", 0xB89AF7), ("Ice", 0x7CD6EA), ("Amber", 0xFFC06E)]
    private let launchDarkPopups = UserDefaults.darkPopUps
    private let launchRounded = UserDefaults.roundedArtwork

    private var glassSubtitle: String {
        guard LiquidGlassSettingsView.supported else { return "liquid_glass_unsupported".localized }
        return (glass.enabled ? "state_on" : "state_off").localized
    }

    private var gradientSubtitle: String {
        let pages = GradientPage.allCases.filter(gradient.shownPages.contains)
        guard !pages.isEmpty else { return "state_off".localized }
        return pages.map { "home_gradient_page_\($0.rawValue)".localized }.joined(separator: ", ")
    }

    var body: some View {
        List {
            Section(header: ASMText("theme".localized), footer: ASMText("theme_footer".localized)) {
                SettingsToggle(title: "amoled".localized, icon: "moon.fill", color: Color(hex: "#3A3A3C"), isOn: $amoled)
                accentRow
                SettingsToggle(title: "rounded_artwork".localized, icon: "square.on.square", color: .orange, isOn: $roundedArtwork)
                SettingsToggle(title: "dark_popups".localized, icon: "rectangle.on.rectangle", color: .gray, isOn: $darkPopups)
            }

            Section {
                SettingsLink(
                    title: "background_color".localized, subtitle: gradientSubtitle, icon: "circle.lefthalf.fill",
                    color: Color(gradient.tintRGB.map(Theme.color) ?? Theme.accent)
                ) {
                    BackgroundColorView()
                }
                SettingsLink(title: "liquid_glass".localized, subtitle: glassSubtitle, icon: "drop.fill", color: Color(hex: "#30B0C7")) {
                    LiquidGlassSettingsView()
                }
            }

            Section(header: ASMText("asm_look_palette".localized), footer: ASMText("restart_is_required_description".localized)) {
                ForEach(colors, id: \.0) { name, color in
                    Button {
                        accent = color
                    } label: {
                        HStack { Circle().fill(Color(Theme.color(color))).frame(width: 24, height: 24); ASMText(name) }
                    }
                }
            }
            Section { ASMMenuLink(route: .appIcon) }

            SettingsResetSection(visible: amoled || accent >= 0 || roundedArtwork) {
                amoled = false
                accent = -1
                roundedArtwork = false
            }

            if amoled != Theme.launchAmoled || accent != Theme.launchAccent || roundedArtwork != launchRounded || darkPopups != launchDarkPopups {
                Section {
                    Button(action: exitApplication) {
                        ASMText("restart_now".localized).fontWeight(.semibold).frame(maxWidth: .infinity)
                    }
                    .foregroundColor(EeveeTheme.accent)
                }
            }

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: amoled) { UserDefaults.amoled = $0 }
        .onChange(of: roundedArtwork) { UserDefaults.roundedArtwork = $0 }
        .onChange(of: darkPopups) { UserDefaults.darkPopUps = $0 }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .eeveeTabBarOptionsChanged)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .eeveeHomeGradientChanged)) { _ in refresh() }
    }

    private func refresh() {
        glass = UserDefaults.liquidGlassOptions
        gradient = UserDefaults.homeGradient
    }

    private var accentRow: some View {
        HStack {
            ColorPicker(selection: Binding(
                get: { Color(Theme.color(Theme.accentOrGreen(accent))) },
                set: { accent = Theme.rgb(of: UIColor($0)) }
            ), supportsOpacity: false) {
                SettingsLabel(title: "accent_color".localized, icon: "paintpalette.fill", color: Color(Theme.color(Theme.accentOrGreen(accent))))
            }
            if accent >= 0 {
                Button { accent = -1 } label: { ASMImage(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(.secondary) }
                    .buttonStyle(.borderless)
            }
        }
    }
}
