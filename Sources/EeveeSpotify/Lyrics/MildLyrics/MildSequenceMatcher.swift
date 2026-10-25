import Foundation

// Adapted from Mild Lyrics' difflib-based alignment. AGPL-3.0; see THIRD_PARTY_MILD_LYRICS.md.
enum MildSequenceMatcher {
    struct Block: Equatable { let a: Int; let b: Int; let count: Int }
    struct Edit { let a: Range<Int>; let b: Range<Int>; let equal: Bool }

    static func blocks<T: Hashable>(_ a: [T], _ b: [T]) -> [Block] {
        var positions: [T: [Int]] = [:]
        for (i, value) in b.enumerated() { positions[value, default: []].append(i) }
        var pending = [(0, a.count, 0, b.count)], found: [Block] = []
        while let (loA, hiA, loB, hiB) = pending.popLast() {
            var best = Block(a: loA, b: loB, count: 0), previous: [Int: Int] = [:]
            for i in loA..<hiA {
                var current: [Int: Int] = [:]
                for j in positions[a[i]] ?? [] where j >= loB && j < hiB {
                    let count = (previous[j - 1] ?? 0) + 1
                    current[j] = count
                    if count > best.count { best = Block(a: i - count + 1, b: j - count + 1, count: count) }
                }
                previous = current
            }
            guard best.count > 0 else { continue }
            found.append(best)
            if loA < best.a && loB < best.b { pending.append((loA, best.a, loB, best.b)) }
            if best.a + best.count < hiA && best.b + best.count < hiB {
                pending.append((best.a + best.count, hiA, best.b + best.count, hiB))
            }
        }
        found.sort { $0.a == $1.a ? $0.b < $1.b : $0.a < $1.a }
        var merged: [Block] = []
        for block in found {
            if let last = merged.last, last.a + last.count == block.a, last.b + last.count == block.b {
                merged[merged.count - 1] = Block(a: last.a, b: last.b, count: last.count + block.count)
            } else { merged.append(block) }
        }
        merged.append(Block(a: a.count, b: b.count, count: 0))
        return merged
    }

    static func ratio<T: Hashable>(_ a: [T], _ b: [T]) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        return 2 * Double(blocks(a, b).reduce(0) { $0 + $1.count }) / Double(a.count + b.count)
    }

    static func edits<T: Hashable>(_ a: [T], _ b: [T]) -> [Edit] {
        var result: [Edit] = [], i = 0, j = 0
        for block in blocks(a, b) {
            if i < block.a || j < block.b { result.append(Edit(a: i..<block.a, b: j..<block.b, equal: false)) }
            if block.count > 0 { result.append(Edit(a: block.a..<(block.a + block.count), b: block.b..<(block.b + block.count), equal: true)) }
            i = block.a + block.count; j = block.b + block.count
        }
        return result
    }
}
