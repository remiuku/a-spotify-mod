import SwiftUI
import UIKit

struct EeveeExperimentsSettingsView: View {
    @State var experimentsOptions = UserDefaults.experimentsOptions

    var body: some View {
        List {
            Section(footer: ASMText("livecontainer_sharing_description".localized)) {
                ASMToggle(
                    "livecontainer_sharing".localized,
                    isOn: $experimentsOptions.liveContainerSharing
                )
            }
            
            Section(
                footer: ASMText("show_instagram_destination_description"
                    .localizeWithFormat("restart_is_required_description".localized))
            ) {
                ASMToggle(
                    "show_instagram_destination".localized,
                    isOn: $experimentsOptions.showInstagramDestination
                )
            }

        }
        .onChange(of: experimentsOptions) { options in
            UserDefaults.experimentsOptions = options
            
            if options.showInstagramDestination {
                OfflineHelper.resetData()
            }
        }
        
        .eeveeSettingsStyle()
        .animation(.default, value: experimentsOptions)
    }
}
