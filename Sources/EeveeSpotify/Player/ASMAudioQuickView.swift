import SwiftUI
import EeveeSpotifyC

/// Uses the same setters as Sound & playback; never installs a second engine.
struct ASMAudioQuickView: View {
    @State private var speed = SGPlayerSpeed()
    @State private var pitch = Double(SGPlayerPitch())
    @State private var dsp = SGDSPSwitch("asm.dsp")
    @State private var gain = SGDSPNumber("asm.dsp.postGain")
    @State private var bass = SGDSPSwitch("asm.dsp.bass")
    @State private var reverb = SGDSPSwitch("asm.dsp.reverb")
    @State private var wide = SGDSPSwitch("asm.dsp.wide")
    @State private var status = SGDSPStatus() ?? ""
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        List {
            Section(header: ASMText("Quick sound controls")) {
                slider("Speed", value: $speed, range: 0.25...4, step: 0.05, unit: "×")
                HStack { ForEach([0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                    Button(String(format: "%g×", value)) { speed = value }.buttonStyle(.bordered)
                } }
                slider("Pitch", value: $pitch, range: -12...12, step: 1, unit: "st")
                ASMButton("Reset speed & pitch") { speed = 1; pitch = 0 }
            }
            Section(footer: ASMText(status)) {
                ASMToggle("JamesDSP", isOn: $dsp)
                slider("Output gain", value: $gain, range: -15...15, step: 0.5, unit: "dB")
                ASMToggle("Bass boost", isOn: $bass)
                ASMToggle("Reverb", isOn: $reverb)
                ASMToggle("Stereo widening", isOn: $wide)
                ASMText("Effect switches use your saved amounts and need JamesDSP enabled.").font(.footnote).foregroundColor(.secondary)
            }
            Section { Button("All sound settings") { ASMInterfaceHost.openSoundSettings() } }
        }.eeveeSettingsStyle()
            .onChange(of: speed) { SGSetPlayerSpeed($0) }
            .onChange(of: pitch) { SGSetPlayerPitch(Float($0)) }
            .onChange(of: dsp) { SGDSPSetSwitch("asm.dsp", $0) }
            .onChange(of: gain) { SGDSPSetNumber("asm.dsp.postGain", $0) }
            .onChange(of: bass) { SGDSPSetSwitch("asm.dsp.bass", $0) }
            .onChange(of: reverb) { SGDSPSetSwitch("asm.dsp.reverb", $0) }
            .onChange(of: wide) { SGDSPSetSwitch("asm.dsp.wide", $0) }
            .onReceive(tick) { _ in status = SGDSPStatus() ?? "" }
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack { ASMText(title); Spacer(); ASMText(String(format: "%.2f %@", value.wrappedValue, unit)).monospacedDigit() }
            Slider(value: value, in: range, step: step)
        }
    }
}
