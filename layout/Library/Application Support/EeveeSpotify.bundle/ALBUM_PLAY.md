# Album button forwarding

Included in local build: activity-log 1.

Reported behavior: the album header Play button does nothing while the rest of
Spotify remains responsive. This differs from the earlier preferences watchdog.

The glass action row previously passed the header wrapper to the generic tap
bridge. That bridge visits wrapper recognizers before descendant controls and
can report success without reaching the actual UIButton. The row now resolves
the underlying UIControl with an activation registration first. Only a header
without such a control falls back to the generic gesture path.

The explicit button bridge sends one registered touchUpInside event, or a
primaryActionTriggered event for a primary-only control. It never sends both.
This restores the physical button activation path without changing generic tab
or player gesture forwarding. Disabled controls remain disabled. Deferred main
delivery, same-window validation and the shared recursion guard remain active.
The asynchronous preferences handoff from track-change 1 is retained.

Validation includes the actual event-selection policy for both registrations,
touch-only and primary-only controls, a single playback activation and recursion
rejection. UIKit interaction still requires device verification. In Spotify
interface mode, open an album and press the large Play button, then Pause and
Play again. Also check shuffle and saved, and select a Liked Songs track to
exercise the prior watchdog fix. Import into LiveContainer, fully close and
reopen it, and check Resources & credits for the build label above.
