# Player core ad requests: Vitrine adaptation

Upstream: https://github.com/Clone5030/vitrine
Revision: f5473f76958b22232f6034443b4af84107729dbb (October 23, 2026).
Original Vitrine authors: My-Name-Is-Jeff and Clone5030; inherited EeveeSpotify
network/premium work retains its existing authorship. Licence: GPL-3.0;
the complete Vitrine-LICENSE.txt and existing upstream notices are bundled.

Reviewed upstream files:

* tweak/Sources/Shared/AdBlock/AdNetwork.x
  SHA-256 14ea99127ee211e029b9ad9b6f5192fd6bd411570b267d5439f20e61b30a0f74.
* tweak/Sources/Shared/AdBlock/Premium.m
  SHA-256 a563faedd5200c306e488db5d2fa41679ff2a160c1bd5999653a2c9e8b78647e.

The Vitrine changelog documents native core ad-request interception (34681b5),
core ad-state fetching flags (0603f40), and exact Esperanto route tokens
(524d845). The ad-request fix was already in our Vitrine reference revision
7c3067f65b8b11f56fcf4a0e12f3a70b8f0a9947, but absent from the shared host.
The imported interface modules do not own shared network hooks, so selecting
another interface would not have supplied this missing host interception.

The current candidate adapts the narrow SPTCoreURLSessionDataDelegate block
to CoreAudioAdRequests.x.swift. Matching ad routes receive empty successful
headers/body; unrelated traffic passes through, network errors retain their
original completion error, and per-task associated state avoids cross-session
ID collisions. Calls to Orion's saved orig implementation deliver the empty
body without reentering suppression. Activation is restricted to the 9.1 path,
with class and all three callback selectors checked before hooking.

ASMCoreAdPolicy.swift restricts matching to actual spotify.com hosts and the
audio-ad config/state/inventory and token-delimited Esperanto routes. It does
not apply account/logout transformations or cancel core tasks. The existing
application-delegate Esperanto matcher now also uses whole ad/slot tokens,
preserving routes named Load, Download or metadata.

Two force-false assigned flags from Premium.m are added to the host rules:
core-ads.enable_state_fetch_system and
core-ad-detection.use_ad_placements_beta. A disk-only customize replay is
decoded and passed through the current rules before its first replay, upgrading
old persisted responses on a 304 without requiring data deletion or login reset.
The prior post-startup request-cancellation bugs are not reintroduced.

Device evidence motivating this adaptation: ad-product-state 1 activated both
client gates, but original ads was already 0 and adsEnabled was already false.
At October 24, 01:19:57 local time, item_kind=ad and InStreamAdsNPBHatViewController
appeared without a configuration refresh. The prior claim that the passive
client gate was the cause was not supported by that trace.

The original Spotify 9.1.88 build 918802209 binary was inspected. It contains
SPTCoreURLSessionDataDelegate and these callback encodings:
URLSession:dataTask:didReceiveResponse:completionHandler: v48@0:8@16@24@32@?40
URLSession:dataTask:didReceiveData: v40@0:8@16@24@32
URLSession:task:didCompleteWithError: v40@0:8@16@24@32.

Activity recording adds ads.core_hook, ads.core_request, ads.core_response,
ads.core_completion and configuration.cache_upgraded. Only fixed route labels,
HTTP status, age/size and success/error flags are recorded; no request URL,
query, headers, body, device ID or ad ID is saved.

Regression checks cover route boundaries, playback/login/AP lookup exclusions,
lookalike hosts, cold persisted-cache migration, disabled patching and invalid
cache preservation. The actual core hook still requires a phone test: compiler
and route-policy checks do not prove ad-free playback. Spotify Connect playback
on another device is controlled by that receiving device, outside these local
phone hooks.
