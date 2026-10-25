import SwiftUI

struct SponsorBlockSettingsView: View {
    @State private var options = UserDefaults.sponsorBlockOptions

    var body: some View {
        List {
            Section(footer: ASMText("categoryOneFooter".localized)) {
                ASMToggle("enableSponsorblock".localized, isOn: $options.enabled)
                ASMToggle("showColoredOverlay".localized, isOn: $options.showOverlay)
                    .disabled(!options.enabled)
                ASMToggle("showToast".localized, isOn: $options.showToast)
                    .disabled(!options.enabled)
                ASMToggle("skipToast".localized, isOn: $options.showSkipFeedbackButtons)
                    .disabled(!options.enabled || !options.showToast)
                ASMToggle("respectManualSeek".localized, isOn: $options.respectManualSeek)
                    .disabled(!options.enabled)
            }

            Section(header: ASMText("categoriesHeader".localized),
                    footer: ASMText("categoriesFooter".localized)) {
                ForEach(SponsorBlockOptions.allCategoryOrder, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            ASMText(prettyName(key))
                                .font(.body)
                            Spacer()
                            ColorPicker("", selection: bindingForColor(key), supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32)
                                .disabled(!options.enabled)
                        }
                        ASMPicker("", selection: bindingForAction(key)) {
                            ForEach(SponsorBlockAction.allCases, id: \.self) { act in
                                ASMText(actionLabel(act)).tag(act)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .disabled(!options.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                NavigationLink(destination: SponsorBlockPendingListView()) {
                    HStack {
                        ASMImage(systemName: "tray.and.arrow.up")
                        ASMText("draftsTitle".localized)
                        Spacer()
                        let count = SponsorBlockPendingStore.all().values.reduce(0) { $0 + $1.count }
                        if count > 0 {
                            ASMText("\(count)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Button {
                    let snap = SponsorBlockSkipper.shared.currentPlayhead()
                    guard let episodeID = snap.episodeID else {
                        PopUpHelper.showPopUp(message: "errorNoPodcats".localized, buttonText: "OK")
                        return
                    }
                    let active = SponsorBlockPendingStore.segments(for: episodeID).first(where: { $0.end == nil })
                    if let active {
                        var copy = active
                        copy.end = max(snap.position, copy.start + 0.1)
                        SponsorBlockPendingStore.upsert(copy)
                        SponsorBlockReportingUI.presentSubmitForm(pending: copy, duration: snap.duration)
                    } else {
                        let p = SponsorBlockPendingSegment(episodeID: episodeID, start: snap.position)
                        SponsorBlockPendingStore.upsert(p)
                        SponsorBlockToast.shared.show("Start set at \(String(format: "%.1f", snap.position))s · open again to set end")
                    }
                } label: {
                    HStack {
                        ASMImage(systemName: "plus.circle")
                        ASMText("markSegment".localized)
                    }
                }
                NavigationLink(destination: SponsorBlockAdvancedView(options: $options)) {
                    HStack {
                        ASMImage(systemName: "gearshape.2")
                        ASMText("advancedTitle".localized)
                    }
                }
                NavigationLink(destination: SponsorBlockHelpView()) {
                    HStack {
                        ASMImage(systemName: "questionmark.circle")
                        ASMText("howToUseTitle".localized)
                    }
                }
            }

            Section(header: ASMText("creditsTitle".localized),
                    footer: ASMText("creditsSubtitle".localized)) {
                ASMLink("linkButtonTitle".localized,
                     destination: URL(string: "https://github.com/Spot-SponsorBlock/Spot-SponsorBlock-Extension")!)
                ASMLink("SponsorBlock", destination: URL(string: "https://sponsor.ajay.app")!)
            }

            Section {
                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .eeveeSettingsStyle()
        .animation(.default, value: options)
        .onChange(of: options) { newValue in
            UserDefaults.sponsorBlockOptions = newValue
            NotificationCenter.default.post(name: SponsorBlockSkipper.segmentsChangedNotification, object: nil)
        }
    }

    private func bindingForAction(_ key: String) -> Binding<SponsorBlockAction> {
        Binding(
            get: { options.categories[key] ?? .disabled },
            set: { options.categories[key] = $0 }
        )
    }

    private func bindingForColor(_ key: String) -> Binding<Color> {
        Binding(
            get: { Color(hex: options.color(for: key)) },
            set: { newColor in options.colors[key] = "#" + newColor.hexString }
        )
    }

    private func actionLabel(_ a: SponsorBlockAction) -> String {
        switch a {
            case .disabled: return "action_disabled".localized
            case .showOnly: return "action_show".localized
            case .manualSkip: return "action_manual".localized
            case .autoSkip: return "action_auto".localized
        }
    }

    private func prettyName(_ key: String) -> String {
        switch key {
            case "sponsor": return "sponsor_category".localized
            case "selfpromo": return "selfpromo_category".localized
            case "interaction": return "interaction_category".localized
            case "intro": return "intro_category".localized
            case "outro": return "outro_category".localized
            case "preview": return "preview_category".localized
            case "hook": return "hook_category".localized
            case "filler": return "filler_category".localized
            case "exclusive_access": return "exclusive_access_category".localized
            default: return key
        }
    }
}
