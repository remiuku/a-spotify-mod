import SwiftUI

enum ASMDancerMedia {
    static func url(_ animation: ASMDancerAnimation) -> URL? {
        let file = animation.filename as NSString
        return BundleHelper.shared.resourceURL(file.deletingPathExtension, withExtension: file.pathExtension, subdirectory: "DancingBoykisser")
    }
}
/// Mounts a real view even while frames are loading, instead of an empty Group.
struct ASMDancerView: UIViewRepresentable {
    var preview = false
    func makeUIView(context: Context) -> ASMDancerSurface { ASMDancerSurface(preview: preview) }
    func updateUIView(_ view: ASMDancerSurface, context: Context) { view.reloadOptions() }
}
struct ASMCreditsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
