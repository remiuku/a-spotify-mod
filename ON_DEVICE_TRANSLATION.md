# On-device translations in Sweet Lyrics

Open **a spotify mod → Lyrics → Lyrics viewers → On-device translation**.
Choose a target language, enable the switch and prepare the source/target
languages with **Download languages**. Reopen Sweet Lyrics afterward. Automatic
language detection skips short/uncertain lines; use Song language to override it.
The page shows the last request summary and can clear the translation cache.

Automatic translation uses iOS 26's `TranslationSession(installedSource:target:)`.
It cannot request downloads or present language-selection UI. Only installed
language pairs are translated; missing or unsupported pairs leave the original
lyrics visible. The explicit setup button uses a view-bound translationTask and
prepareTranslation, where Apple's download UI is expected. iOS 26.4+ uses the
low-latency strategy for availability checks, downloads and translation alike.
Older iOS versions retain existing source-provided translation support.

Source-provided translations take precedence when their detected language
matches the chosen target (including Chinese script variants). Unknown or
different-language translations remain eligible for machine fallback. Machine translation remains a
separate display layer: source text, word timing, seek positions, audio settings
and provider credits are preserved. Repeated phrases are deduplicated; each
line's language is detected separately before batching. Responses are matched
by identifier and original text rather than response order. No Google key,
billing account or third-party translation server is used.

Translation/model work runs on a separate actor, outside animation callbacks.
Results appear beneath the original lines as one document update with a 0.25s
fade, rather than a reflow for every completed response. Auto-follow restores the
active line's scroll anchor after layout; manual scroll is respected. Reduce
Motion removes this animation. Translation tasks cancel on view/song/language
changes or backgrounding, and late results are rejected. Completed line results
are cached by exact source language, target language and original text in the
app's cache directory, bounded to 512 entries / 1 MiB.

Validation: 24 regression suites pass, including translation planning, supplied
translation preference, chorus deduplication, response ordering/ID rejection,
stale/cancelled request rejection, persistent language-isolated cache, bounds,
clear and corruption recovery. The actual Sweet rendering/physics/translation
sources and translation settings pass iOS 27.1 SDK typechecking at a 16.1
deployment target, with unrelated host services stubbed. No IPA was built for
this change. Real language downloads, silent execution in LiveContainer,
translation quality and visual smoothness still need a phone check.

References: https://developer.apple.com/documentation/translation/translationsession
and https://developer.apple.com/videos/play/wwdc2024/10117/.
