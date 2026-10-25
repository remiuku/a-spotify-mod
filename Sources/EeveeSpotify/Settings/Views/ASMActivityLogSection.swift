import SwiftUI
import UIKit

struct ASMActivityLogSection: View {
    @State private var enabled = ASMActivityRecorder.store.isEnabled
    @State private var busy = false
    @State private var message = ""
    @State private var showMessage = false

    var body: some View {
        Section(header: ASMText("Activity recording"), footer: ASMText("Records taps, screens, playback, lyrics changes and mod errors on this device. Keeps recent events across restarts, up to 2 MB. Typed text, passwords and request contents are excluded. Enable it before reproducing a problem, then export the recording.")) {
            ASMToggle("Record my activity", isOn: Binding(get: { enabled }, set: {
                enabled = $0
                ASMActivityRecorder.setEnabled($0)
            }))
            ASMText(enabled ? "Recording · recent actions and UI stalls" : "Off · saved recordings remain available")
                .font(.footnote).foregroundColor(.secondary)
            Button(action: export) {
                SettingsLabel(title: "Export activity recording", icon: "square.and.arrow.up", color: .blue)
            }.disabled(busy)
            Button(action: clear) {
                SettingsLabel(title: "Clear activity recording", icon: "trash.fill", color: .gray)
            }.disabled(busy)
        }
        .onAppear { enabled = ASMActivityRecorder.store.isEnabled }
        .alert("Activity recording", isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: { Text(message) }
    }

    private func export() {
        busy = true
        ASMActivityRecorder.store.export { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let url):
                    let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let popover = share.popoverPresentationController, let view = SettingsNavigator.navigationController?.view {
                        popover.sourceView = view
                        popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                    }
                    WindowHelper.shared.present(share)
                case .failure:
                    message = "No recording could be exported. Enable recording and reproduce the problem first."
                    showMessage = true
                }
            }
        }
    }

    private func clear() {
        busy = true
        ASMActivityRecorder.store.clear { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success: message = "Activity recording cleared."
                case .failure: message = "The recording could not be cleared."
                }
                showMessage = true
            }
        }
    }
}
