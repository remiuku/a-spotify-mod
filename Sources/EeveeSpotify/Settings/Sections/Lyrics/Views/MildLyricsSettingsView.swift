import SwiftUI

struct MildLyricsSettingsView: View {
    let page: MildLyricsSettingsPage
    @State private var options = UserDefaults.mildLyricsOptions
    var body: some View {
        List {
            Section {
                ASMText("Display controls apply to Sweet Lyrics. Source controls apply when the lyrics source is Mild sources + blends. Reopen lyrics after a display change; source changes apply on the next fetch.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            if page == .playful {
                Section {
                    ASMToggle("Use Mild controls in Sweet Lyrics", isOn: Binding(
                        get: { options.flag("enabled") }, set: { options.flags["enabled"] = $0 }))
                }
            }
            ForEach(page.sections, id: \.self) { section in
                Section(header: ASMText(section)) {
                    ForEach(MildLyricsOptions.toggles.filter { $0.section == section }) { spec in
                        ASMToggle(spec.label, isOn: Binding(get: { options.flag(spec.id) }, set: { options.flags[spec.id] = $0 }))
                    }
                    ForEach(MildLyricsOptions.pickers.filter { $0.section == section }) { spec in
                        ASMPicker(spec.label, selection: Binding(get: { options.choice(spec.id) }, set: { options.choices[spec.id] = $0 })) {
                            ForEach(spec.values, id: \.self) { ASMText($0.capitalized).tag($0) }
                        }
                    }
                    ForEach(MildLyricsOptions.sliders.filter { $0.section == section }) { spec in
                        VStack(alignment: .leading) {
                            HStack { ASMText(spec.label); Spacer(); ASMText(String(format: "%.2g", options.number(spec.id))).foregroundColor(.secondary) }
                            Slider(value: Binding(get: { options.number(spec.id) }, set: { options.numbers[spec.id] = $0 }),
                                   in: spec.min...spec.max, step: spec.step)
                        }
                    }
                }
            }
            if page == .sources {
                Section(header: ASMText("Sources and blends"), footer: ASMText("Drag to set priority. Disabled sources are never fetched, including blend donors. A blend retains the base text and borrows matching word timing. Failed sources fall through. Musixmatch uses your existing token.")) {
                ASMPicker("Blend word timing", selection: Binding(get: { options.choice("blend") }, set: { options.choices["blend"] = $0 })) {
                    ASMText("Off").tag("off")
                    ForEach(MildLyricsBlend.definitions) { ASMText($0.label).tag($0.id) }
                }
                ForEach(options.orderedSources, id: \.self) { id in
                    ASMToggle(MildLyricsOptions.sourceName(id) ?? id, isOn: Binding(
                        get: { !options.disabledSources.contains(id) },
                        set: { if $0 { options.disabledSources.remove(id) } else { options.disabledSources.insert(id) } }))
                }.onMove { from, to in var order = options.orderedSources; order.move(fromOffsets: from, toOffset: to); options.sourceOrder = order }
                ASMToggle("Uncensor from base lyrics", isOn: Binding(get: { options.flag("uncensor") }, set: { options.flags["uncensor"] = $0 }))
                TextField("Exclude uploaders (comma separated)", text: $options.excludedUploaders)
                TextField("Prefer uploaders (comma separated)", text: $options.preferredUploaders)
                }
            }
            Section {
                if page == .display { ASMButton("Reset Mild controls") { options = MildLyricsOptions() } }
                ASMLink("Mild Lyrics · gcoolL", destination: URL(string: "https://github.com/gcoolL/mild-lyrics")!)
            }
        }.navigationTitle(page.titleKey.localized)
            .pickerStyle(.menu)
            .environment(\.editMode, .constant(page == .sources ? .active : .inactive))
            .onChange(of: options) { UserDefaults.mildLyricsOptions = $0 }
            .eeveeSettingsStyle()
    }
}
