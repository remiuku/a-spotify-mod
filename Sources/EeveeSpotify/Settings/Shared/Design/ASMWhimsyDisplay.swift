import SwiftUI
import UIKit
import EeveeSpotifyC
import Combine

// Display adapters only: keep raw metadata, URLs, user input, lyric timings and
// caches intact. Returning concrete Text/Image preserves their existing modifiers.
func ASMText<S: StringProtocol>(_ value: S) -> SwiftUI.Text {
    let original = String(value)
    return SwiftUI.Text(ASMWhimsyDisplayText(original) ?? original)
}

func ASMLyricText<S: StringProtocol>(_ value: S) -> SwiftUI.Text {
    let original = String(value)
    return SwiftUI.Text(ASMWhimsyDisplayLyricText(original) ?? original)
}

@available(iOS 15.0, *)
func ASMText(_ value: AttributedString) -> SwiftUI.Text {
    guard ASMWhimsyIsEnabled() else { return SwiftUI.Text(value) }
    var result = AttributedString()
    for run in value.runs {
        let original = String(value[run.range].characters)
        var fragment = AttributedString(ASMWhimsyDisplayText(original) ?? original)
        fragment.mergeAttributes(run.attributes)
        result.append(fragment)
    }
    return SwiftUI.Text(result)
}

func ASMImage(uiImage: UIImage) -> SwiftUI.Image {
    SwiftUI.Image(uiImage: ASMWhimsyDisplayImage(uiImage) ?? uiImage)
}

func ASMImage(systemName: String) -> SwiftUI.Image {
    if ASMWhimsyIsEnabled() {
        if let icon = ASMWhimsySymbols.cache.object(forKey: systemName as NSString) {
            return ASMImage(uiImage: icon)
        }
        if let icon = UIImage(systemName: systemName) {
            ASMWhimsySymbols.cache.setObject(icon, forKey: systemName as NSString)
            return ASMImage(uiImage: icon)
        }
    }
    return SwiftUI.Image(systemName: systemName)
}

private enum ASMWhimsySymbols {
    static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 128
        return cache
    }()
}

func ASMButton(_ title: String, action: @escaping () -> Void) -> Button<SwiftUI.Text> {
    Button(action: action) { ASMText(title) }
}

func ASMToggle(_ title: String, isOn: Binding<Bool>) -> Toggle<SwiftUI.Text> {
    Toggle(isOn: isOn) { ASMText(title) }
}

func ASMPicker<Selection: Hashable, Content: View>(
    _ title: String, selection: Binding<Selection>, @ViewBuilder content: () -> Content
) -> Picker<SwiftUI.Text, Selection, Content> {
    Picker(selection: selection, content: content) { ASMText(title) }
}

@available(iOS 14.0, *)
func ASMLink(_ title: String, destination: URL) -> Link<SwiftUI.Text> {
    Link(destination: destination) { ASMText(title) }
}

func ASMLabel(_ title: String, systemImage: String) -> Label<SwiftUI.Text, SwiftUI.Image> {
    Label { ASMText(title) } icon: { ASMImage(systemName: systemImage) }
}

// These roots are recreated only when the user changes the visual mode, never
// on playback ticks. New screens read the current mode on their first render.
struct ASMWhimsyRefresh: ViewModifier {
    @State private var enabled = ASMWhimsyIsEnabled()
    func body(content: Content) -> some View {
        content.id(enabled)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ASMWhimsyChanged"))) { _ in
                enabled = ASMWhimsyIsEnabled()
            }
    }
}
