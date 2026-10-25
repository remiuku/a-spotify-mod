import SwiftUI
import EeveeSpotifyC
import UniformTypeIdentifiers
import Combine

struct ASMAudioSettingsView: View {
    @State private var speed = SGPlayerSpeed()
    @State private var pitch = Double(SGPlayerPitch())
    @State private var transformEnabled = SGPlayerSpeed() != 1 || SGPlayerPitch() != 0
    @State private var status = SGDSPStatus() ?? ""
    @State private var speedAvailable = SGPlayerSpeedAllowed()
    @State private var pitchAvailable = SGPlayerPitchAvailable()
    @State private var revision = 0
    @State private var preset = -1
    @State private var graphic = SGDSPString("asm.dsp.geq.nodes") ?? ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = revision
        return List {
            Section(header: ASMText("asm_audio_speed_pitch".localized), footer: ASMText("asm_audio_session_hint".localized)) {
                ASMToggle("asm_audio_transform_enabled".localized, isOn: $transformEnabled)
                valueSlider("asm_audio_speed".localized, value: $speed, range: 0.25...4, step: 0.05, unit: "×")
                    .disabled(!transformEnabled)
                valueSlider("asm_audio_pitch".localized, value: $pitch, range: -12...12, step: 1, unit: "st")
                    .disabled(!transformEnabled)
                if transformEnabled && (!speedAvailable || !pitchAvailable) {
                    ASMText("asm_audio_pending".localized).font(.footnote).foregroundColor(.secondary)
                }
                ASMButton("asm_audio_reset_speed".localized) { speed = 1; pitch = 0; transformEnabled = false }
            }
            Section { ASMMenuLink(route: .sponsorBlock) }
            Section(header: ASMText("asm_audio_effects".localized), footer: ASMText(status)) {
                switchRow("asm_audio_enabled", "asm.dsp")
                numberRow("asm_audio_gain", "asm.dsp.postGain", unit: "dB")
                numberRow("asm_audio_limiter", "asm.dsp.limiterThreshold", unit: "dB")
                numberRow("asm_audio_release", "asm.dsp.limiterRelease", unit: "ms")
            }
            Section(header: ASMText("asm_audio_eq".localized)) {
                switchRow("asm_audio_enabled", "asm.dsp.eq")
                ASMPicker("asm_audio_preset".localized, selection: $preset) {
                    ASMText("asm_audio_custom".localized).tag(-1)
                    ForEach(Array((SGDSPEqualizerPresetNames() ?? []).enumerated()), id: \.offset) { ASMText($0.element).tag($0.offset) }
                }
                .pickerStyle(.menu)
                choiceRow("asm_audio_filter", "asm.dsp.eq.filter", ["FIR minimum phase", "IIR 4", "IIR 6", "IIR 8", "IIR 10", "IIR 12"])
                choiceRow("asm_audio_interpolation", "asm.dsp.eq.interpolation", ["Cubic Hermite", "Modified Akima"])
                ForEach(Array([25,40,63,100,160,250,400,630,1000,1600,2500,4000,6300,10000,16000].enumerated()), id: \.offset) {
                    bandRow("\($0.element) Hz", "asm.dsp.eq.gains", index: $0.offset, limit: 12)
                }
            }
            Section(header: ASMText("asm_audio_bass".localized)) {
                switchRow("asm_audio_enabled", "asm.dsp.bass")
                numberRow("asm_audio_gain", "asm.dsp.bass.gain", unit: "dB")
            }
            Section(header: ASMText("asm_audio_compressor".localized)) {
                switchRow("asm_audio_enabled", "asm.dsp.compander")
                numberRow("asm_audio_response", "asm.dsp.compander.time", unit: "s")
                numberRow("asm_audio_granularity", "asm.dsp.compander.granularity")
                choiceRow("asm_audio_transform", "asm.dsp.compander.transform", ["Uniform FFT", "Multiresolution CWT", "Pseudo multiresolution", "Time domain"])
                ForEach(Array([95,200,400,800,1600,3400,7500].enumerated()), id: \.offset) {
                    bandRow("\($0.element) Hz", "asm.dsp.compander.gains", index: $0.offset, limit: 1.2)
                }
            }
            Section(header: ASMText("asm_audio_graphic".localized)) {
                switchRow("asm_audio_enabled", "asm.dsp.geq")
                TextField("GraphicEQ: 20 -1.2; 1000 0; …", text: $graphic).textInputAutocapitalization(.never).autocorrectionDisabled()
                ASMButton("asm_audio_apply".localized) { SGDSPSetString("asm.dsp.geq.nodes", graphic); revision += 1 }
                effectError("asm.dsp.geq")
            }
            Section(header: ASMText("asm_audio_space".localized)) {
                switchRow("asm_audio_reverb", "asm.dsp.reverb")
                choiceRow("asm_audio_preset", "asm.dsp.reverb.preset", ["Default", "Small hall 1", "Small hall 2", "Medium hall", "Large hall", "Small room 1", "Small room 2", "Medium room", "Large room", "Plate high", "Plate low", "Long reverb 1", "Long reverb 2"])
                switchRow("asm_audio_widen", "asm.dsp.wide")
                numberRow("asm_audio_width", "asm.dsp.wide.level", unit: "%")
                switchRow("asm_audio_crossfeed", "asm.dsp.crossfeed")
                choiceRow("asm_audio_mode", "asm.dsp.crossfeed.mode", ["BS2B weak", "BS2B strong", "Out of head", "Surround 1", "Surround 2", "Realistic surround"])
                switchRow("asm_audio_tube", "asm.dsp.tube")
                numberRow("asm_audio_drive", "asm.dsp.tube.drive", unit: "dB")
            }
            Section(header: ASMText("asm_audio_file_effects".localized)) {
                fileEffect("asm_audio_convolver", "asm.dsp.convolver", kind: 0)
                choiceRow("asm_audio_mode", "asm.dsp.convolver.mode", ["Original", "Shrink", "Minimum phase and shrink"])
                fileEffect("ViPER DDC", "asm.dsp.ddc", kind: 1, localize: false)
                fileEffect("Liveprog", "asm.dsp.liveprog", kind: 2, localize: false)
            }
            Section {
                ASMButton("asm_audio_reset_effects".localized) { SGDSPResetAll(); preset = -1; graphic = SGDSPString("asm.dsp.geq.nodes") ?? ""; revision += 1 }
            }
        }
        .eeveeSettingsStyle()
        .onChange(of: speed) { if transformEnabled { SGSetPlayerSpeed($0) } }
        .onChange(of: pitch) { if transformEnabled { SGSetPlayerPitch(Float($0)) } }
        .onChange(of: transformEnabled) { SGSetPlayerSpeed($0 ? speed : 1); SGSetPlayerPitch($0 ? Float(pitch) : 0) }
        .onChange(of: preset) { if $0 >= 0 { SGDSPSetGains("asm.dsp.eq.gains", SGDSPEqualizerPreset($0)); revision += 1 } }
        .onReceive(timer) { _ in status = SGDSPStatus() ?? ""; speedAvailable = SGPlayerSpeedAllowed(); pitchAvailable = SGPlayerPitchAvailable(); revision += 1 }
    }

    private func valueSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack { ASMText(title); Spacer(); ASMText(String(format: "%.2f %@", value.wrappedValue, unit)).monospacedDigit().foregroundColor(.secondary) }
            Slider(value: value, in: range, step: step)
        }.padding(.vertical, 4)
    }
    private func switchRow(_ title: String, _ key: String) -> some View {
        ASMToggle(title.localized, isOn: Binding(get: { SGDSPSwitch(key) }, set: { SGDSPSetSwitch(key, $0); revision += 1 }))
    }
    private func numberRow(_ title: String, _ key: String, unit: String = "") -> some View {
        let range = ASMDSPRangeFor(key)
        return valueSlider(title.localized, value: Binding(get: { SGDSPNumber(key) }, set: { SGDSPSetNumber(key, $0); revision += 1 }), range: range.min...range.max, step: max(0.01, range.step), unit: unit)
    }
    private func choiceRow(_ title: String, _ key: String, _ choices: [String]) -> some View {
        ASMPicker(title.localized, selection: Binding(get: { Int(SGDSPNumber(key)) }, set: { SGDSPSetNumber(key, Double($0)); revision += 1 })) {
            ForEach(Array(choices.enumerated()), id: \.offset) { ASMText($0.element).tag($0.offset) }
        }
        .pickerStyle(.menu)
    }
    private func bandRow(_ title: String, _ key: String, index: Int, limit: Double) -> some View {
        valueSlider(title, value: Binding(get: { (SGDSPGains(key) ?? [])[safe: index]?.doubleValue ?? 0 }, set: {
            var values = SGDSPGains(key) ?? []
            guard values.indices.contains(index) else { return }
            values[index] = NSNumber(value: $0); SGDSPSetGains(key, values); revision += 1
        }), range: -limit...limit, step: limit < 2 ? 0.05 : 0.5, unit: limit < 2 ? "" : "dB")
    }
    @ViewBuilder private func effectError(_ key: String) -> some View {
        if let error = SGDSPError(key), !error.isEmpty { ASMText(error).font(.footnote).foregroundColor(.orange) }
    }
    @ViewBuilder private func fileEffect(_ title: String, _ key: String, kind: Int, localize: Bool = true) -> some View {
        ASMToggle(localize ? title.localized : title, isOn: Binding(get: { SGDSPSwitch(key) }, set: { SGDSPSetSwitch(key, $0); revision += 1 }))
        SettingsLink(title: "asm_audio_library".localized, icon: "folder.fill", color: .blue) { ASMAudioLibraryView(kind: kind, key: key) }
        effectError(key)
    }
}

private struct ASMAudioLibraryView: View {
    let kind: Int
    let key: String
    @State private var files: [String] = []
    @State private var selection = ""
    @State private var importing = false
    @State private var error: String?
    var body: some View {
        List {
            ASMPicker("asm_audio_file".localized, selection: $selection) {
                ASMText("asm_audio_none".localized).tag("")
                ForEach(files, id: \.self) { ASMText($0).tag($0) }
            }.pickerStyle(.inline)
            ASMButton("asm_audio_import".localized) { importing = true }
            if let error { ASMText(error).font(.footnote).foregroundColor(.orange) }
        }
        .eeveeSettingsStyle()
        .onAppear { files = ASMDSPFiles(kind) ?? []; selection = SGDSPString(key + ".file") ?? "" }
        .onChange(of: selection) { SGDSPSetString(key + ".file", $0) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .audio], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                var importError: NSError?
                if let name = ASMDSPImport(kind, url, &importError) {
                    files = ASMDSPFiles(kind) ?? []; selection = name; error = nil
                } else { error = importError?.localizedDescription ?? "asm_audio_import_failed".localized }
            } catch { self.error = error.localizedDescription }
        }
    }
}
