import Foundation
func require(_ test: @autoclosure () -> Bool, _ message: String) { precondition(test(), message) }
var settings = ASMArtworkOptions()
require(!settings.animates(active: true, playing: true, reduceMotion: false, lowPower: false), "default must preserve existing covers")
settings.enabled = true
require(settings.animates(active: true, playing: true, reduceMotion: false, lowPower: false), "enabled artwork")
require(!settings.animates(active: false, playing: true, reduceMotion: false, lowPower: false), "background motion")
require(!settings.animates(active: true, playing: false, reduceMotion: false, lowPower: false), "pause motion")
require(!settings.animates(active: true, playing: true, reduceMotion: true, lowPower: false), "reduce motion ignored")
require(!settings.animates(active: true, playing: true, reduceMotion: false, lowPower: true), "battery policy ignored")
settings.pauseWithMusic = false; settings.lowPowerStill = false
require(settings.animates(active: true, playing: false, reduceMotion: false, lowPower: true), "explicit policy options")
settings.radius = .nan; settings.motionDuration = -100; settings.pausedScale = 5; settings.shadow = .infinity
require(settings.safeRadius == 24 && settings.safeDuration == 2 && settings.safePausedScale == 1 && settings.safeShadow == 0.4, "unsafe presentation values")
let roundtrip = try! JSONDecoder().decode(ASMArtworkOptions.self, from: JSONEncoder().encode(ASMArtworkOptions()))
require(roundtrip == ASMArtworkOptions(), "settings round trip")
require(ASMArtworkMetadata.matches(artist: "Beyoncé", album: "RENAISSANCE", candidate: ["artistName":"Beyonce", "collectionName":"Renaissance"]), "case/accent matching")
require(!ASMArtworkMetadata.matches(artist: "Artist", album: "Album", candidate: ["artistName":"Other", "collectionName":"Album"]), "wrong artist accepted")
require(!ASMArtworkMetadata.matches(artist: "Artist", album: "Album", candidate: ["artistName":"Artist", "collectionName":"Album (Live)"]), "wrong edition accepted")
require(!ASMArtworkMetadata.matches(artist: "", album: "", candidate: [:]), "empty metadata matched")
func html(_ header: [String: Any], recommendations: [[String: Any]] = []) -> String {
    let object: [String: Any] = ["data":[["data":["sections":[["items":[header]], ["items":recommendations]]]]]]
    return "<html><script type=\"application/json\" id=\"serialized-server-data\">" + String(data: try! JSONSerialization.data(withJSONObject: object), encoding:.utf8)! + "</script></html>"
}
func art(_ url: String) -> [String: Any] { ["videoArtwork":["dictionary":["motionDetailSquare":["video":url]]]] }
let url = "https://mvod.itunes.apple.com/itunes-assets/test/default.m3u8"
require(ASMArtworkMetadata.squareVideo(inHTML: html(art(url)))?.absoluteString == url, "primary square HLS missing")
require(ASMArtworkMetadata.squareVideo(inHTML: html([:], recommendations: [art(url)])) == nil, "used recommendation as current album")
require(ASMArtworkMetadata.squareVideo(inHTML: html(art("http://mvod.itunes.apple.com/x.m3u8"))) == nil, "HTTP accepted")
require(ASMArtworkMetadata.squareVideo(inHTML: html(art("https://apple.com.evil.example/x.m3u8"))) == nil, "false Apple suffix accepted")
require(ASMArtworkMetadata.squareVideo(inHTML: html(art("https://mvod.itunes.apple.com/x.json"))) == nil, "non-video accepted")
require(ASMArtworkMetadata.squareVideo(inHTML: "<html>no artwork</html>") == nil, "no-video fallback")
print("PASS artwork: motion/system policy, safe geometry, persistence, strict album match, primary-only video extraction and still fallback")
