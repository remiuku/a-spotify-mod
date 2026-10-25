import SwiftUI
import UIKit

struct EeveeUISettingsView: View {
    var showPopups = true
    @State var lyricsColors = UserDefaults.lyricsColors

    var body: some View {
        List {
            if UserDefaults.lyricsSource.isReplacingLyrics {
                Section(
                    header: ASMText("lyrics_background_color_section".localized),
                    footer: ASMText("lyrics_background_color_section_description".localized)
                ) {
                    ASMToggle(
                        "display_original_colors".localized,
                        isOn: $lyricsColors.displayOriginalColors
                    )
                    
                    ASMToggle(
                        "use_static_color".localized,
                        isOn: $lyricsColors.useStaticColor
                    )
                    
                    if lyricsColors.useStaticColor {
                        ColorPicker(
                            "static_color".localized,
                            selection: Binding<Color>(
                                get: { Color(hex: lyricsColors.staticColor) },
                                set: { lyricsColors.staticColor = $0.hexString }
                            ),
                            supportsOpacity: false
                        )
                    }
                    else {
                        VStack(alignment: .leading, spacing: 5) {
                            ASMText("color_normalization_factor".localized)
                            
                            Slider(
                                value: $lyricsColors.normalizationFactor,
                                in: 0.2...0.8,
                                step: 0.1
                            )
                        }
                    }
                }
                .onChange(of: lyricsColors) { lyricsColors in
                    UserDefaults.lyricsColors = lyricsColors
                }
            }
            
            if showPopups { Section {
                ASMToggle(
                    "dark_popups".localized,
                    isOn: Binding<Bool>(
                        get: { UserDefaults.darkPopUps },
                        set: { UserDefaults.darkPopUps = $0 }
                    )
                )
            } }
            
            SpacerView()
        }
        
        .eeveeSettingsStyle()
        .animation(.default, value: lyricsColors)
    }
}
