import Foundation
func expect(_ actual: Double, _ expected: Double, _ reason: String) { precondition(abs(actual - expected) < 0.00001, "\(reason): \(actual) != \(expected)") }
var clock = ASMPlaybackClock()
expect(clock.position(at: 0), 0, "uninitialized")
clock.receive(position: 10, reportedSpeed: 1, audioRate: 1, playing: true, now: 0)
expect(clock.position(at: 2), 12, "normal interpolation")
clock.changeAudioRate(2, at: 2)
expect(clock.position(at: 2), 12, "rate boundary jumps")
expect(clock.position(at: 4), 16, "2x interpolation")
clock.receive(position: 17, reportedSpeed: 2, audioRate: 2, playing: true, now: 4.5)
expect(clock.position(at: 5), 18, "rate applied twice to player callback")
clock.changeAudioRate(0.5, at: 5)
expect(clock.position(at: 9), 20, "0.5x interpolation")
clock.receive(position: 20, reportedSpeed: 0, audioRate: 0.5, playing: false, now: 9)
clock.changeAudioRate(4, at: 10)
expect(clock.position(at: 12), 20, "paused clock moved")
clock.receive(position: 20, reportedSpeed: 4, audioRate: 4, playing: true, now: 13)
expect(clock.position(at: 14), 24, "resume")
clock.receive(position: 5, reportedSpeed: 4, audioRate: 4, playing: true, now: 14)
expect(clock.position(at: 15), 9, "seek at changed rate")
clock.changeAudioRate(.nan, at: 15)
expect(clock.position(at: 16), 10, "invalid audio factor")
clock.receive(position: .nan, reportedSpeed: .nan, audioRate: 1, playing: true, now: 16)
expect(clock.position(at: 17), 11, "invalid state recovery")
expect(clock.position(at: 15), 10, "backwards clock")
print("PASS lyric clock: continuous speed boundaries, no double rate, pause/resume, seek, invalid state recovery")

var pausedClock = ASMPlaybackClock()
pausedClock.receiveSpotifyState(position: 10, positionAsOfTimestamp: 8, reportedSpeed: 1,
                                paused: false, playing: true, loading: false, audioRate: 1, now: 100)
expect(pausedClock.position(at: 102), 12, "live player state advances")
// The exact failure: pause=true while isPlaying/rate and computed position still advance.
pausedClock.receiveSpotifyState(position: 15, positionAsOfTimestamp: 12, reportedSpeed: 1,
                                paused: true, playing: true, loading: false, audioRate: 1, now: 105)
expect(pausedClock.position(at: 165), 12, "pause wins over stale playing and uses fixed timestamp")
precondition(!pausedClock.isPlaying)
pausedClock.receiveSpotifyState(position: 75, positionAsOfTimestamp: 12, reportedSpeed: 1,
                                paused: true, playing: true, loading: false, audioRate: 1, now: 165)
expect(pausedClock.position(at: 200), 12, "repeated paused callbacks never advance lyrics")
pausedClock.changeAudioRate(2, at: 200)
expect(pausedClock.position(at: 210), 12, "audio speed changes while paused stay frozen")
pausedClock.receiveSpotifyState(position: 90, positionAsOfTimestamp: 40, reportedSpeed: 2,
                                paused: true, playing: true, loading: false, audioRate: 2, now: 210)
expect(pausedClock.position(at: 215), 40, "seek while paused moves to the new timestamp only")
pausedClock.receiveSpotifyState(position: 40, positionAsOfTimestamp: 40, reportedSpeed: 2,
                                paused: false, playing: true, loading: false, audioRate: 2, now: 215)
expect(pausedClock.position(at: 217), 44, "resume at changed speed uses the held/seeked position")
pausedClock.receiveSpotifyState(position: 44, positionAsOfTimestamp: 44, reportedSpeed: 2,
                                paused: false, playing: true, loading: true, audioRate: 2, now: 217)
expect(pausedClock.position(at: 220), 44, "buffering holds its anchor")
pausedClock.receiveSpotifyState(position: 50, positionAsOfTimestamp: nil, reportedSpeed: nil,
                                paused: true, playing: nil, loading: nil, audioRate: 1, now: 220)
expect(pausedClock.position(at: 250), 44, "paused state with missing anchor preserves held position")
var legacy = ASMPlaybackClock()
legacy.receiveSpotifyState(position: 5, positionAsOfTimestamp: nil, reportedSpeed: 1,
                           paused: nil, playing: true, loading: nil, audioRate: 1, now: 0)
expect(legacy.position(at: 1), 6, "legacy state without pause getter still plays")
legacy.receiveSpotifyState(position: 6, positionAsOfTimestamp: 6, reportedSpeed: 1,
                           paused: nil, playing: false, loading: nil, audioRate: 1, now: 1)
expect(legacy.position(at: 10), 6, "legacy playing=false pauses")
print("PASS Spotify pause state: conflicting flags, computed-position drift, repeated callbacks, speed changes, paused seeks, resume, buffering and legacy fallback")

var openedPaused = ASMPlaybackClock()
openedPaused.receiveSpotifyState(position: 18, positionAsOfTimestamp: nil, reportedSpeed: 1,
                                paused: true, playing: true, loading: false, audioRate: 1, now: 10)
expect(openedPaused.position(at: 70), 18, "initial paused fallback reads once and then holds")
