import SwiftUI

struct SponsorBlockAdvancedView: View {
    @Binding var options: SponsorBlockOptions
    @State private var showingResetSheet = false

    var body: some View {
        List {
            Section(header: ASMText("skipBehaviourTitle".localized)) {
                ASMToggle("autoSkipSubmissionsTitle".localized, isOn: $options.autoSkipMySubmissions)
                ASMToggle("logOnlyToggle".localized, isOn: $options.logOnly)
            }

            Section(header: ASMText("serverHeader".localized)) {
                HStack {
                    ASMText("urlText".localized)
                    Spacer()
                    TextField("https://sponsor.ajay.app", text: $options.serverURL)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }
            }

            Section(header: ASMText("tuningTitle".localized)) {
                Stepper(
                    String(format: "minSegmentDuration".localized, options.minSegmentDuration),
                    value: $options.minSegmentDuration,
                    in: 0.0...30.0,
                    step: 0.5
                )
                Stepper(
                    String(format: "toastDuration".localized, options.toastDuration),
                    value: $options.toastDuration,
                    in: 1.0...8.0,
                    step: 0.2
                )
            }

            Section(footer: ASMText("trackLogSubtitle".localized)) {
                ASMToggle("trackLogToggle".localized, isOn: $options.verboseLogging)
            }

            Section {
                Button {
                    showingResetSheet = true
                } label: {
                    HStack {
                        ASMImage(systemName: "arrow.counterclockwise")
                        ASMText("resetButtonTrackLog".localized)
                    }
                    .foregroundColor(.red)
                }
            }

            Section {
                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .eeveeSettingsStyle()
        .navigationTitle("advancedTitle".localized)
        .actionSheet(isPresented: $showingResetSheet) { resetSheet() }
    }

    private func resetSheet() -> ActionSheet {
        let draftCount  = SponsorBlockPendingStore.all().values.reduce(0) { $0 + $1.count }
        let hiddenCount = SponsorBlockHiddenStore.all().count
        let votedCount  = SponsorBlockVotedStore.count
        let mineCount   = SponsorBlockMySubmissionsStore.totalCount

        return ActionSheet(
            title: ASMText("resetTitle".localized),
            message: ASMText("resetSubtitle".localized),
            buttons: [
                .destructive(ASMText("settingsResetSB".localized)) {
                    options = SponsorBlockOptions(
                        enabled: options.enabled,
                        logOnly: false,
                        showOverlay: true,
                        showToast: false,
                        respectManualSeek: false,
                        serverURL: "https://sponsor.ajay.app",
                        minSegmentDuration: 1.0,
                        categories: SponsorBlockOptions.defaultCategories,
                        colors: SponsorBlockOptions.defaultColors
                    )
                },
                .destructive(ASMText(String(format: "draftsCountSB".localized, draftCount))) {
                    for (id, _) in SponsorBlockPendingStore.all() {
                        SponsorBlockPendingStore.clear(episodeID: id)
                    }
                },
                .destructive(ASMText(String(format: "hiddenSegmentsSB".localized, hiddenCount))) {
                    SponsorBlockHiddenStore.clear()
                },
                .destructive(ASMText(String(format: "votedRecordsSB".localized, votedCount))) {
                    SponsorBlockVotedStore.clear()
                },
                .destructive(ASMText(String(format: "localSubmissionsSB".localized, mineCount))) {
                    SponsorBlockMySubmissionsStore.clear()
                },
                .destructive(ASMText("regenerateIDSB".localized)) {
                    UserDefaults.sponsorBlockUserID = SponsorBlockReporter.makeUserID()
                },
                .destructive(ASMText("allResetSB".localized)) {
                    options = SponsorBlockOptions(
                        enabled: false,
                        logOnly: false,
                        showOverlay: true,
                        showToast: false,
                        respectManualSeek: false,
                        serverURL: "https://sponsor.ajay.app",
                        minSegmentDuration: 1.0,
                        categories: SponsorBlockOptions.defaultCategories,
                        colors: SponsorBlockOptions.defaultColors
                    )
                    for (id, _) in SponsorBlockPendingStore.all() {
                        SponsorBlockPendingStore.clear(episodeID: id)
                    }
                    SponsorBlockHiddenStore.clear()
                    SponsorBlockVotedStore.clear()
                    SponsorBlockMySubmissionsStore.clear()
                    UserDefaults.sponsorBlockUserID = SponsorBlockReporter.makeUserID()
                },
                .cancel()
            ]
        )
    }
}
