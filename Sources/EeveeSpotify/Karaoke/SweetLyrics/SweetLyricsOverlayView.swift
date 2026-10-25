import SwiftUI
import MediaPlayer

// System font adapter: the host's settings do not import Sweet Lyrics' font manager.
enum SweetLyricsFont: String { case standard }
struct SweetLyricsFontChoice: Equatable {
    let stored: String
    init(stored: String) { self.stored = stored }
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: stored == "rounded" ? .rounded : stored == "serif" ? .serif : stored == "monospaced" ? .monospaced : .default)
    }
    func uiFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let design: UIFontDescriptor.SystemDesign = stored == "rounded" ? .rounded : stored == "serif" ? .serif : stored == "monospaced" ? .monospaced : .default
        return base.fontDescriptor.withDesign(design).map { UIFont(descriptor: $0, size: size) } ?? base
    }
}

@available(iOS 16.0, *)
struct SweetLyricsOverlayView: View {
    let onDismiss: () -> Void
    @StateObject private var model: KaraokeLyricsViewModel
    @State private var title = "Sweet Lyrics"
    @State private var artist = ""
    @State private var artwork: UIImage?
    @State private var tint: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let options = UserDefaults.karaokeOptions
    private let mild = UserDefaults.mildLyricsOptions

    init(trackId: String?, lyrics: KaraokeLyricsDto, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _model = StateObject(wrappedValue: KaraokeLyricsViewModel(trackId: trackId, lyrics: lyrics))
    }

    var body: some View {
        GeometryReader { viewport in
            VStack(spacing: 0) {
                header
                if let lyrics = model.lyrics {
                    SweetHostedLyrics(lyrics: lyrics, trackId: model.trackId, options: options, mild: mild, tint: tint)
                        .id(model.trackId)
                } else {
                    Spacer(); ProgressView().tint(.white); Spacer()
                }

            }
            .frame(width: viewport.size.width, height: viewport.size.height)
            .onAppear { logViewport(viewport.size) }
            .onChange(of: viewport.size) { logViewport($0) }
        }
        // Backgrounds receive their own bounded viewport and cannot contribute
        // the cover's aspect-fill size to the foreground's layout proposal.
        .background {
            GeometryReader { viewport in
                ZStack {
                    if !transparentBackground { Color.black }
                    backdrop
                }
                .frame(width: viewport.size.width, height: viewport.size.height)
                .clipped()
            }.ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task(id: model.trackId) {
            refreshHeader()
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            refreshHeader()
        }
    }

    private var transparentBackground: Bool {
        KaraokeBackdropPolicy.presentsTransparently(isSweet: true, mildEnabled: mild.flag("enabled"),
                                                   mildBackground: mild.choice("background"), glassEnabled: KaraokeGlass.isEnabled)
    }

    @ViewBuilder private var backdrop: some View {
        if mild.flag("enabled") {
            mildBackground
        } else if KaraokeGlass.isEnabled {
            KaraokeGlassBackground()
        } else if artwork != nil, SweetKawarpBackground.isSupported {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                SweetKawarpBackground(image: artwork, imageID: model.trackId ?? "", animated: !reduceMotion,
                                      playing: KaraokePlaybackTracker.shared.isPlaying())
            }
        } else {
            KaraokeBackgroundView().id(model.trackId)
        }
    }

    private func logViewport(_ size: CGSize) {
        writeDebugLog("[SweetLayout] viewport=\(size), screen=\(UIScreen.main.bounds.size), background=\(mild.flag("enabled") ? mild.choice("background") : "Sweet"), transparent=\(transparentBackground)")
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let artwork {
                ASMImage(uiImage: artwork).resizable().scaledToFill().frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            VStack(alignment: .leading, spacing: 3) {
                ASMText(title).font(.system(size: 16, weight: .bold)).lineLimit(1)
                if !artist.isEmpty {
                    ASMText(artist).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            ASMLyricsSoundButton()
            Button(action: onDismiss) {
                ASMImage(systemName: "chevron.down").font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
            }.accessibilityLabel(ASMText("karaoke_close".localized))
        }
        .foregroundColor(.white).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 4)
    }

    @ViewBuilder private var mildBackground: some View {
        ZStack {
            switch mild.choice("background") {
            case "mesh":
                if SweetKawarpBackground.isSupported {
                    SweetKawarpBackground(image: artwork, imageID: model.trackId ?? "", animated: !reduceMotion && mild.number("bg_motion") > 0,
                                          playing: KaraokePlaybackTracker.shared.isPlaying(), speed: mild.number("bg_motion"))
                } else { tint.opacity(0.4) }
            case "art":
                if let artwork { ASMImage(uiImage: artwork).resizable().scaledToFill().blur(radius: 40).overlay(.black.opacity(0.25)) }
                else { Color.black }
            case "solid": tint.opacity(0.4)
            default: Color.clear
            }
            Color.black.opacity(mild.number("bg_dim"))
        }
    }

    private func refreshHeader() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        title = info?[MPMediaItemPropertyTitle] as? String ?? "Sweet Lyrics"
        artist = info?[MPMediaItemPropertyArtist] as? String ?? ""
        artwork = AlbumArtLocator.currentAlbumArt()
        if let artwork {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            let pixel = renderer.image { _ in artwork.draw(in: CGRect(x: 0, y: 0, width: 1, height: 1)) }
            if let data = pixel.cgImage?.dataProvider?.data, CFDataGetLength(data) >= 4, let bytes = CFDataGetBytePtr(data) {
                tint = Color(red: 0.55 + Double(bytes[0]) / 255 * 0.45, green: 0.55 + Double(bytes[1]) / 255 * 0.45, blue: 0.55 + Double(bytes[2]) / 255 * 0.45)
            }
        }
    }
}

