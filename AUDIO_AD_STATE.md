# Client audio-ad product state

The user heard a Spotify ad break with a numbered multi-ad counter on the
audio-refresh 2 build. The October 24 activity capture records non-track
playback and AdsNowPlaying_InStreamAdsImpl.InStreamAdsNPBHatViewController at
00:41:54 local time. No customize request occurred near that transition: the
only recorded request in that process was the startup 304 and successful replay
of the persisted 116,768-byte patched configuration. Configuration refresh is
therefore not sufficient to explain or prevent this observed ad break.

The existing CoreProductState and SPTAdsProductState hooks were passive: broad
dictionary rewrites, direct getter overrides and adsEnabled suppression were
all disabled. This candidate enables only client ad suppression. The core
dictionary setters/snapshots and the two keyed getters override the ads key
to string 0. All other account fields, including licence, catalogue, country,
streaming rules and subscription type, retain the original values and types.
The larger Premium rewrite and broad getter overrides remain disabled.

SPTAdsProductState.adsEnabled is hooked separately, after checking runtime
class compatibility, selector presence and BOOL return encoding. The original
answer is observed for diagnostics and the effective answer is false. This is
a candidate correction, not proof that Spotify's current audio scheduler uses
either gate on every playback path.

Activity recording adds ads.hooks and deduplicated ads.product_state events,
with route, incoming ad flag and effective ad flag. Diagnostics accept only
known flag values; arbitrary account data are not recorded. There are no
defaults writes, synchronous UI calls or file operations inside these hooks.
Playback events additionally classify track/ad/episode/local/other URIs,
without storing non-track URIs or IDs. Consecutive distinct items now produce
separate state events even when all are playing non-track items.

The Foundation policy regression checks that only ads changes, incoming state
is not mutated, account/rule values and types survive, missing flags are seeded,
already-disabled dictionaries are reused, and diagnostics remain bounded.
Phone confirmation requires a new playback session. If an ad returns, compare
ads.hooks, ads.product_state, item_kind and configuration events at the ad.

Earlier runtime reporting overstated the initial test: the 46-minute process
window contained a roughly 28-minute pause and skipped tracks. Distinct item
count was not a count of fully played songs or continuous listening time.
