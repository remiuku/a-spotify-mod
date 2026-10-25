import SwiftUI
import UIKit

struct SponsorBlockPendingListView: View {
    @State private var groups: [(episodeID: String, drafts: [SponsorBlockPendingSegment])] = []
    @State private var hiddenUUIDs: [String] = []
    @State private var userID: String = UserDefaults.sponsorBlockUserID
    @State private var showingRegenConfirm = false
    @State private var showingHiddenClearConfirm = false
    @State private var presentingSubmit: SponsorBlockPendingSegment?

    var body: some View {
        List {
            Section(header: ASMText("sponsorblockIDTitle".localized),
                    footer: ASMText("sponsorblockIDFooter".localized)) {
                VStack(alignment: .leading, spacing: 6) {
                    ASMText(userID)
                        .font(.system(.footnote, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    HStack {
                        Button {
                            UIPasteboard.general.string = userID
                            SponsorBlockToast.shared.show(NSLocalizedString("user_id_copied", comment: ""))
                        } label: {
                            ASMLabel("copyButton".localized, systemImage: "doc.on.doc")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        Spacer()
                        Button(action: { showingRegenConfirm = true }) {
                            ASMLabel("regenerateButton".localized, systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            }

            if groups.isEmpty {
                Section(header: ASMText("draftsTitleSB".localized)) {
                    ASMText("draftsEmpty".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(groups, id: \.episodeID) { group in
                    let headerText = String(format: "episode_header".localized, "\(group.episodeID)")
                    Section(header: ASMText(headerText)) {
                        ForEach(group.drafts) { d in
                            draftRow(d)
                        }
                    }
                }
            }

            Section(header: ASMText(String(format: "hidden_locally_header".localized, hiddenUUIDs.count)),
                    footer: ASMText("hiddenFooter".localized)) {
                if hiddenUUIDs.isEmpty {
                    ASMText("hiddenSegmentsEmpty".localized)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(hiddenUUIDs, id: \.self) { uuid in
                        HStack {
                            ASMText(String(uuid.prefix(8)) + "…")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                SponsorBlockHiddenStore.remove(uuid)
                                reload()
                            }) {
                                ASMText("unhideButton".localized).font(.footnote)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    Button(action: { showingHiddenClearConfirm = true }) {
                        ASMLabel("Clear all hidden", systemImage: "trash")
                            .foregroundColor(.red)
                    }
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
        .navigationTitle("sponsorblock_reports_title".localized)
        .onAppear(perform: reload)
        .alert(isPresented: $showingRegenConfirm) {
            Alert(
                title: ASMText("popUpRegenerateTitle".localized),
                message: ASMText("popUpRegenerateSubtitle".localized),
                primaryButton: .destructive(ASMText("regenerateButton".localized)) {
                    let fresh = SponsorBlockReporter.makeUserID()
                    UserDefaults.sponsorBlockUserID = fresh
                    userID = fresh
                },
                secondaryButton: .cancel()
            )
        }
        .actionSheet(isPresented: $showingHiddenClearConfirm) {
            ActionSheet(
                title: ASMText("popUpClearAllTitle".localized),
                message: ASMText("popUpClearAllSubtitle".localized),
                buttons: [
                    .destructive(ASMText("popUpClearAllButton".localized)) {
                        SponsorBlockHiddenStore.clear()
                        reload()
                    },
                    .cancel()
                ]
            )
        }
        .sheet(item: $presentingSubmit, onDismiss: reload) { item in
            SponsorBlockSubmitView(
                pending: item,
                duration: SponsorBlockSkipper.shared.currentPlayhead().duration,
                onSubmitted: reload
            )
        }
    }

    @ViewBuilder
    private func draftRow(_ d: SponsorBlockPendingSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color(hex: UserDefaults.sponsorBlockOptions.color(for: d.category)))
                    .frame(width: 10, height: 10)
                ASMText(SponsorBlockFormatters.categoryName(d.category))
                    .font(.body)
                Spacer()
                ASMText(d.isReadyToSubmit ? "readyButton".localized : "incompleteButton".localized)
                    .font(.caption2)
                    .foregroundColor(d.isReadyToSubmit ? .green : .orange)
            }
            ASMText("\(SponsorBlockFormatters.time(d.start)) → \(d.end.map(SponsorBlockFormatters.time) ?? "—")")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Button(action: { presentingSubmit = d }) {
                    ASMLabel("editSubmit".localized, systemImage: "square.and.pencil")
                        .font(.footnote)
                }
                .buttonStyle(BorderlessButtonStyle())
                Spacer()
                Button(action: {
                    SponsorBlockPendingStore.remove(id: d.id, episodeID: d.episodeID)
                    reload()
                }) {
                    ASMLabel("discardButton".localized, systemImage: "trash")
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 2)
    }

    private func reload() {
        groups = SponsorBlockPendingStore.all()
            .map { (episodeID: $0.key, drafts: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.episodeID < $1.episodeID }
        hiddenUUIDs = SponsorBlockHiddenStore.all().sorted()
    }
}
