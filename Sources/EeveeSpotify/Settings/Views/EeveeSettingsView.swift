import SwiftUI
import UIKit

struct EeveeSettingsView: View {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        SettingsNavigator.navigationController = navigationController
    }

    var body: some View {
        List {
            Section { SettingsHero() }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            Section {
                ForEach(ASMMenuRoute.root.children) { ASMMenuLink(route: $0) }
            }
            SpacerView()
        }.eeveeSettingsStyle()
            .onAppear { WindowHelper.shared.overrideUserInterfaceStyle(.dark) }
    }
}
