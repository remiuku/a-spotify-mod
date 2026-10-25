/// One owned modal at a time, including its dismissal animation. Callbacks
/// from a removed renderer must not dismiss or unlock its replacement.
struct ASMLyricsPresentationState {
    private(set) var token: UInt64?
    private(set) var dismissing = false
    private var revision: UInt64 = 0
    var isPresented: Bool { token != nil }
    mutating func begin() -> UInt64? {
        guard token == nil else { return nil }
        revision &+= 1; token = revision; dismissing = false
        return revision
    }
    mutating func beginDismiss(_ value: UInt64) -> Bool {
        guard token == value, !dismissing else { return false }
        dismissing = true; return true
    }
    @discardableResult mutating func finish(_ value: UInt64) -> Bool {
        guard token == value else { return false }
        token = nil; dismissing = false; return true
    }
}
