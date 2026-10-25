import SwiftUI

struct EeveeDevNoteView: View {
    @State private var noteText: String?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private let devNoteURL = URL(
        string: "https://raw.githubusercontent.com/SideloadLabs/EeveeSpotifyReincarnated/refs/heads/Master/devnote.txt"
    )!
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("developer_note".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button {
                        WindowHelper.shared.dismissCurrentViewController()
                    } label: {
                        ASMText("Done".uiKitLocalized)
                            .font(.headline)
                    }
                }
                .onAppear {
                    loadDevNote()
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView("Loading".uiKitLocalized)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                ASMImage(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                ASMText("Failed to load developer note")
                    .font(.headline)
                ASMText(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                ASMButton("Retry") {
                    isLoading = true
                    errorMessage = nil
                    loadDevNote()
                }
            }
        } else if let text = noteText {
            ScrollView {
                ASMText(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ASMText("No developer note found")
                .foregroundColor(.gray)
        }
    }
    
    private func loadDevNote() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: devNoteURL)
                noteText = String(data: data, encoding: .utf8)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
