import Foundation

/// A URLSession delegate can be called on main. Never wait there for a lyric
/// provider: metadata lookup may itself need main, and the network may be slow.
enum ASMLyricsResponseDelivery {
    private static let worker = DispatchQueue(label: "asm.lyrics.response.worker", qos: .userInitiated)

    static func resolve(original: Data, timeout: TimeInterval = 18,
                        load: @escaping () -> Data?, deliver: @escaping (Data) -> Void) {
        let reply = Reply(original: original, completion: deliver)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { reply.finish(nil) }
        worker.async {
            // Native requests for queued tracks can expire before reaching the
            // serial provider worker. Do not start those unnecessary lookups.
            guard reply.isPending else { return }
            let result = load()
            DispatchQueue.main.async { reply.finish(result) }
        }
    }

    private final class Reply {
        private let lock = NSLock()
        private var original: Data
        private var completion: ((Data) -> Void)?
        init(original: Data, completion: @escaping (Data) -> Void) {
            self.original = original; self.completion = completion
        }
        var isPending: Bool {
            lock.lock(); defer { lock.unlock() }; return completion != nil
        }
        func finish(_ custom: Data?) {
            dispatchPrecondition(condition: .onQueue(.main))
            lock.lock()
            guard let callback = completion else { lock.unlock(); return }
            let data = custom ?? original
            // Late results and timeouts cannot replay data/completion or keep
            // the delegate/controller and original response alive afterwards.
            completion = nil; original = Data()
            lock.unlock()
            callback(data)
        }
    }
}
