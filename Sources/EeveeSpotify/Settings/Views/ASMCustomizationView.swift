import SwiftUI

struct ASMCustomizationView: View {
    @State private var slot = 1
    @State private var selectedStyle = ASMLookProfiles.selected(store: .container)
    @State private var message: String?
    var body: some View {
        List {
            Section(header: ASMText("asm_style_presets".localized), footer: ASMText("asm_style_hint".localized)) {
                ForEach(ASMLookPreset.allCases, id: \.rawValue) { preset in
                    Button {
                        if ASMLookProfiles.select(preset, supportsGlass: LiquidGlassSettingsView.supported, store: .container) {
                            selectedStyle = preset
                            didApplyLook()
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                ASMText(preset.titleKey.localized).font(.headline)
                                ASMText(preset.detailKey.localized).font(.footnote).foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                            if selectedStyle == preset { ASMImage(systemName: "checkmark.circle.fill").foregroundColor(EeveeTheme.accent) }
                        }.padding(.vertical, 4)
                    }
                    .disabled(preset.requiresGlass && !LiquidGlassSettingsView.supported)
                }
                if !LiquidGlassSettingsView.supported {
                    ASMText("asm_style_requires_glass".localized).font(.footnote).foregroundColor(.secondary)
                }
                if selectedStyle != .personal {
                    ASMButton("asm_style_reset".localized) {
                        if ASMLookProfiles.resetSelected(store: .container) { didApplyLook() }
                    }
                }
                ASMButton("restart_now".localized, action: exitApplication)
            }
            Section(header: ASMText("asm_look_profiles".localized), footer: ASMText("asm_look_profiles_hint".localized)) {
                ASMPicker("asm_look_slot".localized, selection: $slot) { ForEach(1...3, id: \.self) { ASMText("\($0)").tag($0) } }
                ASMButton("asm_look_save".localized) { ASMLookProfiles.save(slot: slot, store: .container); message = "asm_look_saved".localized }
                ASMButton("asm_look_restore".localized) {
                    if ASMLookProfiles.restore(slot: slot, store: .container) { didApplyLook() }
                }.disabled(UserDefaults.container.dictionary(forKey: "asm.look.\(slot)") == nil)
                if let message { ASMText(message).font(.footnote).foregroundColor(.secondary) }
            }
            RestartSection(visible: message == "asm_look_applied".localized)
        }.eeveeSettingsStyle().pickerStyle(.menu)
    }
    private func didApplyLook() {
        if !UserDefaults.liquidGlassOptions.enabled { LiquidGlass.clearDefaults() }
        for name in [Notification.Name.asmArtworkChanged, .eeveeTabBarOptionsChanged, .eeveePlaylistOptionsChanged,
                     .eeveeNowPlayingBarOptionsChanged, .eeveeHomeGradientChanged] {
            NotificationCenter.default.post(name: name, object: nil)
        }
        message = "asm_look_applied".localized
    }
}