@available(iOS 16.0, *)
private struct SweetHostedLyrics: View {
    let lyrics: KaraokeLyricsDto
    let trackId: String?
    let options: KaraokeOptions
    let mild: MildLyricsOptions
    let tint: Color
    @State private var animator: SweetLyricsAnimator
    @State private var dragging = false
    @State private var resumeAt: Date = .distantPast
    @State private var followToken = 0
    @State private var playing = KaraokePlaybackTracker.shared.isPlaying()
    @State private var foreground = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var diagnostics = SweetFrameDiagnostics()
    @State private var wordDrift = MildLooseWordScene()
    @StateObject private var translations = ASMSweetTranslationModel()
    @State private var translationOptions: ASMTranslationOptions
    private let translationPlan: ASMTranslationPlan
    private let sourceLinesByText: [String: [KaraokeLineDto]]
    private let sourceTranslations: [String: String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lyrics: KaraokeLyricsDto, trackId: String?, options: KaraokeOptions, mild: MildLyricsOptions, tint: Color) {
        self.lyrics = lyrics; self.trackId = trackId; self.options = options
        self.mild = mild; self.tint = tint
        _translationOptions = State(initialValue: ASMTranslationOptions.forTrack(trackId))
        translationPlan = ASMTranslationPlan(lyrics: lyrics)
        sourceLinesByText = Dictionary(grouping: lyrics.lines) {
            ASMTranslationPlan.text(($0.sweetSyllables ?? $0.syllables).plainText) ?? ""
        }
        sourceTranslations = lyrics.lines.reduce(into: [:]) { values, line in
            if let text = ASMTranslationPlan.text((line.sweetSyllables ?? line.syllables).plainText),
               let translated = ASMTranslationPlan.text(line.translation) { values[text] = translated }
        }
        let original = SweetLyricsAdapter.document(from: lyrics)
        let document = mild.flag("enabled") ? MildRenderPolicy.document(original, options: mild) : original
        let basePrepared = SweetPreparedLyrics(document: document, romanized: false, simple: options.sweetSimpleLyrics,
                                          interludeThreshold: mild.flag("enabled") ? mild.number("interlude_gap") : 3)
        let font = SweetLyricsFontChoice(stored: mild.choice("font_name")).uiFont(size: 24)
        let prepared = MildPlayfulEffects.prepareJelly(basePrepared, configuration: MildPlayfulConfiguration(options: mild, reduceMotion: false)) {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }
        _animator = State(initialValue: SweetLyricsAnimator(lyrics: prepared, simple: options.sweetSimpleLyrics))
    }

