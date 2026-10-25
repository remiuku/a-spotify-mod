import SwiftUI

struct ChevronRightView: View {
    var body: some View {
        ASMImage(systemName: "chevron.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Color(UIColor.tertiaryLabel))
    }
}
