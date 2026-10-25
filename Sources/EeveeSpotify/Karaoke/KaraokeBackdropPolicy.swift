import Foundation

enum KaraokeBackdropPolicy {
    // Mild's explicit background choice owns presentation while its Sweet controls
    // are active. Other renderers retain the existing global glass setting.
    static func presentsTransparently(isSweet: Bool, mildEnabled: Bool,
                                      mildBackground: String, glassEnabled: Bool) -> Bool {
        if isSweet && mildEnabled { return mildBackground == "clear" }
        return glassEnabled
    }
}