    var body: some View {
        GeometryReader { geometry in
            let height = mild.flag("enabled") ? mild.number("focus_height") : 0.4
            let anchor = UnitPoint(x: 0.5, y: options.reversedDirection ? 1 - height : height)
            let flip: CGFloat = options.reversedDirection ? -1 : 1
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    TimelineView(.periodic(from: .now, by: foreground ? frameInterval : 60)) { _ in
                        let now = SweetMediaClock.now()
                        let playback = KaraokePlaybackTracker.shared.lyricSnapshot()
                        let position = Double(playback.positionMs) / 1000 + (mild.flag("enabled") ? mild.number("offset") : 0)
                        let _ = foreground ? diagnostics.record(at: now) : ()
                        let _ = animator.step(position: position,
                                              now: now, blurEnabled: !dragging && options.blurIntensity > 0 && !reduceMotion,
                                              frameInterval: frameInterval, isPlaying: playback.isPlaying)
                        let focus = animator.focusIndex
                        let scrollFocus = mild.flag("enabled") ? (animator.lyrics.lines.last { !$0.isBackground && $0.start <= position + mild.number("scroll_lead") }?.id ?? focus) : focus
                        // Capture value state, as upstream does. Capturing only the unchanged animator
                        // object lets ForEach reuse old rows even while TimelineView is ticking.
                        let visuals = animator.visuals
                        let typography = typography(width: geometry.size.width)
                        LazyVStack(alignment: .leading, spacing: typography.lineSpacing) {
                            if mild.flag("enabled") && mild.flag("credits_top") { KaraokeSongwritersView(lyrics: lyrics).scaleEffect(x: 1, y: flip) }
                            ForEach(animator.lyrics.lines) { line in
                                if !(mild.flag("enabled") && line.isInterlude && mild.flag("hide_gaps")) {
                                styledLine(line, visual: visuals[line.id], typography: typography, focus: focus, position: position)
                                    .contentShape(Rectangle())
                                    .onTapGesture { seek(line) }
                                    .accessibilityAddTraits(line.isInterlude ? [] : .isButton)
                                    .accessibilityHint(line.isInterlude ? "" : "karaoke_seek_hint".localized)
                                    .id(line.id)
                                    .scaleEffect(x: 1, y: flip)
                                }
                            }
                            if !mild.flag("enabled") || !mild.flag("credits_top") { KaraokeSongwritersView(lyrics: lyrics).scaleEffect(x: 1, y: flip) }
                        }
                        .frame(width: max(0, geometry.size.width - 48), alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, geometry.size.height * 0.6)
                        .onChange(of: scrollFocus) { newFocus in
                            guard !dragging, Date() >= resumeAt else { return }
                            if animator.snapped || reduceMotion || (mild.flag("enabled") && mild.choice("renderer") == "snap") { proxy.scrollTo(newFocus, anchor: anchor) }
                            else { withAnimation(.spring(response: 1, dampingFraction: 1)) { proxy.scrollTo(newFocus, anchor: anchor) } }
                        }
                        .onChange(of: followToken) { _ in proxy.scrollTo(animator.focusIndex, anchor: anchor) }
                        .onChange(of: translations.presentation.revision) { _ in
                            // Run after the batch's new text has laid out. Keep the
                            // singing line at its focus anchor unless the user scrolled.
                            DispatchQueue.main.async {
                                guard !dragging, Date() >= resumeAt else { return }
                                if reduceMotion { proxy.scrollTo(animator.focusIndex, anchor: anchor) }
                                else { withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(animator.focusIndex, anchor: anchor) } }
                            }
                        }
                        .onAppear { proxy.scrollTo(focus, anchor: anchor) }
                    }
                }
                .scaleEffect(x: 1, y: flip)
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in
                    dragging = true
                    resumeAt = .distantFuture
                }.onEnded { _ in
                    dragging = false
                    resumeAt = Date().addingTimeInterval(0.75)
                })
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.08),
                                            .init(color: .white, location: 0.98), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottomTrailing) {
                    if resumeAt != .distantPast {
                        Button {
                            dragging = false; resumeAt = .distantPast; followToken += 1
                        } label: {
                            ASMImage(systemName: "arrow.down.to.line").frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }.foregroundColor(.white).padding(16)
                            .accessibilityLabel(ASMText("karaoke_follow_line".localized))
                    }
                }
            }
            .overlayPreferenceValue(MildLooseWordAnchors.self) { anchors in
                if mild.flag("enabled"), mild.number("zero_g") > 0, !reduceMotion {
                    MildLooseWordsLayer(anchors: anchors, scene: wordDrift, speed: mild.number("zero_g"),
                                        interval: foreground ? frameInterval : 60)
                        .allowsHitTesting(false)
                }
            }
        }
        .task(id: translationJob) { await translations.load(translationJob, reduceMotion: reduceMotion) }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)) { _ in
            let next = ASMTranslationOptions.forTrack(trackId)
            if next != translationOptions { translationOptions = next }
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            let updated = KaraokePlaybackTracker.shared.isPlaying()
            if playing != updated { playing = updated }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            foreground = false
            diagnostics.reset()
            wordDrift.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            foreground = true
            animator.snapNext()
            diagnostics.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var translationJob: ASMTranslationJob {
        var selected = translationOptions
        if options.translationDisplay == .original { selected.enabled = false }
        return ASMTranslationJob(track: trackId, plan: translationPlan, options: selected, foreground: foreground)
    }

    private var automaticTranslationEnabled: Bool {
        translationOptions.enabled && options.translationDisplay != .original
    }

    private var frameInterval: Double {
        let cap = mild.flag("enabled") ? mild.number("fps") : 30
        let low = mild.flag("enabled") && mild.flag("battery") && lowPower
        return 1 / (playing ? (low ? min(15, cap) : cap) : min(15, cap))
    }

    private func typography(width: CGFloat) -> SweetLyricsTypography {
        var style = SweetLyricsTypography(fontSize: min(56, max(29.6, width * 0.07)))
        style.cqw = max(1, width - 48) / 100
        style.hasDuets = animator.lyrics.lines.contains(where: \.oppositeAligned)
        style.centered = options.textAlignment == .center
        style.simple = options.sweetSimpleLyrics
        style.blurScale = options.blurIntensity / 1.5
        if mild.flag("enabled") {
            style.fontSize *= mild.number("font_scale")
            style.lineSpacingScale = mild.number("line_spacing")
            style.blurScale *= mild.number("blur_scale")
            style.glowScale = mild.number("glow_scale")
            style.fillSoftness = mild.number("edge")
            style.font = SweetLyricsFontChoice(stored: mild.choice("font_name"))
            style.wordTint = mild.choice("sung_mode") == "album tint" ? tint : .white
            style.glowTint = mild.choice("glow_tint") == "word" ? style.wordTint : .white
        }
        return style
    }

    private func styledLine(_ line: SweetPreparedLine, visual: SweetLineVisual, typography: SweetLyricsTypography,
                            focus: Int, position: Double) -> some View {
        let enabled = mild.flag("enabled")
        let displayLine = enabled ? MildRenderPolicy.line(aligned(line), position: position, options: mild) : aligned(line)
        let displayVisual = enabled ? MildRenderPolicy.visual(visual, line: line, focus: focus, position: position, options: mild, reduceMotion: reduceMotion) : visual
        var type = typography
        let configuration = MildPlayfulConfiguration(options: mild, reduceMotion: reduceMotion)
        if configuration.enabled {
            type.playful = MildPlayfulContext(configuration: configuration, position: position)
            type.lineID = line.id
            type.lineOpacity = type.opacity(displayVisual.opacity)
            if configuration.zeroGravity > 0 { type.blurScale = 0 }
        }
        if enabled && line.oppositeAligned && mild.choice("duet_colour") == "album tint" {
            type.wordTint = tint
            if mild.choice("glow_tint") == "word" { type.glowTint = tint }
        }
        let text = ASMTranslationPlan.text(line.sourceText) ?? line.sourceText
        let showTranslation = options.translationDisplay != .original && (options.showTranslation || translationOptions.enabled)
        let source = (options.showPronunciation || showTranslation) ? sourceLinesByText[text]?
            .min { abs(Double($0.startMs) / 1000 - line.start) < abs(Double($1.startMs) / 1000 - line.start) } : nil
        let roman = options.showPronunciation ? source?.pronunciation : nil
        // Automatic mode validates supplied text against the selected target
        // language in its worker. Legacy source-only mode retains its metadata.
        let supplied = showTranslation && !automaticTranslationEnabled
            ? ASMTranslationPlan.text(source?.translation) ?? sourceTranslations[text] : nil
        let generated = automaticTranslationEnabled ? translations.presentation.values[text] : nil
        let mainTranslation = supplied ?? generated
        let hideOriginal = options.translationDisplay.hideOriginal(translation: mainTranslation == line.plainText ? nil : mainTranslation)
        let translated = [mainTranslation,
                          roman ?? (enabled && mild.choice("roman") == "under" ? MildRenderPolicy.roman(line.plainText) : nil)]
            .compactMap { $0 }.filter { !$0.isEmpty && $0 != line.plainText }.joined(separator: "\n")
        let active = visual.state == .active
        return SweetLyricLineView(line: displayLine, visual: displayVisual, typography: type,
                                  translation: translated.isEmpty ? nil : translated, showOriginal: !hideOriginal)
            .equatable()
            .padding(enabled && mild.choice("renderer") == "cards" ? 12 : 0)
            .background(enabled && mild.choice("renderer") == "cards" ? Color.white.opacity(active ? 0.12 : 0.03) : .clear,
                        in: RoundedRectangle(cornerRadius: 18))
            .offset(y: enabled && !reduceMotion && visual.state == .sung ? mild.number("line_drop") * 5 : 0)
    }

    private func aligned(_ line: SweetPreparedLine) -> SweetPreparedLine {
        var result = line
        if options.textAlignment == .trailing { result.oppositeAligned.toggle() }
        return result
    }

    private func seek(_ line: SweetPreparedLine) {
        // Positions are checked again against the player-observed track by the shared bridge.
        guard let start = SweetLyricsAdapter.seekStartMs(for: line) else { return }
        if KaraokePlaybackTracker.shared.seek(toLineStartMs: start, trackId: trackId) {
            resumeAt = .distantPast
            wordDrift.reset()
            animator.snapNext()
        }
    }
}
