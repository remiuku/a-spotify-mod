# Activity recording

Build: activity-log 1. Includes the album Play button forwarding correction and
the asynchronous preferences observer fix from track-change 1.

Open a spotify mod -> Advanced -> Troubleshooting -> Activity recording.
Record my activity is off by default and takes effect immediately. Enable it,
reproduce the problem, then Export activity recording. The system share sheet
exports a stable JSON-lines snapshot; no automatic upload or recipient is used.
After a crash, reopen the app and export from the same page. Turning recording
off stops new events; Clear activity recording removes current, previous and
export files. The pre-existing debug log remains available separately.

Recorded events: touch beginnings/endings/cancellations (view class and nearest
accessibility identifier), control target actions, screen appearances, mod menu
navigation, interface/viewer changes, track/play/pause/loading transitions, lyric
seeks, custom lyrics open/close, app lifecycle, and mod errors. Album controls
also record attempted buttons, rejected targets and dispatch results. Imported
interfaces share the global UIKit hooks and playback tracker. No complete view
tree, keyboard contents, request/response bodies, raw notification objects or
audio data are recorded. Error text is bounded and credential patterns and URL
queries/fragments are redacted before writing. Logs may contain listening history
and app identifiers; sharing is always an explicit action in the share sheet.

A utility-queue timer keeps at most one pending main pulse. A foreground pulse
delayed at least three seconds writes ui.stalled, then ui.recovered if main
returns. Background/suspended activity resets the monitor and stale pulse replies
are discarded. This is a breadcrumb, not a crash reporter or stack unwinder;
the last few queued events can be lost if the process is killed immediately.

The real store uses a short lock and bounded event queue, then writes on its own
utility queue. Neither UI nor player callbacks wait for file work or for main.
Two rolling files are limited to 1 MB each, with a separate export copy limited
to their combined size. Pending overflow produces recording.dropped. Files are
in the app sandbox's Library/Application Support/ASMActivity directory, outside
temporary storage, so they survive ordinary app restarts. Uninstalling/removing
the guest app can still remove them.

Tests exercise the actual Foundation store: disabled/no files, enable/disable,
redaction of bearer tokens, quoted JSON secrets and URL credentials, 4000
concurrent events, overflow reporting, repeated rotation, export, reopening,
clearing and one-pulse stall/recovery behavior. The UIKit hooks/share sheet and
album button still need confirmation on the phone.
