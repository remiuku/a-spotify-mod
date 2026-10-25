import SwiftUI

struct EeveeLyricsSettingsView: View {
    @StateObject var viewModel = EeveeLyricsSettingsViewModel()
    @State private var karaokeOptions: KaraokeOptions = UserDefaults.karaokeOptions
    @State var spicyLyricsApiKey: String = UserDefaults.spicyLyricsApiKey

    var body: some View {
        List {
            lyricsSourceSection()
            Section {
                ForEach(ASMMenuRoute.lyrics.children) { ASMMenuLink(route: $0) }
            }

            if viewModel.lyricsSource != .notReplaced {
                if viewModel.lyricsSource != .genius {
                    geniusFallbackSection()
                }
                
                hideOnErrorSection()
                romanizedLyricsSection()
                
                if viewModel.lyricsSource == .musixmatch {
                    musixmatchLanguageSection()
                }

                if viewModel.lyricsSource.supportsCustomLyricsView {
                    karaokeAppearanceSection()
                    SettingsResetSection(visible: karaokeOptions != KaraokeOptions()) { karaokeOptions = KaraokeOptions() }
                }
            }

            SpacerView()
        }
        .onReceive(viewModel.musixmatchTokenInputAlertPublisher) { showAnonymousTokenOption in
            showMusixmatchTokenAlert(UserDefaults.lyricsSource, showAnonymousTokenOption)
        }
        .eeveeSettingsStyle()
        .pickerStyle(.menu)
        .disabled(viewModel.isRequestingMusixmatchToken)
        .animation(.default, value: viewModel.animationValues)
        .onAppear { karaokeOptions = UserDefaults.karaokeOptions }
        .onChange(of: karaokeOptions) { UserDefaults.karaokeOptions = $0 }
        .onChange(of: spicyLyricsApiKey) { UserDefaults.spicyLyricsApiKey = $0 }
    }

    @ViewBuilder private func karaokeAppearanceSection() -> some View {
        Section {
            ASMToggle(
                "karaoke_enabled".localized,
                isOn: $karaokeOptions.enabled
            )

            if karaokeOptions.enabled {
                ASMPicker("karaoke_renderer".localized, selection: $karaokeOptions.renderer) {
                    ForEach(KaraokeRenderer.allCases, id: \.self) { renderer in
                        ASMText(renderer.displayName).tag(renderer)
                    }
                }
                if karaokeOptions.renderer == .sweetLyrics {
                    ASMToggle("sweet_simple_lyrics".localized, isOn: $karaokeOptions.sweetSimpleLyrics)
                }

                SettingsLink(title: "Viewer settings", icon: "slider.horizontal.3", color: .purple) { ASMViewerSettingsView() }

            }
        } header: {
            ASMText("karaoke_section".localized)
        } footer: {
            ASMText("karaoke_section_footer".localized + "\n\n" + "karaoke_renderer_description".localized)
        }
    }
    
    @ViewBuilder private func geniusFallbackSection() -> some View {
        Section {
            ASMToggle(
                "genius_fallback".localized,
                isOn: $viewModel.lyricsOptions.geniusFallback
            )
            
            if viewModel.lyricsOptions.geniusFallback {
                ASMToggle(
                    "show_fallback_reasons".localized,
                    isOn: $viewModel.lyricsOptions.showFallbackReasons
                )
            }
        } footer: {
            ASMText("genius_fallback_description"
                .localizeWithFormat(viewModel.lyricsSource.description))
        }
    }
    
    @ViewBuilder private func romanizedLyricsSection() -> some View {
        Section {
            ASMToggle(
                "romanized_lyrics".localized,
                isOn: $viewModel.lyricsOptions.romanization
            )
        } footer: {
            ASMText("romanized_lyrics_description".localized)
        }
    }
    
    @ViewBuilder private func hideOnErrorSection() -> some View {
        Section {
            ASMToggle(
                "hide_lyrics_on_error".localized,
                isOn: $viewModel.lyricsOptions.hideOnError
            )
        } footer: {
            ASMText("hide_lyrics_on_error_description".localized)
        }
    }
    
    @ViewBuilder private func musixmatchLanguageSection() -> some View {
        Section {
            HStack {
                ASMText("musixmatch_language".localized)
                
                Spacer()
                
                TextField("en", text: $viewModel.lyricsOptions.musixmatchLanguage)
                    .frame(maxWidth: 20)
                    .foregroundColor(.gray)
            }
            .icon(
                "exclamationmark.triangle.fill",
                color: .yellow,
                when: $viewModel.showMusixmatchInvalidLanguageWarning
            )
        } footer: {
            ASMText("musixmatch_language_description".localized)
        }
    }
}
