# Audio ad configuration refresh

The user reported audio ads between tracks which temporarily disappear after
restarting LiveContainer. Device diagnostics from October 23 show request
patching enabled, AdsServiceImpl and InStreamAdsService load hooks attaching,
and a persisted 116,768-byte patched customize response. Some launches have a
logged fresh customize patch; others do not. This is not proof of the specific
ad-delivery path, but it rules out patching simply being switched off.

The response patcher incorrectly classified every customize refresh as blocked
after 30 seconds. That branch discarded incoming configuration bytes and
returned only the process-local cached body. A warm relaunch can have only the
persisted cache, so this returned an empty body even though the 304 response
handler had already replayed a valid persisted response. With a process-local
cache, it still dropped real configuration updates instead of patching them.

The network task hook also cancelled every customize request after 30 seconds,
before either response delegate could patch it. That cancellation has been
removed; request metadata is recorded instead.

Customize is now always handled as a response transformation. Real responses
are patched and persisted throughout the session; 304s use the existing replay
path, with a completion associated with the actual task object rather than a
numeric ID shared by unrelated URLSessions. Replayed tasks release any buffered
body. Disabling request patching suppresses customize replay and transformation.

Server error envelopes are passed through without replacing a good cache;
malformed configuration bodies are forwarded to Spotify's error/retry handling.
Defaults persistence runs after releasing the response cache lock, allowing
synchronous observers to read the cache safely.

Activity recording adds configuration.request, configuration.response, configuration.patched,
configuration.replayed and configuration.failed metadata. It records endpoint
kind, HTTP status, patching flag and body byte count as applicable, without
request URLs, authorization or configuration contents.

The focused regression runs the actual production response patcher with test
doubles for the Orion/protobuf integration. It covers the startup/30-second/
long-session boundary, absent and disk-only caches, two real URLSessions with
the same task identifier, reentrant defaults notification, server errors and
disabled patching. These checks do not prove ad-free playback. Confirm on the
phone over several track transitions, including a warm relaunch and a session
lasting more than 30 seconds, then inspect configuration activity events.
