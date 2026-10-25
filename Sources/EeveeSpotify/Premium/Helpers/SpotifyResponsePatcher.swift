import Foundation

// Shared by SPTDataLoaderServiceHook and HttpClientURLSessionHook. Lyrics is
// kept in each caller because its async fetch doesn't fit a sync transform.
enum SpotifyResponsePatcher {

    // Patched customize body, replayed for 304s and post-startup re-fetches
    // so ad flags can't re-enable mid-session. Touched from two hook classes on
    // URLSession's concurrent delegate queues — all access is lock-guarded.
    private static let lock = NSLock()
    private static var _cachedCustomizeData: Data?
    private static var _handledCustomizeTasks = Set<ObjectIdentifier>()

    static var cachedCustomizeData: Data? {
        get { lock.lock(); defer { lock.unlock() }; return _cachedCustomizeData }
        set {
            lock.lock()
            _cachedCustomizeData = newValue
            lock.unlock()
            // Setting defaults can synchronously notify observers. Never hold
            // the cache lock while another component may read the cache again.
            // Mirror to disk: on a warm relaunch the customize fetch comes back
            // 304 (no body) and the in-memory cache is empty in the new process.
            // Without the persisted copy there is nothing to replay and
            // Spotify's disk-cached unpatched config re-enables ad flags —
            // the fingerprint behind the "random crashes within minutes of
            // relaunch" reports (empty/unpatched config + ad surfaces that the
            // tweak then kills mid-render).
            UserDefaults.cachedCustomizeData = newValue
        }
    }

    static func markCustomizeTaskHandled(_ task: URLSessionTask) {
        lock.lock(); defer { lock.unlock() }
        _handledCustomizeTasks.insert(ObjectIdentifier(task))
    }

    /// Upgrade a disk-only replay through the current rules. Otherwise an app
    /// update returning 304 can keep replaying a cache lacking newly added flags.
    static func customizeReplayData() -> Data? {
        guard UserDefaults.patchType.isPatching else { return nil }
        if let cached = cachedCustomizeData { return cached }
        guard let stored = UserDefaults.cachedCustomizeData else { return nil }
        do {
            var message = try CustomizeMessage(serializedBytes: stored)
            guard case .response? = message.result else { return nil }
            modifyRemoteConfiguration(&message.response)
            let data = try message.serializedData()
            cachedCustomizeData = data
            ASMActivityRecorder.store.record("configuration.cache_upgraded", ["bytes": String(data.count)])
            return data
        } catch {
            ASMActivityRecorder.store.record("configuration.failed", ["endpoint": "cached-customize"])
            return nil
        }
    }

