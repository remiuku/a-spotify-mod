import SwiftUI
import EeveeSpotifyC

struct ASMImportedLyricsView: View {
    let mode: String
    let lyrics: KaraokeLyricsDto
    let onDismiss: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ASMText(mode == "spotipw" ? "spoti.pw" : "Vitrine").font(.headline)
                Spacer()
                ASMLyricsSoundButton()
                Button(action: onDismiss) { ASMImage(systemName: "xmark").padding(12) }
                    .accessibilityLabel("karaoke_close".localized)
            }.padding(.horizontal, 16)
            ASMImportedLyricsSurface(mode: mode)
        }.background(Color.black.ignoresSafeArea()).foregroundColor(.white)
    }
}

private struct ASMImportedLyricsSurface: UIViewRepresentable {
    let mode: String
    func makeUIView(context: Context) -> UIView {
        if let view = ASMInterfaceLyricsView(mode) { return view }
        let label = UILabel()
        label.text = "This lyrics module could not load. Reimport the complete app update in LiveContainer."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        return label
    }
    func updateUIView(_ view: UIView, context: Context) { }
    static func dismantleUIView(_ view: UIView, coordinator: ()) {
        // Force the port's didMoveToWindow cleanup before SwiftUI caches or
        // releases the removed representable.
        view.removeFromSuperview()
        view.layer.removeAllAnimations()
    }
}
