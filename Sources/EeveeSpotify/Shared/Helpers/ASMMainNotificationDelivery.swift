import Foundation

/// OperationQueue.main notification observers can make the posting thread wait
/// for main. Spotify posts preference changes from a player queue that main can
/// itself be waiting for. Observe inline, then enqueue UI work without waiting.
enum ASMMainNotificationDelivery {
    static func observe(forName name: Notification.Name, object: Any? = nil,
                        center: NotificationCenter = .default,
                        using action: @escaping (Notification) -> Void) -> NSObjectProtocol {
        let pending = Pending(action)
        return center.addObserver(forName: name, object: object, queue: nil) { pending.enqueue($0) }
    }

    private final class Pending {
        private let lock = NSLock()
        private var latest: Notification?
        private var scheduled = false
        private let action: (Notification) -> Void
        init(_ action: @escaping (Notification) -> Void) { self.action = action }

        func enqueue(_ notification: Notification) {
            lock.lock()
            latest = notification
            let schedule = !scheduled
            scheduled = true
            lock.unlock()
            guard schedule else { return }
            // Always async, even if posted on main: don't enter UIKit layout
            // inside a native preferences write. Bursts reload current state once.
            DispatchQueue.main.async { self.deliver() }
        }
        private func deliver() {
            lock.lock()
            let notification = latest
            latest = nil; scheduled = false
            lock.unlock()
            if let notification { action(notification) }
        }
    }
}
