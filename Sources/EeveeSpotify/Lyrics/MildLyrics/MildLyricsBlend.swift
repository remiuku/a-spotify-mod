import Foundation

enum MildLyricsBlend {
    struct Definition: Identifiable, Hashable {
        let id: String
        let label: String
        let donors: [String]
    }
    static let definitions = [
        Definition(id: "blend", label: "Base + QQ", donors: ["qq"]),
        Definition(id: "kublend", label: "Base + Kugou", donors: ["kugou"]),
        Definition(id: "neblend", label: "Base + NetEase", donors: ["netease"]),
        Definition(id: "triblend", label: "Base + NetEase + QQ", donors: ["netease", "qq"]),
        Definition(id: "kutriblend", label: "Base + NetEase + Kugou", donors: ["netease", "kugou"]),
        Definition(id: "kwblend", label: "Base + Kuwo", donors: ["kuwo"]),
        Definition(id: "kwtriblend", label: "Base + NetEase + Kuwo", donors: ["netease", "kuwo"]),
    ]
    static func key(_ text: String) -> [Unicode.Scalar] {
        text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    }

    // Retains base characters and borrows donor cut points, rather than inventing equal word times.
    static func relay(text: String, donor: [KaraokeSyllableDto], floor: Double = 0.65) -> [KaraokeSyllableDto]? {
        let raw = Array(text.unicodeScalars)
        let indexes = raw.indices.filter { CharacterSet.alphanumerics.contains(raw[$0]) }
        let ours = key(text)
        guard !ours.isEmpty, ours.count == indexes.count else { return nil }
        let spans = donor.compactMap { syllable -> (KaraokeSyllableDto, [Unicode.Scalar])? in
            let k = key(syllable.text)
            return k.isEmpty ? nil : (syllable, k)
        }
        let theirs = spans.flatMap { $0.1 }
        guard !theirs.isEmpty, MildSequenceMatcher.ratio(theirs, ours) >= floor else { return nil }
        var cuts: [Int] = [], covered = 0
        for span in spans { covered += span.1.count; cuts.append(covered) }
        if ours != theirs {
            var at = [Int](repeating: 0, count: theirs.count + 1), low = at, high = at
            var loose: Int?
            for edit in MildSequenceMatcher.edits(theirs, ours) {
                if edit.equal {
                    for k in 0..<edit.a.count {
                        let i = edit.a.lowerBound + k, j = edit.b.lowerBound + k
                        at[i] = j; low[i] = j; high[i] = j
                    }
                    if let loose { low[edit.a.lowerBound] = loose }
                } else if !edit.a.isEmpty {
                    for k in 0..<edit.a.count {
                        let i = edit.a.lowerBound + k
                        at[i] = edit.b.lowerBound + Int((Double(k * edit.b.count) / Double(edit.a.count)).rounded(.toNearestOrEven))
                        low[i] = edit.b.lowerBound; high[i] = edit.b.upperBound
                    }
                }
                loose = edit.equal ? nil : edit.b.lowerBound
            }
            at[theirs.count] = ours.count; low[theirs.count] = loose ?? ours.count; high[theirs.count] = ours.count
            let breaks = Set([0, ours.count] + (1..<ours.count).filter { indexes[$0] - indexes[$0 - 1] > 1 })
            cuts = cuts.map { b in
                (low[b]...high[b]).filter { breaks.contains($0) }.min {
                    let l = abs($0 - at[b]), r = abs($1 - at[b])
                    return l == r ? $0 > $1 : l < r
                } ?? at[b]
            }
        }
        var out: [KaraokeSyllableDto] = [], previous = 0, held: Int?
        for (span, end) in zip(spans, cuts) {
            var stop = end < indexes.count ? indexes[max(0, end)] : raw.count
            if end > 0 && end < indexes.count {
                let lo = indexes[end - 1] + 1
                while stop > lo && CharacterSet.whitespacesAndNewlines.contains(raw[stop - 1]) { stop -= 1 }
                while stop < indexes[end] && CharacterSet.whitespacesAndNewlines.contains(raw[stop]) { stop += 1 }
            }
            guard stop >= previous else { return nil }
            let piece = String(String.UnicodeScalarView(raw[previous..<stop]))
            if key(piece).isEmpty {
                if !out.isEmpty { out[out.count - 1].endMs = max(out.last!.endMs, span.0.endMs) }
                else { held = min(held ?? span.0.startMs, span.0.startMs) }
                continue
            }
            var body = piece
            while body.last?.isWhitespace == true { body.removeLast() }
            var next = KaraokeSyllableDto(text: body, startMs: held ?? span.0.startMs,
                                          endMs: max(span.0.startMs, span.0.endMs), isPartOfWord: piece == body)
            if let last = out.last, last.isPartOfWord, last.text.hasSuffix("'") || last.text.hasSuffix("’") {
                next.text = last.text + next.text; next.startMs = last.startMs
                out.removeLast()
            }
            out.append(next); held = nil; previous = stop
        }
        guard !out.isEmpty else { return nil }
        if previous < raw.count { out[out.count - 1].text += String(String.UnicodeScalarView(raw[previous...])).trimmingCharacters(in: .whitespacesAndNewlines) }
        out[out.count - 1].isPartOfWord = false
        return out
    }

