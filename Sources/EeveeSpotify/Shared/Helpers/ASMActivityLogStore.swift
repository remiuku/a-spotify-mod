import Foundation

/// Small, bounded breadcrumbs, not a dump of requests, text fields or view trees.
enum ASMActivityLogPolicy {
    static func bounded(_ value: String, bytes: Int) -> String {
        String(decoding: value.utf8.prefix(bytes), as: UTF8.self)
    }
    static func clean(_ value: String) -> String {
        var text = bounded(value, bytes: 800).replacingOccurrences(of: "\n", with: " ")
        // Strip URL queries/fragments and HTTP credentials before sharing errors.
        let urlPattern = #"https?://[^\s<>\"]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: text) else { continue }
                guard var url = URLComponents(string: String(text[range])) else {
                    text.replaceSubrange(range, with: "[url]"); continue
                }
                url.query = nil; url.fragment = nil; url.user = nil; url.password = nil
                text.replaceSubrange(range, with: url.string ?? "[url]")
            }
        }
        for pattern in [#"(?i)bearer\s+[^\s,;\"']+"#,
                        #"(?i)(?:access[_-]?token|refresh[_-]?token|password|authorization|cookie)[\"']?\s*[:=]\s*(?:\"[^\"]*\"|'[^']*'|[^\s,;]+)"#] {
            text = text.replacingOccurrences(of: pattern, with: "[redacted]", options: .regularExpression)
        }
        return text
    }
}

/// All file work belongs to `worker`. The posting thread only takes a short lock
/// to enqueue bounded values. In particular, it never waits for the main queue.
final class ASMActivityLogStore {
    private struct Entry {
        let time: TimeInterval
        let uptime: TimeInterval
        let event: String
        let fields: [String: String]
    }
    let directory: URL
    private let limit: Int
    private let pendingLimit: Int
    private let worker = DispatchQueue(label: "asm.activity.log", qos: .utility)
    private let lock = NSLock()
    private var recording = false
    private var pending: [Entry] = []
    private var scheduled = false
    private var dropped = 0
    private var handle: FileHandle?
    private var bytes = 0
    private let session = UUID().uuidString
    private var current: URL { directory.appendingPathComponent("activity-current.jsonl") }
    private var previous: URL { directory.appendingPathComponent("activity-previous.jsonl") }
    private var exported: URL { directory.appendingPathComponent("activity-export.jsonl") }

    init(directory: URL, limit: Int = 1 << 20, pendingLimit: Int = 256) {
        self.directory = directory
        self.limit = max(64 << 10, limit)
        self.pendingLimit = max(8, pendingLimit)
    }

    var isEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return recording
    }

    func setEnabled(_ enabled: Bool) {
        lock.lock()
        guard recording != enabled else { lock.unlock(); return }
        recording = enabled
        enqueueLocked(Entry(time: Date().timeIntervalSince1970, uptime: ProcessInfo.processInfo.systemUptime,
                            event: enabled ? "recording.enabled" : "recording.disabled", fields: [:]))
        lock.unlock()
    }

    func record(_ event: String, _ fields: [String: String] = [:]) {
        guard isEnabled else { return }
        // Bound memory before enqueuing; redaction/JSON encoding happen on worker.
        var bounded: [String: String] = [:]
        for (key, value) in fields.prefix(12) {
            bounded[ASMActivityLogPolicy.bounded(key, bytes: 96)] = ASMActivityLogPolicy.bounded(value, bytes: 800)
        }
        let entry = Entry(time: Date().timeIntervalSince1970, uptime: ProcessInfo.processInfo.systemUptime,
                          event: String(event.prefix(80)), fields: bounded)
        lock.lock()
        if recording { enqueueLocked(entry) }
        lock.unlock()
    }

    private func enqueueLocked(_ entry: Entry) {
        if pending.count == pendingLimit { pending.removeFirst(); dropped += 1 }
        pending.append(entry)
        guard !scheduled else { return }
        scheduled = true
        worker.asyncAfter(deadline: .now() + .milliseconds(100)) { self.drain() }
    }

    private func drain() {
        lock.lock()
        let batch = pending, skipped = dropped
        pending.removeAll(keepingCapacity: true); dropped = 0; scheduled = false
        lock.unlock()
        do {
            if skipped > 0 {
                try append(Entry(time: Date().timeIntervalSince1970, uptime: ProcessInfo.processInfo.systemUptime,
                                 event: "recording.dropped", fields: ["count": String(skipped)]))
            }
            for entry in batch { try append(entry) }
        } catch {
            // Disk errors must never propagate into player/UI callbacks.
            try? handle?.close(); handle = nil
        }
    }

    private func append(_ entry: Entry) throws {
        var fields: [String: String] = [:]
        for (key, value) in entry.fields {
            let sensitive = ["token", "password", "authorization", "cookie"].contains { key.lowercased().contains($0) }
            fields[key] = sensitive ? "[redacted]" : ASMActivityLogPolicy.clean(value)
        }
        let object: [String: Any] = ["time": entry.time, "uptime": entry.uptime,
                                     "session": session, "event": entry.event, "details": fields]
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(10)
        // A single byte-bounded event fits even the smallest rotation limit.
        if handle == nil {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: current.path) {
                _ = FileManager.default.createFile(atPath: current.path, contents: nil)
            }
            handle = try FileHandle(forWritingTo: current)
            bytes = Int(try handle!.seekToEnd())
        }
        if bytes + data.count > limit {
            try handle?.close(); handle = nil
            if FileManager.default.fileExists(atPath: previous.path) { try FileManager.default.removeItem(at: previous) }
            try FileManager.default.moveItem(at: current, to: previous)
            _ = FileManager.default.createFile(atPath: current.path, contents: nil)
            handle = try FileHandle(forWritingTo: current); bytes = 0
        }
        try handle?.write(contentsOf: data)
        bytes += data.count
    }

    /// A stable copy, including queued breadcrumbs, rather than sharing a file
    /// that is still being rotated. Completion runs on the utility queue.
    func export(completion: @escaping (Result<URL, Error>) -> Void) {
        worker.async {
            self.drain()
            do {
                var data = Data()
                for file in [self.previous, self.current] where FileManager.default.fileExists(atPath: file.path) {
                    data.append(try Data(contentsOf: file))
                }
                guard !data.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
                try data.write(to: self.exported, options: .atomic)
                completion(.success(self.exported))
            } catch { completion(.failure(error)) }
        }
    }

    func clear(completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock(); pending.removeAll(); dropped = 0; lock.unlock()
        worker.async {
            do {
                try self.handle?.close(); self.handle = nil; self.bytes = 0
                for file in [self.current, self.previous, self.exported] where FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
                completion(.success(()))
            } catch { completion(.failure(error)) }
        }
    }
}

/// Utility-queue state: at most one outstanding pulse on main, one stall event
/// per stall and one recovery event. No backlogged heartbeat blocks.
struct ASMActivityHeartbeat {
    enum Tick: Equatable { case request, stalled, none }
    private var requestedAt: TimeInterval?
    private var reported = false
    mutating func tick(at now: TimeInterval) -> Tick {
        guard let start = requestedAt else { requestedAt = now; return .request }
        if !reported && now - start >= 3 { reported = true; return .stalled }
        return .none
    }
    mutating func complete(at now: TimeInterval) -> TimeInterval? {
        let duration = reported ? requestedAt.map { max(0, now - $0) } : nil
        requestedAt = nil; reported = false
        return duration
    }
    mutating func reset() { requestedAt = nil; reported = false }
}
