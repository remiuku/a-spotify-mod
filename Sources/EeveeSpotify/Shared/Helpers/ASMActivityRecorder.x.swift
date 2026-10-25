import Foundation
import UIKit
import Orion

struct ASMActivityRecordingGroup: HookGroup {}

enum ASMActivityRecorder {
    static let preference = "asm.diagnostics.activityRecording"
    static let store = ASMActivityLogStore(directory: URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/ASMActivity", isDirectory: true))
    private static let monitor = DispatchQueue(label: "asm.activity.heartbeat", qos: .utility)
    private static var timer: DispatchSourceTimer?
    private static var heartbeat = ASMActivityHeartbeat()
    private static var foreground = true
    private static var pulseID: UInt64 = 0
    private static var observers: [NSObjectProtocol] = []
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        ASMActivityRecordingGroup().activate()
        store.setEnabled(UserDefaults.standard.bool(forKey: preference))
        recordLaunch()
        for (name, active) in [(UIApplication.didBecomeActiveNotification, true),
                               (UIApplication.didEnterBackgroundNotification, false),
                               (UIApplication.willTerminateNotification, false)] {
            // Inline observer does not call main or inspect notification objects.
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                store.record("app.lifecycle", ["name": name.rawValue])
                monitor.async { foreground = active; heartbeat.reset(); pulseID &+= 1 }
            })
        }
        let source = DispatchSource.makeTimerSource(queue: monitor)
        source.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        source.setEventHandler {
            guard store.isEnabled, foreground else { heartbeat.reset(); pulseID &+= 1; return }
            switch heartbeat.tick(at: ProcessInfo.processInfo.systemUptime) {
            case .request:
                pulseID &+= 1
                let requestID = pulseID
                DispatchQueue.main.async {
                    monitor.async {
                        guard requestID == pulseID else { return }
                        if let seconds = heartbeat.complete(at: ProcessInfo.processInfo.systemUptime), foreground {
                            store.record("ui.recovered", ["seconds": String(format: "%.1f", seconds)])
                        }
                    }
                }
            case .stalled:
                store.record("ui.stalled", ["threshold_seconds": "3"])
            case .none: break
            }
        }
        timer = source; source.resume()
    }

    static func setEnabled(_ enabled: Bool) {
        store.setEnabled(enabled)
        UserDefaults.standard.set(enabled, forKey: preference)
        if enabled { recordLaunch() }
    }

    private static func recordLaunch() {
        guard store.isEnabled else { return }
        store.record("session.context", ["build": ASMBrand.build,
                     "spotify": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                     "ios": ProcessInfo.processInfo.operatingSystemVersionString,
                     "interface": ASMInterfaceMode.active.rawValue])
    }

    static func describe(_ view: UIView?) -> [String: String] {
        guard Thread.isMainThread, let view else { return [:] }
        var fields = ["view": NSStringFromClass(type(of: view))]
        var ancestor: UIView? = view
        var identifier: String?
        for _ in 0..<6 {
            guard let current = ancestor else { break }
            if current is UITextField || current is UITextView || NSStringFromClass(type(of: current)).lowercased().contains("keyboard") {
                return ["view": "text_input"]
            }
            if identifier == nil, let id = current.accessibilityIdentifier, !id.isEmpty { identifier = id }
            ancestor = current.superview
        }
        fields["id"] = identifier
        return fields
    }
}

class ASMActivityTouchesHook: ClassHook<UIApplication> {
    typealias Group = ASMActivityRecordingGroup
    func sendEvent(_ event: UIEvent) {
        if ASMActivityRecorder.store.isEnabled, event.type == .touches {
            for touch in event.allTouches ?? [] where touch.phase == .began || touch.phase == .ended || touch.phase == .cancelled {
                var fields = ASMActivityRecorder.describe(touch.view)
                fields["phase"] = touch.phase == .began ? "began" : touch.phase == .ended ? "ended" : "cancelled"
                ASMActivityRecorder.store.record("touch", fields)
            }
        }
        orig.sendEvent(event)
    }
}

class ASMActivityControlHook: ClassHook<UIControl> {
    typealias Group = ASMActivityRecordingGroup
    func sendAction(_ action: Selector, to recipient: Any?, forEvent event: UIEvent?) {
        if ASMActivityRecorder.store.isEnabled {
            var fields = ASMActivityRecorder.describe(target)
            fields["action"] = NSStringFromSelector(action)
            ASMActivityRecorder.store.record("control.action", fields)
        }
        orig.sendAction(action, to: recipient, forEvent: event)
    }
    func sendAction(_ action: UIAction) {
        if ASMActivityRecorder.store.isEnabled {
            var fields = ASMActivityRecorder.describe(target)
            fields["action"] = action.identifier.rawValue
            ASMActivityRecorder.store.record("control.uiaction", fields)
        }
        orig.sendAction(action)
    }
}

class ASMActivityScreenHook: ClassHook<UIViewController> {
    typealias Group = ASMActivityRecordingGroup
    func viewDidAppear(_ animated: Bool) {
        if ASMActivityRecorder.store.isEnabled {
            ASMActivityRecorder.store.record("screen.appeared", ["controller": NSStringFromClass(type(of: target))])
        }
        orig.viewDidAppear(animated)
    }
}
