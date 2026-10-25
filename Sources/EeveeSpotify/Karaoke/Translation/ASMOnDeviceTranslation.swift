import SwiftUI
import NaturalLanguage
import Translation

@available(iOS 26.0, *)
enum ASMAppleTranslation {
    static func availability() -> LanguageAvailability {
        if #available(iOS 26.4, *) { return LanguageAvailability(preferredStrategy: .lowLatency) }
        return LanguageAvailability()
    }
    static func session(source: Locale.Language, target: Locale.Language) -> TranslationSession {
        if #available(iOS 26.4, *) {
            return TranslationSession(installedSource: source, target: target, preferredStrategy: .lowLatency)
        }
        return TranslationSession(installedSource: source, target: target)
    }
    static func configuration(source: String, target: String) -> TranslationSession.Configuration {
        if #available(iOS 26.4, *) {
            return .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target), preferredStrategy: .lowLatency)
        }
        return .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
    }
}

/// No SwiftUI translationTask here: these sessions cannot request downloads or
/// present language-identification UI. All ML and cache work stays off the main
/// actor and outside the lyric animation loop.
@available(iOS 26.0, *)
private actor ASMTranslationWorker {
    static let shared = ASMTranslationWorker()
    struct Outcome { var values: [String: String]; var status: String }
    func translate(_ plan: ASMTranslationPlan, options: ASMTranslationOptions) async throws -> Outcome {
        let target = Locale.Language(identifier: options.target)
        var groups: [String: [String]] = [:], uncertain = 0, downloads = 0, unavailable = 0
        var result: [String: String] = [:]
        for text in plan.texts {
            try Task.checkCancellation()
            if let supplied = plan.supplied[text] {
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(supplied)
                if let guess = recognizer.languageHypotheses(withMaximum: 1).first,
                   ASMTranslationPlan.matchesTarget(guess.key.rawValue, confidence: guess.value, target: options.target) {
                    result[text] = supplied
                    continue
                }
            }
            let source: String
            if options.source != "auto" { source = options.source }
            else {
                // Detect each line independently so multilingual songs are
                // never sent as one mixed-language translation batch.
                guard text.unicodeScalars.filter({ CharacterSet.letters.contains($0) }).count >= 4 else { uncertain += 1; continue }
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(text)
                guard let guess = recognizer.languageHypotheses(withMaximum: 1).first,
                      guess.value >= 0.65, guess.key != .undetermined else { uncertain += 1; continue }
                source = guess.key.rawValue
            }
            guard source != options.target else { continue }
            groups[source, default: []].append(text)
        }
        for source in groups.keys.sorted() {
            let texts = groups[source]!
            let cached = await ASMTranslationCache.shared.lookup(texts, source: source, target: options.target)
            result.merge(cached) { _, new in new }
            let missing = texts.filter { cached[$0] == nil }
            guard !missing.isEmpty else { continue }
            let language = Locale.Language(identifier: source)
            let status = await ASMAppleTranslation.availability().status(from: language, to: target)
            try Task.checkCancellation()
            guard status == .installed else {
                if status == .supported { downloads += missing.count } else { unavailable += missing.count }
                continue
            }
            let session = ASMAppleTranslation.session(source: language, target: target)
            defer { session.cancel() }
            guard !session.canRequestDownloads else { continue }
            var translated: [String: String] = [:]
            do {
                for offset in stride(from: 0, to: missing.count, by: 16) {
                    try Task.checkCancellation()
                    let batch = Array(missing[offset..<min(offset + 16, missing.count)])
                    let requests = batch.enumerated().map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }
                    let replies = try await withTaskCancellationHandler {
                        try await session.translations(from: requests)
                    } onCancel: {
                        session.cancel()
                    }
                    try Task.checkCancellation()
                    for reply in replies {
                        if let (original, text) = ASMTranslationPlan.reply(identifier: reply.clientIdentifier,
                            original: reply.sourceText, translated: reply.targetText, batch: batch) {
                            translated[original] = text
                        }
                    }
                }
            } catch {
                try Task.checkCancellation()
                unavailable += missing.count - translated.count
            }
            result.merge(translated) { _, new in new }
            await ASMTranslationCache.shared.store(translated, source: source, target: options.target)
        }
        try Task.checkCancellation()
        var notes = ["\(result.count) lines ready"]
        if downloads > 0 { notes.append("\(downloads) need language downloads") }
        if uncertain > 0 { notes.append("\(uncertain) skipped: uncertain language") }
        if unavailable > 0 { notes.append("\(unavailable) unavailable") }
        return Outcome(values: result, status: notes.joined(separator: " · "))
    }
}

final class ASMSweetTranslationModel: ObservableObject {
    struct Presentation {
        var values: [String: String] = [:]
        var revision = 0
    }
    @Published private(set) var presentation = Presentation()
    private var selection = ASMTranslationSelection()
    private var visibleOptions: ASMTranslationOptions?
    @MainActor func load(_ job: ASMTranslationJob, reduceMotion: Bool) async {
        let token = selection.begin()
        guard job.foreground else { return }
        if visibleOptions != job.options || !job.options.enabled { publish([:], reduceMotion: reduceMotion) }
        visibleOptions = job.options
        guard job.options.enabled, !job.plan.texts.isEmpty else { return }
        let signature = job.track.map(ASMSongLyricsContext.signature)
        var savedValues: [String: String] = [:]
        if let track = job.track, let signature {
            let saved = await Task.detached(priority: .utility) {
                ASMLyricsOfflineLibrary.shared.translations(track, signature: signature, target: job.options.target)
            }.value
            guard selection.accepts(token, cancelled: Task.isCancelled) else { return }
            savedValues = saved
            if !saved.isEmpty { publish(saved, reduceMotion: reduceMotion) }
        }
        guard #available(iOS 26.0, *) else { return }
        do {
            let outcome = try await ASMTranslationWorker.shared.translate(job.plan, options: job.options)
            guard selection.accepts(token, cancelled: Task.isCancelled) else { return }
            // Publish a whole document together, never one reflow per reply.
            savedValues.merge(outcome.values) { _, new in new }
            publish(savedValues, reduceMotion: reduceMotion)
            if let track = job.track, let signature, ASMSongLyricsContext.signature(track) == signature {
                ASMLyricsPreparedTranslations.shared.store(savedValues, track: track, signature: signature, target: job.options.target)
                let values = savedValues
                await Task.detached(priority: .utility) {
                    ASMLyricsOfflineLibrary.shared.storeTranslations(values, track: track, signature: signature, target: job.options.target)
                }.value
            }
            UserDefaults.standard.set(outcome.status, forKey: "asm.lyrics.translation.lastStatus")
        } catch { /* Keep original lyrics and player state intact. No alerts. */ }
    }
    @MainActor private func publish(_ values: [String: String], reduceMotion: Bool) {
        guard presentation.values != values else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            presentation = Presentation(values: values, revision: presentation.revision + 1)
        }
    }
}
