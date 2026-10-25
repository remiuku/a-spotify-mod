import SwiftUI

@available(iOS 15.0, *)
struct ASMDancerSettingsView: View {
    @State private var options = ASMDancerOptions.load()
    private var beats: Binding<Double> {
        Binding(get: { options.beats }, set: { options.beatCounts[options.animation.rawValue] = $0 })
    }
    var body: some View {
        List {
            Section {
                ASMToggle("Dancing boykisser", isOn: $options.enabled)
                HStack { Spacer(); ASMDancerView(preview: true).frame(width: 96, height: 96); Spacer() }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    ASMText(UserDefaults.standard.string(forKey: "asm.lyrics.dancer.mediaStatus") ?? "Loading animation preview…")
                        .font(.footnote).foregroundColor(.secondary)
                }
                ASMPicker("Animation", selection: Binding(get: { options.animation }, set: { options.animation = $0 })) {
                    ForEach(ASMDancerAnimation.allCases) { animation in
                        ASMText(animation.title + (ASMDancerMedia.url(animation) == nil ? " (file needed)" : ""))
                            .tag(animation).disabled(ASMDancerMedia.url(animation) == nil)
                    }
                }
                if let seconds = options.animation.playbackSeconds {
                    ASMText(String(format: "Playback loop: %.2f s · calibrated cadence: %.1f BPM", seconds, 60 * options.beats / seconds))
                        .font(.footnote).foregroundColor(.secondary)
                }
            } footer: {
                ASMText("Above the credits in custom lyric viewers. Freezes when paused; Reduce Motion shows a still frame.")
                if ASMDancerMedia.url(.bounce) == nil {
                    ASMText("The fourth link expired. Supply bounce.gif to enable that choice.")
                }
            }
            Section {
                ASMToggle("Sync to song tempo", isOn: $options.sync)
                ASMToggle("Estimate BPM from local playback", isOn: $options.estimateBPM)
                ASMPicker("Dance tempo", selection: $options.tempoScale) {
                    ForEach(ASMDancerTempoScale.allCases, id: \.self) { ASMText($0.title).tag($0) }
                }.disabled(!options.sync)
                ASMToggle("Always use manual BPM", isOn: $options.forceManual)
                valueSlider("Manual / fallback BPM", value: $options.manualBPM, range: 30...300, step: 1)
                valueSlider("Beats per animation loop", value: beats, range: 1...32, step: 1)
                valueSlider("Beat alignment offset", value: $options.offsetBeats, range: -1...1, step: 0.05)
            } footer: {
                ASMText("Uses the Spotify audio-features lookup from Spicetify DJ Info, then local beat estimation if enabled. Estimates need about 8–16 seconds and can be half/double-time. Spotify can deny or lack data for a track; the exact lookup status is shown below. No microphone or audio upload. Manual BPM is used while waiting.")
            }
            Section(header: ASMText("Current song")) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let snapshot = KaraokePlaybackTracker.shared.dancerSnapshot()
                    ASMText(ASMDancerTempoService.shared.status(snapshot: snapshot, options: options))
                }.font(.footnote).foregroundColor(.secondary)
            }
            SpacerView()
        }.eeveeSettingsStyle().pickerStyle(.menu)
            .onChange(of: options) { _ in options.save() }
    }
    private func valueSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading) {
            HStack { ASMText(title); Spacer(); ASMText(String(format: step < 1 ? "%.2f" : "%.0f", value.wrappedValue)).foregroundColor(.secondary) }
            Slider(value: value, in: range, step: step).accessibilityLabel(title)
        }
    }
}
