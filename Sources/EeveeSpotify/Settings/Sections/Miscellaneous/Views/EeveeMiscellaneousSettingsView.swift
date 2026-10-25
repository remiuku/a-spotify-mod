import SwiftUI
import UIKit

struct EeveeMiscellaneousSettingsView: View {
    @State private var blockTelemetry = UserDefaults.blockTelemetry
    @State private var cleanShareLinks = UserDefaults.cleanShareLinks
    @State private var blockRatingPrompts = UserDefaults.blockRatingPrompts

    var body: some View {
        List {
            Section(footer: ASMText("block_telemetry_footer".localized)) {
                ASMToggle("block_telemetry".localized, isOn: $blockTelemetry)
            }

            Section(footer: ASMText("block_rating_prompts_footer".localized)) {
                ASMToggle("block_rating_prompts".localized, isOn: $blockRatingPrompts)
            }

            Section(footer: ASMText("clean_share_links_description".localized)) {
                ASMToggle("clean_share_links".localized, isOn: $cleanShareLinks)
            }

            RestartSection(visible: blockTelemetry != TelemetryBlock.launchEnabled || blockRatingPrompts != RatingPromptBlock.launchEnabled)

            SpacerView()
        }
        .eeveeSettingsStyle()
        .onChange(of: blockTelemetry) { UserDefaults.blockTelemetry = $0 }
        .onChange(of: cleanShareLinks) { UserDefaults.cleanShareLinks = $0 }
        .onChange(of: blockRatingPrompts) { UserDefaults.blockRatingPrompts = $0 }
    }
}
