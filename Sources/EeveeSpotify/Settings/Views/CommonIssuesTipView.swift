import SwiftUI

struct CommonIssuesTipView: View {
    var onDismiss: () -> Void
    
    var body: some View {
        Section {
            HStack(spacing: 15) {
                ASMImage(systemName: "exclamationmark.bubble")
                    .font(.title)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 3) {
                    VStack(alignment: .leading) {
                        ASMText("common_issues_tip_title".localized)
                            .font(.headline)
                    }
                    
                    Link(
                        destination: URL(
                            string: "https://github.com/jaydenjcpy/EeveeSpotifyReincarnated/blob/Master/common_issues.md"
                        )!,
                        label: {
                            VStack {
                                ASMText("\("common_issues_tip_message".localized) ")
                                    .foregroundColor(.white)
                                
                                + ASMText("common_issues_tip_button".localized)
                                    .foregroundColor(EeveeTheme.accent)
                                
                                + ASMText(".")
                                    .foregroundColor(.white)
                            }
                            .font(.subheadline)
                        }
                    )
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    ASMImage(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemGray2))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 5)
        }
    }
}
