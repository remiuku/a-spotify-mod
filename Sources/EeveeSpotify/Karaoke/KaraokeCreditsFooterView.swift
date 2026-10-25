import SwiftUI

/// Spicy Mobile's pinned NoWriters block. Never part of the scrolling timeline.
struct KaraokeCreditsFooterView: View {
    let lyrics: KaraokeLyricsDto
    var viewportWidth: CGFloat? = nil
    var compact: Bool = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var width = UIScreen.main.bounds.width
    private var rows: [KaraokeCreditPolicy.Row] { KaraokeCreditPolicy.rows(lyrics) }
    private var isCompact: Bool { compact || verticalSizeClass == .compact }
    var body: some View {
        let metrics = KaraokeCreditPolicy.Metrics(width: Double(viewportWidth ?? width), compact: isCompact)
        if !rows.isEmpty {
            Group {
                if isCompact {
                    // Keep source and people in two tight rows. The lyric word
                    // flow layout uses one gap for both axes, wasting vertical
                    // space when the footer wraps in a short landscape viewport.
                    VStack(alignment: .trailing, spacing: CGFloat(metrics.rowSpacing)) {
                        compactRow(rows.filter { $0.kind != .contributor }, metrics: metrics)
                        compactRow(rows.filter { $0.kind == .contributor }, metrics: metrics)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            credit(row, metrics: metrics)
                                .padding(.top, index == 0 ? 0 : CGFloat(metrics.margin(before: row.kind)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, CGFloat(metrics.horizontalInset))
            .padding(.top, 4).padding(.bottom, 4)
            .multilineTextAlignment(.trailing)
            .environment(\.layoutDirection, .leftToRight)
            .background(GeometryReader { geometry in
                Color.clear.onAppear { width = geometry.size.width }
                    .onChange(of: geometry.size.width) { width = $0 }
            })
        }
    }
    @ViewBuilder private func compactRow(_ rows: [KaraokeCreditPolicy.Row], metrics: KaraokeCreditPolicy.Metrics) -> some View {
        if !rows.isEmpty {
            HStack(alignment: .center, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    credit(row, metrics: metrics)
                }
            }
        }
    }
    @ViewBuilder private func credit(_ row: KaraokeCreditPolicy.Row, metrics: KaraokeCreditPolicy.Metrics) -> some View {
        if let person = row.contributor, let label = row.label {
            if let url = person.profile {
                Link(destination: url) { personRow(person, label: label, metrics: metrics) }.buttonStyle(.plain)
            } else { personRow(person, label: label, metrics: metrics) }
        } else {
            ASMText(row.text)
                .font(.system(size: CGFloat(row.kind == .community ? metrics.communitySize : metrics.providerSize), weight: row.kind == .community ? .bold : .semibold))
                .foregroundColor(.white.opacity(row.kind == .community ? 0.65 : 0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private func personRow(_ person: KaraokeCreditPolicy.Contributor, label: String, metrics: KaraokeCreditPolicy.Metrics) -> some View {
        HStack(spacing: 2) {
            (ASMText(label + " ").foregroundColor(.white.opacity(0.6))
             + ASMText("@" + person.name).bold().underline().foregroundColor(.white.opacity(0.75)))
                .font(.system(size: CGFloat(metrics.providerSize), weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let url = person.avatar {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Circle().fill(Color.white.opacity(0.12)) }
                }.frame(width: CGFloat(metrics.avatarSize), height: CGFloat(metrics.avatarSize))
                    .clipShape(Circle()).accessibilityHidden(true)
            }
        }
    }
}

/// Writer attribution remains at the original configurable place in the scroll.
struct KaraokeSongwritersView: View {
    let lyrics: KaraokeLyricsDto
    var body: some View {
        if !lyrics.songWriters.isEmpty {
            ASMText("Written by: " + lyrics.songWriters.joined(separator: ", "))
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing).multilineTextAlignment(.trailing)
                .padding(.horizontal, 24).padding(.top, 12)
        }
    }
}