    // Task identifiers repeat across URLSession instances. A replay in one
    // session must not suppress the configuration body in another session.
    static func consumeCustomizeTask(_ task: URLSessionTask) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _handledCustomizeTasks.remove(ObjectIdentifier(task)) != nil
    }

    static func shouldBlock(_ url: URL) -> Bool {
        let elapsed = Date().timeIntervalSince(tweakInitTime)
        let path = url.path.lowercased()

        if url.isDeleteToken || url.isSessionInvalidation
            || path.contains("session/purge") || path.contains("token/revoke")
            || url.isAdRelated {
            return true
        }
        if path.contains("/dac/view/v1/") { return true }

        // 30s grace: signup/public is part of fresh-login; blocking pre-30s
        // breaks first-launch.
        if elapsed > 30 {
            return url.isAccountValidate || url.isOndemandSelector
                || url.isTrialsFacade || url.isPremiumMarketing || url.isPendragonFetchMessageList
                || url.isPushkaTokens
                || url.path.contains("signup/public") || url.path.contains("apresolve")
                || url.path.contains("pses/screenconfig")
        }
        return false
    }

    // Customize policy shared by shouldBlock/shouldModify. We do NOT blanket-block
    // customize: when the cache is cold there is nothing to replay, and serving an
    // empty body re-enables free-tier flags (crash/ad recurrence). Instead we let
    // the request through to a real 200 (patched on arrival), or synthesize a 200
    // from cache for 304s — see the URLSession hooks.
    static func shouldHandleCustomize(_ url: URL) -> Bool {
        url.isCustomize && UserDefaults.patchType.isPatching
    }

    static func shouldModify(_ url: URL) -> Bool {
        let shouldPatchPremium = BasePremiumPatchingGroup.isActive || PremiumBootstrapGroup.isActive
        let shouldReplaceLyrics = BaseLyricsGroup.isActive
        let isDAC = url.path.lowercased().contains("/dac/view/v1/")

        return (shouldReplaceLyrics && url.isLyrics)
            || (shouldPatchPremium && (
                url.isBootstrap || shouldHandleCustomize(url) ||
                url.isPremiumPlanRow || url.isPremiumBadge || url.isPlanOverview ||
                isDAC
            ))
            || BrowsitaSectionStripper.shouldHandle(url)
    }

    static func blockedResponseData(for url: URL) -> Data {
        if url.isAccountValidate {
            return #"{"status":1,"country":"US","is_country_launched":true}"#.data(using: .utf8)!
        }
        if url.isTrialsFacade {
            return #"{"result":"NOT_ELIGIBLE"}"#.data(using: .utf8)!
        }
        if url.isPremiumMarketing {
            return #"{}"#.data(using: .utf8)!
        }
        if url.isSessionInvalidation
            || url.path.contains("session/purge")
            || url.path.contains("token/revoke")
            || url.path.contains("signup/public")
            || url.path.contains("apresolve") {
            // Logout daemons parse the body; synthetic OK keeps them off the
            // actual logout codepath.
            return #"{"status":"OK"}"#.data(using: .utf8)!
        }
        if url.path.contains("pses/screenconfig") {
            return #"{}"#.data(using: .utf8)!
        }
        return Data()
    }

    enum PatchTag: String {
        case bootstrap   = "bootstrap"
        case customize   = "customize"
        case planRow     = "PremiumPlanRow"
        case planBadge   = "YourPremiumBadge"
        case planOverview = "PlanOverview"
        case dacEmpty    = "dac"
        case casitaStrip = "casitaStrip"
    }

    struct PatchResult {
        let data: Data
        let tag: PatchTag
    }

    static func patch(url: URL, buffer: Data) throws -> PatchResult? {
        if url.isPremiumPlanRow {
            return PatchResult(
                data: try getPremiumPlanRowData(
                    originalPremiumPlanRow: try PremiumPlanRow(serializedBytes: buffer)
                ),
                tag: .planRow
            )
        }
        if url.isPremiumBadge {
            return PatchResult(data: try getPremiumPlanBadge(), tag: .planBadge)
        }
        if url.isBootstrap {
            var msg = try BootstrapMessage(serializedBytes: buffer)
            if UserDefaults.patchType == .requests {
                modifyRemoteConfiguration(&msg.ucsResponse)
                UserDefaults.hasPatchedBootstrap = true
                ASMActivityRecorder.store.record("configuration.patched", ["endpoint": "bootstrap"])
            }
            return PatchResult(data: try msg.serializedBytes(), tag: .bootstrap)
        }
        if url.isCustomize {
            guard shouldHandleCustomize(url) else { return nil }
            var msg = try CustomizeMessage(serializedBytes: buffer)
            // An error envelope is not a fresh configuration. Preserve it for
            // Spotify's retry logic rather than caching an empty response.
            guard case .response? = msg.result else { return nil }
            modifyRemoteConfiguration(&msg.response)
            let data = try msg.serializedData()
            cachedCustomizeData = data
            ASMActivityRecorder.store.record("configuration.patched", ["endpoint": "customize", "bytes": String(data.count)])
            return PatchResult(data: data, tag: .customize)
        }
        if url.isPlanOverview {
            return PatchResult(data: try getPlanOverviewData(), tag: .planOverview)
        }
        if url.path.lowercased().contains("/dac/view/v1/") {
            // Empty body = "no ad to render" to the DAC consumer.
            return PatchResult(data: Data(), tag: .dacEmpty)
        }
        if BrowsitaSectionStripper.shouldHandle(url) {
            if let stripped = BrowsitaSectionStripper.strip(buffer, url: url) {
                return PatchResult(data: stripped, tag: .casitaStrip)
            }
            // Ad survived in a feed we parse but found no marker in — visible
            // only via this log. Testers hitting ads can now hand us the exact
            // feed + payload size to dig new markers out of.
            writeDebugLog("[STRIP] no-match \(url.path) size=\(buffer.count)")
            return nil
        }
        return nil
    }

    // Selected metadata only: no authorization, payload, URL query or account ID.
    static func recordConfigurationResponse(url: URL, status: Int) {
        guard url.isBootstrap || url.isCustomize else { return }
        ASMActivityRecorder.store.record("configuration.response", [
            "endpoint": url.isBootstrap ? "bootstrap" : "customize",
            "status": String(status),
            "patching": String(UserDefaults.patchType.isPatching)
        ])
    }
}
