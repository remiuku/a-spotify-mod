import Foundation
func check(_ value: @autoclosure () -> Bool, _ text: String) { precondition(value(), text) }
let root = SpicyLyricsJSON(["source": "spicy_lyrics", "UploadAttribution": ["Uploader": ["username": "cg", "url": "https://spicylyrics.org/users/cg", "avatar": "https://cdn.example.org/cg.png"]]])
let attribution = SpicyCreditAttribution(root)
var lyrics = KaraokeLyricsDto(lines: [], songWriters: ["Writer"], providerCode: "spicy_lyrics", providerName: "Spicy Lyrics", uploaderName: attribution.uploader?.name, uploaderUrl: attribution.uploader?.profile, uploaderAvatarUrl: attribution.uploader?.avatar, creditOrigin: attribution.origin, creditProviderName: "Spicy Lyrics")
let rows = KaraokeCreditPolicy.rows(lyrics)
check(rows.map(\.text) == ["Provided by: Spicy Lyrics", "These lyrics have been provided by our community", "Made by @cg"], "Exact screenshot wording and order; writers are not pinned")
check(rows.last?.contributor?.avatar?.absoluteString == "https://cdn.example.org/cg.png", "Preserve real profile picture")
check(rows.last?.contributor?.profile?.absoluteString == "https://spicylyrics.org/users/cg", "Preserve contributor profile link")
lyrics.makerName = "@Maker"; lyrics.makerAvatarUrl = "https://cdn.example.org/maker.png"
check(KaraokeCreditPolicy.rows(lyrics).suffix(2).map(\.text) == ["Made by @Maker", "Uploaded by @cg"], "Maker and uploader have separate roles and one @ prefix")
lyrics.providerName = "Mild blend: base words + donor timing"
check(KaraokeCreditPolicy.rows(lyrics).first?.text == "Provided by: Spicy Lyrics", "Blending preserves original credit origin")
let external = KaraokeLyricsDto(lines: [], songWriters: [], providerCode: nil, providerName: "Unison", uploaderName: "Curator")
check(KaraokeCreditPolicy.rows(external).map(\.text) == ["Provided by: Unison", "Submitted by @Curator"], "Never invent a Spicy community credit for another source")
check(KaraokeCreditPolicy.rows(KaraokeLyricsDto(lines: [], songWriters: [], providerCode: nil)).isEmpty, "No invented attribution when data is missing")
let variants = SpicyCreditAttribution(SpicyLyricsJSON(["source": "APPLE-MUSIC", "UploadAttribution": ["Maker": ["Name": "M", "ProfileUrl": "https://github.com/M", "AvatarUrl": "https://avatars.githubusercontent.com/u/1"], "Uploader": "U"]]))
check(variants.origin == "Apple Music" && variants.maker?.name == "M" && variants.uploader?.name == "U" && variants.maker?.avatar != nil, "Case variants and string contributor records")
check(SpicyCreditAttribution(SpicyLyricsJSON([:])).maker == nil, "Malformed/missing attribution does not invent a person")
let unsafe = KaraokeCreditPolicy.contributor("  @test  ", profile: "javascript:alert(1)", avatar: "file:///private/avatar.png")!
check(unsafe.name == "test" && unsafe.profile == nil && unsafe.avatar == nil, "Only usable HTTPS avatar/profile URLs")
check(KaraokeCreditPolicy.contributor("name", profile: "https://unknown.example/user", avatar: "https://u:p@cdn.example/x")?.profile == nil, "Match trusted profile hosts")
check(KaraokeCreditPolicy.contributor("@@", profile: nil, avatar: nil) == nil, "Blank handle is omitted")
for width in [320.0,393,430,800] {
    let metrics = KaraokeCreditPolicy.Metrics(width: width)
    let base = min(56, max(29.6, width * 0.07))
    check(abs(metrics.providerSize - base * 0.34 * 1.15) < 0.00001, "Mobile provider font sizing")
    check(abs(metrics.avatarSize - metrics.providerSize * 1.4) < 0.00001, "Mobile avatar/text ratio")
    check(abs(metrics.horizontalInset - width * 0.05) < 0.00001, "Five percent edge inset")
    check(abs(metrics.margin(before: .community) - base * 0.3) < 0.00001, "Community row spacing")
    check(!metrics.compact && metrics.rowSpacing == 0, "Portrait keeps the stacked layout")
}
let landscape = KaraokeCreditPolicy.Metrics(width: 852, compact: true)
let landscapeBase = min(56, max(29.6, 852 * 0.07))
check(landscape.compact && landscape.lyricSize == 34 && landscape.lyricSize < landscapeBase, "Landscape caps the credit scale")
check(landscape.providerSize < KaraokeCreditPolicy.Metrics(width: 852).providerSize, "Landscape provider text is smaller than portrait")
check(landscape.rowSpacing > 0, "Landscape credit groups retain separation")
check(abs(landscape.margin(before: .community) - landscape.lyricSize * 0.3 * 0.6) < 0.00001, "Landscape row spacing shrinks")
print("PASS pinned credits: exact screenshot labels, API avatars/casing, maker/uploader roles, source and blend provenance, missing data, URL handling and Mobile font/spacing goldens")
