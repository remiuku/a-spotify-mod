import Foundation
import MediaPlayer

final class MildLyricsRepository: LyricsRepository {
    static let shared = MildLyricsRepository()
    private let serial = DispatchQueue(label: "eevee.mild.lookup")
    private var cache: [(LyricsSearchQuery, MildLyricsOptions, KaraokeLyricsDto)] = []

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        return try serial.sync(execute: { () throws -> LyricsDto in
            let settings = UserDefaults.mildLyricsOptions
            if let cached = cache.first(where: { $0.0 == query && $0.1 == settings }) { return publish(cached.2, query) }
            guard !query.title.isEmpty, !query.primaryArtist.isEmpty else { throw LyricsError.noSuchSong }
            var duration = 0.0
            if KaraokePlaybackTracker.shared.playerReportedTrackId() == query.spotifyTrackId {
                let read = { duration = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0 }
                if Thread.isMainThread { read() } else { DispatchQueue.main.sync(execute: read) }
            }
            let remote = MildRemoteSources(query: query, duration: duration)
            var results: [String: KaraokeLyricsDto] = [:]
            var attemptedSpicy = false
            if settings.choice("blend") == "off", settings.orderedSources.first(where: { !settings.disabledSources.contains($0) }) == "spicy",
               settings.preferredUploaders.isEmpty, settings.excludedUploaders.isEmpty {
                attemptedSpicy = true
                if (try? SpicyLyricsRepository.mild.getLyrics(query, options: options)) != nil,
                   let rich = KaraokeLyricsStore.shared.lyrics(forTrackId: query.spotifyTrackId) {
                    results["spicy"] = rich
                    if Self.wordTimed(rich), !settings.flag("uncensor") || !rich.lines.contains(where: { $0.plainText.contains("***") }) {
                        cache.insert((query, settings, rich), at: 0)
                        if cache.count > 12 { cache.removeLast() }
                        return publish(rich, query)
                    }
                }
            }
            var plainFallback: LyricsDto?
            let lock = NSLock(), group = DispatchGroup(), pool = DispatchQueue(label: "eevee.mild.providers", attributes: .concurrent)
            let limit = DispatchSemaphore(value: 4)
            for id in settings.orderedSources where !settings.disabledSources.contains(id) && !(id == "spicy" && attemptedSpicy) {
                group.enter()
                pool.async {
                    limit.wait(); defer { limit.signal(); group.leave() }
                    do {
                        let doc: KaraokeLyricsDto?
                        switch id {
                        case "spicy":
                            _ = try SpicyLyricsRepository.mild.getLyrics(query, options: options)
                            doc = KaraokeLyricsStore.shared.lyrics(forTrackId: query.spotifyTrackId)
                        case "lrclib", "mxm", "genius":
                            let repo: LyricsRepository
                            switch id {
                            case "lrclib": repo = LrclibLyricsRepository.shared
                            case "mxm": repo = MusixmatchLyricsRepository.shared
                            default: repo = GeniusLyricsRepository()
                            }
                            let result = try repo.getLyrics(query, options: options)
                            if !result.timeSynced && !result.lines.isEmpty { lock.lock(); plainFallback = result; lock.unlock() }
                            doc = KaraokeLyricsDto.lineSynced(from: result, providerName: MildLyricsOptions.sourceName(id) ?? id)
                        default: doc = try remote.fetch(id)
                        }
                        if let doc, !doc.lines.isEmpty {
                            let names = [doc.uploaderName, doc.makerName].compactMap { $0?.lowercased() }
                            let excluded = settings.excludedUploaders.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
                            guard !names.contains(where: { excluded.contains($0) }) else { return }
                            lock.lock(); results[id] = doc; lock.unlock()
                        }
                    } catch { writeDebugLog("[Mild] \(id): unavailable (\(type(of: error)))") }
                }
            }
            group.wait()
            let preferred = settings.preferredUploaders.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
            let ranked = settings.orderedSources.filter { results[$0] != nil }.sorted { a, b in
                let left = results[a]!, right = results[b]!
                let lp = [left.uploaderName, left.makerName].compactMap { $0?.lowercased() }.contains { preferred.contains($0) }
                let rp = [right.uploaderName, right.makerName].compactMap { $0?.lowercased() }.contains { preferred.contains($0) }
                if lp != rp { return lp }
                let lq = Self.wordTimed(left), rq = Self.wordTimed(right)
                if lq != rq { return lq }
                return settings.orderedSources.firstIndex(of: a)! < settings.orderedSources.firstIndex(of: b)!
            }
            guard let first = ranked.first, var chosen = results[first] else {
                if var fallback = plainFallback { fallback.providerCredit = "Mild · Genius"; return fallback }
                throw LyricsError.noSuchSong
            }
            if let definition = MildLyricsBlend.definitions.first(where: { $0.id == settings.choice("blend") }) {
                let baseID = settings.orderedSources.first { ["apple", "lrclib", "mxm"].contains($0) && results[$0] != nil }
                if let baseID, let base = results[baseID] {
                    let donors = definition.donors.compactMap { id -> (String, KaraokeLyricsDto)? in results[id].map { (id, $0) } }
                    if let blended = MildLyricsBlend.blend(base: base, donors: donors.map(\.1), baseName: base.providerName ?? baseID, donorNames: donors.map { MildLyricsOptions.sourceName($0.0) ?? $0.0 }) {
                        // Keep an earlier preferred word-timed catalogue above a blend of later sources.
                        if !Self.wordTimed(chosen) || settings.orderedSources.firstIndex(of: baseID)! <= settings.orderedSources.firstIndex(of: first)! { chosen = blended }
                    }
                }
            }
            if settings.flag("uncensor") {
                chosen.lines = LyricsUncensorFill.fillKaraokeFromCandidates(lines: chosen.lines, candidates: results.values.map { $0.lines.map(\.plainText) })
            }
            cache.insert((query, settings, chosen), at: 0)
            if cache.count > 12 { cache.removeLast() }
            return publish(chosen, query)
        })
    }
    static func wordTimed(_ doc: KaraokeLyricsDto) -> Bool {
        doc.lines.contains { line in
            let syllables = line.sweetSyllables ?? line.syllables
            return syllables.count > 1 && Set(syllables.map(\.startMs)).count > 1 && syllables.contains { $0.endMs > $0.startMs }
        }
    }
    private func publish(_ doc: KaraokeLyricsDto, _ query: LyricsSearchQuery) -> LyricsDto {
        KaraokeLyricsStore.shared.set(trackId: query.spotifyTrackId, lyrics: doc)
        return LyricsDto(lines: doc.lines.map { LyricsLineDto(content: $0.plainText, offsetMs: $0.startMs) }, timeSynced: true,
                         romanization: .canBeRomanized, providerCredit: doc.providerName)
    }
}