    static func blend(base: KaraokeLyricsDto, donors: [KaraokeLyricsDto], baseName: String, donorNames: [String]) -> KaraokeLyricsDto? {
        guard !base.lines.isEmpty, !donors.isEmpty else { return nil }
        let a = base.lines.map { key($0.plainText) }
        var result = base, takes: [Int: (KaraokeLineDto, String)] = [:]
        for (donorNumber, donor) in donors.enumerated() {
            let valid = donor.lines.filter { line in
                let source = line.sweetSyllables ?? line.syllables
                return source.count > 1 && Set(source.map(\.startMs)).count > 1 && source.allSatisfy { $0.endMs >= $0.startMs }
            }
            let b = valid.map { key($0.plainText) }
            guard !b.isEmpty else { continue }
            var paired: [Int: Int] = [:], used: Set<Int> = []
            for block in MildSequenceMatcher.blocks(a, b) where block.count > 0 {
                for k in 0..<block.count where !a[block.a + k].isEmpty {
                    paired[block.a + k] = block.b + k; used.insert(block.b + k)
                }
            }
            let anchors = paired.keys.sorted()
            for i in a.indices where paired[i] == nil && !a[i].isEmpty {
                let lower = anchors.last(where: { $0 < i }).flatMap { paired[$0] }.map { $0 + 1 } ?? 0
                let upper = anchors.first(where: { $0 > i }).flatMap { paired[$0] } ?? b.count
                guard lower < upper else { continue }
                let best = (lower..<upper).filter { !used.contains($0) }.map { ($0, MildSequenceMatcher.ratio(a[i], b[$0])) }.max { $0.1 < $1.1 }
                if let best, best.1 >= 0.78 { paired[i] = best.0; used.insert(best.0) }
            }
            var pieces: [Int: [KaraokeSyllableDto]] = [:]
            for (i, j) in paired { pieces[i] = valid[j].sweetSyllables ?? valid[j].syllables }
            // A source can split a sentence differently. Exact character streams can be
            // regrouped without changing words or fabricating intermediate timestamps.
            for i in a.indices where pieces[i] == nil && !a[i].isEmpty {
                let lower = paired.keys.filter { $0 < i }.max().flatMap { paired[$0] }.map { $0 + 1 } ?? 0
                let upper = paired.keys.filter { $0 > i }.min().flatMap { paired[$0] } ?? b.count
                guard lower < upper else { continue }
                var found = false
                for j in lower..<upper where !used.contains(j) && !found {
                    for length in 2...3 where j + length <= upper {
                        let range = j..<(j + length)
                        if range.contains(where: { used.contains($0) }) { continue }
                        if range.flatMap({ b[$0] }) == a[i] {
                            pieces[i] = range.flatMap { valid[$0].sweetSyllables ?? valid[$0].syllables }
                            used.formUnion(range); found = true; break
                        }
                    }
                    if found { break }
                    for length in 2...3 where i + length <= a.count {
                        let range = i..<(i + length)
                        guard !range.contains(where: { pieces[$0] != nil }), range.flatMap({ a[$0] }) == b[j] else { continue }
                        let syllables = valid[j].sweetSyllables ?? valid[j].syllables
                        var boundaries: [Int: Int] = [0: 0], count = 0
                        for (s, syllable) in syllables.enumerated() { count += key(syllable.text).count; boundaries[count] = s + 1 }
                        var at = 0, split: [Int: [KaraokeSyllableDto]] = [:]
                        for line in range {
                            guard let start = boundaries[at], let end = boundaries[at + a[line].count], start < end else { break }
                            split[line] = Array(syllables[start..<end]); at += a[line].count
                        }
                        if split.count == length { pieces.merge(split) { old, _ in old }; used.insert(j); found = true; break }
                    }
                }
            }
            guard pieces.count >= max(1, Int(ceil(Double(min(a.count, b.count)) * 0.6))) else { continue }
            for i in pieces.keys.sorted() where takes[i] == nil {
                let source = pieces[i]!
                guard let syllables = relay(text: base.lines[i].plainText, donor: source) else { continue }
                var new = base.lines[i]
                new.syllables = syllables; new.sweetSyllables = syllables
                new.startMs = syllables.first!.startMs; new.endMs = syllables.last!.endMs
                if let j = paired[i] {
                    new.backgroundGroups = valid[j].backgroundGroups
                    if key(valid[j].plainText) == key(base.lines[i].plainText) {
                        new.translation = new.translation ?? valid[j].translation
                        new.pronunciation = new.pronunciation ?? valid[j].pronunciation
                    }
                }
                takes[i] = (new, donorNumber < donorNames.count ? donorNames[donorNumber] : "word timing")
            }
        }
        guard !takes.isEmpty else { return nil }
        let anchors = takes.keys.sorted().map { (base.lines[$0].startMs, takes[$0]!.0.startMs) }
        func shifted(_ time: Int) -> Int {
            let before = anchors.last(where: { $0.0 <= time }) ?? anchors[0]
            let after = anchors.first(where: { $0.0 >= time }) ?? anchors.last!
            guard before.0 != after.0 else { return time + before.1 - before.0 }
            return Int((Double(before.1) + Double(time - before.0) * Double(after.1 - before.1) / Double(after.0 - before.0)).rounded())
        }
        result.lines = base.lines.enumerated().map { index, line in
            if let taken = takes[index] { return taken.0 }
            var retimed = line
            let delta = shifted(line.startMs) - line.startMs
            retimed.startMs = max(0, line.startMs + delta); retimed.endMs = max(retimed.startMs, line.endMs + delta)
            retimed.syllables = line.syllables.map { var s = $0; s.startMs = max(0, s.startMs + delta); s.endMs = max(s.startMs, s.endMs + delta); return s }
            retimed.sweetSyllables = retimed.syllables
            retimed.backgroundGroups = line.backgroundGroups.map { $0.map { var s = $0; s.startMs = max(0, s.startMs + delta); s.endMs = max(s.startMs, s.endMs + delta); return s } }
            return retimed
        }
        let names = Array(Set(takes.values.map { $0.1 })).sorted().joined(separator: " + ")
        result.providerName = "Mild blend: \(baseName) words + \(names) timing"
        return result
    }
}
