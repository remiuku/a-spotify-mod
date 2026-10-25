import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
if CommandLine.arguments.contains("--pcm") {
    let bytes = FileHandle.standardInput.readDataToEndOfFile()
    let values = bytes.withUnsafeBytes { buffer in Array(buffer.bindMemory(to: Float.self)) }
    if let result = ASMTempoEstimator.estimate(values) { print(result.bpm) } else { print("none") }
} else {
    for bpm in [60.0, 80, 90, 100, 120, 128, 150, 172, 200] {
        var onsets = [Float](repeating: 0, count: 1600)
        var beat = 0.0
        while beat < 16 {
            let index = Int((beat * 100).rounded())
            if index < onsets.count { onsets[index] = 1 }
            beat += 60 / bpm
        }
        let estimate = ASMTempoEstimator.estimate(onsets)
        check(estimate != nil && abs(estimate!.bpm - bpm) < 2, "Regular pulse tempo \(bpm) should be recovered, got \(String(describing: estimate?.bpm))")
    }
    check(ASMTempoEstimator.estimate(Array(repeating: 0, count: 1600)) == nil, "Silence never creates a tempo")
    check(ASMTempoEstimator.estimate(Array(repeating: 1, count: 1600)) == nil, "Flat energy never creates a tempo")
    check(ASMTempoEstimator.estimate(Array(repeating: .nan, count: 1600)) == nil, "Non-finite input is sanitized")
    check(ASMTempoEstimator.estimate(Array(repeating: 0, count: 799)) == nil, "Require eight seconds of evidence")
    var seed: UInt64 = 12345
    let noise: [Float] = (0..<1600).map { _ in seed = seed &* 6364136223846793005 &+ 1; return Float(seed >> 40) / Float(1 << 24) }
    check(ASMTempoEstimator.estimate(noise) == nil, "Irregular noise is rejected by periodicity confidence")
    let track = "TrackA"
    func decode(_ json: String) -> ASMDancerTempo? { ASMDJInfoTempoPolicy.decode(Data(json.utf8), track: track) }
    check(decode(#"{"id":"TrackA","tempo":128.5}"#)?.bpm == 128.5, "DJ Info single-track JSON")
    check(decode(#"{"audio_features":[{"id":"TrackA","tempo":130}]}"#)?.bpm == 130, "DJ Info batch JSON")
    check(decode(#"{"audio_features":[null,{"id":"TrackB","tempo":70},{"id":"TrackA","tempo":130}]}"#)?.bpm == 130, "Bind batch records to the requested Spotify ID")
    check(decode(#"{"id":"TrackB","tempo":130}"#) == nil && decode(#"{"uri":"spotify:track:TrackB","tempo":130}"#) == nil, "Reject another song's tempo")
    check(decode(#"{"error":{"status":403},"tempo":130}"#) == nil && decode(#"{"tempo":0}"#) == nil, "Reject denied/invalid tempo")
    check(decode(#"{"audio_features":[null]}"#) == nil && decode("not json") == nil, "Missing or malformed data keeps fallback")
    print("PASS tempo: regular pulses, silence/noise rejection, warmup, DJ Info batch/single decoding and exact-track/error guards")
}
