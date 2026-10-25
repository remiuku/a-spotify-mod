# Spicetify DJ Info tempo lookup

Upstream: https://github.com/L3-N0X/spicetify-dj-info
Version: 2.4.2, commit d8220d2e48d5d28aa3cb19f20577dec4ac6066d5
Copyright 2023 L3-N0X. MIT licence is bundled as DJInfo-LICENSE.txt.

The native Swift adapter follows src/api/metadata.mjs getFeatures: request
Spotify's internal audio-attributes/v1/audio-features batch JSON endpoint, then
its single-track ?format=json fallback; normalize batch or single tempo data.
It uses the existing native Spotify session token in memory, the actual app
version and iOS platform header. It adds no login, developer API key or token
storage. Authentication/rate failures do not trigger an immediate fallback.

Only the current track is requested. The bounded cache contains track IDs,
validated tempo and date, never session tokens. Replies are bound to the
requested track. HTTP errors, no tempo and missing native session are visible
in the hidden dancer settings. Endpoint availability is not guaranteed.
No popularity, year, key or extended-metadata protobuf code was ported.

The independent local fallback estimates onset autocorrelation from read-only
local output. It was written for this patch, not copied from DJ Info. Method
background: Daniel P. W. Ellis, Beat Tracking by Dynamic Programming (2007),
https://www.ee.columbia.edu/~dpwe/pubs/Ellis07-beattrack.pdf
The local fallback does not implement that paper's complete beat tracker or
infer a reliable downbeat map.
