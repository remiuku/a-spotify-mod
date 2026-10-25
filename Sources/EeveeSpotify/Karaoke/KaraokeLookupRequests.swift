import Foundation

/// A request belongs to a particular visit, including retries of the same song.
/// A slow previous song must never replace the song currently on screen.
struct KaraokeLookupSelection<Key: Equatable> {
    private(set) var key: Key?
    private(set) var revision = 0

    mutating func begin(_ key: Key?) -> Int {
        self.key = key
        revision += 1
        return revision
    }

    func accepts(_ key: Key, revision: Int) -> Bool {
        self.key == key && self.revision == revision
    }
}

/// Coalesces simultaneous opens/reopens. Failed attempts are not cached, so an
/// explicit retry can search again. Work never blocks the UI thread.
final class KaraokeLookupRequests<Key: Hashable, Value> {
    typealias Completion = (Result<Value, Error>) -> Void
    private let lock = NSLock()
    private var flights: [Key: [Completion]] = [:]
    private let deliver: (@escaping () -> Void) -> Void

    init(deliver: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.deliver = deliver
    }

    func request(_ key: Key, operation: @escaping () throws -> Value, completion: @escaping Completion) {
        lock.lock()
        if flights[key] != nil {
            flights[key]!.append(completion)
            lock.unlock()
            return
        }
        flights[key] = [completion]
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result(catching: operation)
            self.lock.lock()
            let callbacks = self.flights.removeValue(forKey: key) ?? []
            self.lock.unlock()
            self.deliver { callbacks.forEach { $0(result) } }
        }
    }
}
