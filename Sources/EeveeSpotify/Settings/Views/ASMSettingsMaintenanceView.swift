import SwiftUI
import UIKit

struct ASMSettingsMaintenanceView: View {
    let reset: Bool

    
    @State private var hasShownCommonIssuesTip = UserDefaults.hasShownCommonIssuesTip
    @State private var isClearingData = false

    private func exportDebugLog() {
        guard let data = FileManager.default.contents(atPath: EeveeLog.path), !data.isEmpty else {
            PopUpHelper.showPopUp(message: "no_debug_log_found".localized, buttonText: "no_debug_log_found_ok".localized)
            return
        }
        let share = UIActivityViewController(activityItems: [URL(fileURLWithPath: EeveeLog.path)], applicationActivities: nil)
        if let popover = share.popoverPresentationController, let view = SettingsNavigator.navigationController?.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        WindowHelper.shared.present(share)
    }

    private func clearDebugLog() {
        EeveeLog.clear()
        writeDebugLog("Log cleared by user")
        PopUpHelper.showPopUp(message: "debug_log_cleared".localized, buttonText: "debug_log_cleared_ok".localized)
    }

    private func wipe(_ work: @escaping () -> Void) {
        isClearingData = true
        DispatchQueue.global(qos: .userInitiated).async {
            work()
            DispatchQueue.main.async { exitApplication() }
        }
    }

    var body: some View {
        List {
            if !reset {
            ASMActivityLogSection()
            if !hasShownCommonIssuesTip {
                CommonIssuesTipView(
                    onDismiss: {
                        hasShownCommonIssuesTip = true
                        UserDefaults.hasShownCommonIssuesTip = true
                    }
                )
            }
            
            Section(header: ASMText("troubleshooting".localized), footer: ASMText("debug_section_footer".localized)) {
                ASMToggle(
                    "debug_logging".localized,
                    isOn: Binding<Bool>(
                        get: { UserDefaults.debugLoggingEnabled },
                        set: { UserDefaults.debugLoggingEnabled = $0 }
                    )
                )

                Button(action: exportDebugLog) {
                    SettingsLabel(title: "export_debug_log".localized, icon: "square.and.arrow.up", color: .blue)
                }
                Button(action: clearDebugLog) {
                    SettingsLabel(title: "clear_debug_log".localized, icon: "trash.fill", color: .gray)
                }
            }

            } else {
            Section(header: ASMText("reset_section".localized), footer: ASMText("reset_section_footer".localized)) {
                Button {
                    confirmDestructive(title: "reset_data".localized, message: "reset_data_description".localized, confirm: "reset_data".localized) {
                        wipe { OfflineHelper.resetData(clearCaches: true) }
                    }
                } label: {
                    SettingsLabel(title: "reset_data".localized, subtitle: "reset_data_subtitle".localized, icon: "arrow.counterclockwise", color: .orange)
                }
                Button {
                    confirmDestructive(title: "resetButtonTitle".localized, message: "resetFooter".localized, confirm: "resetButtonTitle".localized) {
                        wipe { FullResetHelper.wipeSpotifyState() }
                    }
                } label: {
                    SettingsLabel(title: "resetButtonTitle".localized, subtitle: "full_reset_subtitle".localized, icon: "exclamationmark.triangle.fill", color: .red)
                }
            }
            .disabled(isClearingData)

            }
            SpacerView()
        }
        .eeveeSettingsStyle()
        
        .animation(.default, value: isClearingData)
        .animation(.default, value: hasShownCommonIssuesTip)

        .onAppear {
            WindowHelper.shared.overrideUserInterfaceStyle(.dark)
        }
    }
}
