import SwiftUI

@available(iOS 15.0, *)
struct KaraokeLyricsView: View {
    var onDismiss: () -> Void
    @StateObject private var model: KaraokeLyricsViewModel
    private let options = ASMViewerDisplay.eevee

    init(trackId: String?, lyrics: KaraokeLyricsDto, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _model = StateObject(wrappedValue: KaraokeLyricsViewModel(trackId: trackId, lyrics: lyrics))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                if KaraokeGlass.isEnabled {
                    KaraokeGlassBackground().ignoresSafeArea()
                } else {
                    KaraokeBackgroundView()
                }
                if let lyrics = model.lyrics {
                    content(lyrics: lyrics, layouts: model.layouts, screenWidth: geo.size.width)
                        // A new song starts from its own scroll position and state.
                        .id(model.trackId)
                }
                closeButton
            }
        }
        .preferredColorScheme(.dark)
    }

    private func content(lyrics: KaraokeLyricsDto, layouts: [KaraokeLineLayout], screenWidth: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
            let currentMs = KaraokePlaybackTracker.shared.currentLyricPositionMs()

            KaraokeScrollingLines(
                lyrics: lyrics,
                layouts: layouts,
                options: options,
                currentMs: currentMs,
                activeLineIndex: activeLineIndex(in: lyrics, at: currentMs),
                screenWidth: screenWidth,
                onSelectLine: { model.seek(toLineAt: $0) }
            )
        }
    }

    private func activeLineIndex(in lyrics: KaraokeLyricsDto, at currentMs: Int) -> Int? {
        guard !lyrics.lines.isEmpty else { return nil }
        for (index, line) in lyrics.lines.enumerated().reversed() {
            if currentMs >= line.startMs {
                return index
            }
        }
        return nil
    }

    @ViewBuilder private var closeButtonBackground: some View {
        if KaraokeGlass.isEnabled {
            KaraokeGlassCapsule()
        } else {
            Circle().fill(Color.white.opacity(0.12))
        }
    }

    private var closeButton: some View {
        HStack(spacing: 10) {
            ASMLyricsSoundButton()
            Button(action: onDismiss) {
                ASMImage(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(14)
                    .background(closeButtonBackground)
            }
            .accessibilityLabel("karaoke_close".localized)
        }
        .padding(.top, 50)
        .padding(.trailing, 20)
    }
}

@available(iOS 15.0, *)
private struct KaraokeScrollingLines: View {
    let lyrics: KaraokeLyricsDto
    let layouts: [KaraokeLineLayout]
    let options: KaraokeOptions
    let currentMs: Int
    let activeLineIndex: Int?
    let screenWidth: CGFloat
    let onSelectLine: (Int) -> Void

    private let horizontalPadding: CGFloat = 24

    var body: some View {
        let alignment = options.textAlignment.horizontalAlignment
        let flip: CGFloat = options.reversedDirection ? -1 : 1

        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: alignment, spacing: 28) {
                    Spacer().frame(height: 80)

                    ForEach(Array(layouts.enumerated()), id: \.offset) { index, layout in
                        Button {
                            onSelectLine(index)
                        } label: {
                            VStack(alignment: alignment, spacing: 7) {
                            KaraokeLineView(
                                layout: layout,
                                currentMs: currentMs,
                                isActiveLine: index == activeLineIndex,
                                availableWidth: max(0, screenWidth - horizontalPadding * 2),
                                alignment: alignment
                            )
                                if lyrics.lines.indices.contains(index) {
                                    let line = lyrics.lines[index]
                                    if UserDefaults.karaokeOptions.showPronunciation, let text = line.pronunciation { ASMText(text).font(.subheadline).foregroundColor(.white.opacity(0.65)) }
                                    if UserDefaults.karaokeOptions.showTranslation, let text = line.translation { ASMText(text).font(.subheadline).foregroundColor(.white.opacity(0.65)) }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .scaleEffect(x: 1, y: flip)
                    }

                    KaraokeSongwritersView(lyrics: lyrics)
                        .scaleEffect(x: 1, y: flip)

                    Spacer().frame(height: 200)
                }
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                guard let activeLineIndex = activeLineIndex, activeLineIndex < lyrics.lines.count else { return }
                proxy.scrollTo(activeLineIndex, anchor: .center)
            }
            .onChange(of: activeLineIndex) { newIndex in
                guard let newIndex = newIndex, newIndex < lyrics.lines.count else { return }
                // Single-curve stand-in for SpicyLyrics' overshoot scroll.
                withAnimation(.timingCurve(0.3, 1.4, 0.7, 1.0, duration: 0.8)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            // Flip the list and counter-flip rows; y-only so leading/trailing alignment isn't mirrored.
            .scaleEffect(x: 1, y: flip)
        }
        .environment(\.layoutDirection, lyrics.isRTL ? .rightToLeft : .leftToRight)
    }
}
