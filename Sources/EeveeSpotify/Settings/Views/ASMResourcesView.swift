import SwiftUI

enum ASMBrand {
    static let name = "a spotify mod"
    static let build = "core-ad-requests 1"
    static func style(_ button: UIButton) {
        button.setImage(nil, for: .normal)
        button.setTitle(":3", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 28, weight: .heavy)
        button.setTitleColor(.white, for: .normal)
        button.accessibilityLabel = name
    }
}

struct ASMResourcesView: View {
    @State private var contributors = false
    @State private var note = false
    private let projects: [(String, String, String)] = [
        ("EeveeSpotify Reincarnated", "Base patch, settings, player and customization", "https://github.com/SideloadLabs/EeveeSpotifyReincarnated"),
        ("spoti.pw · skopevoj", "GPL v0.21.1 interface, lyrics viewer and audio pipeline", "https://github.com/skopevoj/spoti.pw/tree/v0.21.1"),
        ("Vitrine · Clone5030 / My-Name-Is-Jeff", "Interface, artwork, lyrics and player-core ad request hooks", "https://github.com/Clone5030/vitrine"),
        ("Sweet Lyrics · sppqq", "Native lyrics renderer", "https://github.com/sppqq/sweet-lyrics-ios"),
        ("Mild Lyrics · gcoolL", "Sources, blends, lyric controls and effects", "https://github.com/gcoolL/mild-lyrics"),
        ("Spicy Lyrics", "Timed lyric catalogue and pinned credit layout", "https://github.com/spicylyrics/mobile"),
        ("Spicetify DJ Info · L3-N0X", "Spotify tempo lookup and response normalization", "https://github.com/L3-N0X/spicetify-dj-info"),
        ("JamesDSP · James Fung", "Audio processing engine", "https://github.com/james34602/JamesDSPManager"),
        ("JDSP4Linux · Audio4Linux", "Engine extensions and impulse-response tools", "https://github.com/Audio4Linux/JDSP4Linux"),
        ("RootlessJamesDSP · timschneeb", "Effect controls, Liveprog scripts and DDC presets", "https://github.com/timschneeb/RootlessJamesDSP"),
        ("ThePBone / JamesDSPManager", "JamesDSP engine extensions", "https://github.com/ThePBone/JamesDSPManager"),
        ("Apple Music / iTunes", "Matched public album video artwork; availability varies", "https://music.apple.com"),
        ("Theos + Orion", "Tweak build system and hooks", "https://theos.dev"),
        ("SwiftProtobuf · Apple", "Protobuf support", "https://github.com/apple/swift-protobuf"),
        ("cyan / pyzule-rw", "Local IPA injection", "https://github.com/asdfzxcvbn/pyzule-rw"),
        ("ipapatch / zxPluginsInject", "Sideload compatibility", "https://github.com/asdfzxcvbn/ipapatch"),
        ("xtool", "Windows/WSL Apple SDK setup", "https://xtool.sh"),
        ("boykisserfication", "Extension 0.67 behavior and seven image variants", "https://addons.mozilla.org/en-US/firefox/addon/boykisserfication/"),
        ("Spikerko", "Original idea, code and image hosting (extension README credit)", "https://github.com/Spikerko"),
        ("NaeNae", "Firefox extension fixes and packaging (extension README credit)", "https://github.com/NaeNaeTart"),
        ("LiveContainer", "Guest app runtime", "https://github.com/LiveContainer/LiveContainer")
    ]
    private let catalogues: [(String, String)] = [
        ("Spicy Lyrics", "https://spicylyrics.org"), ("LRCLIB", "https://lrclib.net"),
        ("Musixmatch", "https://www.musixmatch.com"), ("Genius", "https://genius.com"),
        ("PetitLyrics", "https://petitlyrics.com"), ("Apple lyric catalogue / lrc.red", "https://lrc.red"),
        ("AMLL", "https://api.amll.dev"), ("Unison", "https://unison.boidu.dev"),
        ("NetEase Cloud Music", "https://music.163.com"), ("Kugou", "https://www.kugou.com"),
        ("QQ Music", "https://y.qq.com"), ("Kuwo", "https://www.kuwo.cn")
    ]
    private let documents: [(String, String, String)] = [
        ("Completed dancer spin", "DANCER_LOOP", "md"),
        ("Audio ad configuration refresh", "AUDIO_AD_REFRESH", "md"),
        ("Audio ad product state", "AUDIO_AD_STATE", "md"),
        ("Player core ad requests and Vitrine credit", "THIRD_PARTY_CORE_ADS", "md"),
        ("Activity recording", "ACTIVITY_RECORDING", "md"),
        ("Album button forwarding", "ALBUM_PLAY", "md"),
        ("Track-change watchdog fix", "NOTIFICATION_HANDOFF", "md"),
        ("Album controls and response delivery", "ALBUM_CONTROLS", "md"),
        ("Sweet pause fix and latest UI", "SWEET_PAUSE", "md"),
        ("Playback & lyrics additions", "PLAYBACK_LYRICS", "md"),
        ("Settings menu map", "SIMPLE_MENU", "md"),
        ("Appearance preset notes", "APPEARANCE_PRESETS", "md"),
        ("Interfaces and lyrics viewers", "INTERFACES", "md"),
        ("Vitrine licence · GPL-3.0", "Vitrine-LICENSE", "txt"),
        ("Vitrine upstream notices", "Vitrine-UPSTREAM-NOTICES", "md"),
        ("Boykisserfication source and artwork credits", "THIRD_PARTY_BOYKISSER", "md"),
        ("Boykisser mode notes", "BOYKISSER_MODE", "md"),
        ("Dancing boykisser media and tempo notes", "DANCING_BOYKISSER", "md"),
        ("Spicetify DJ Info licence · MIT", "DJInfo-LICENSE", "txt"),
        ("Spicetify DJ Info adaptation notices", "THIRD_PARTY_DJ_INFO", "md"),
        ("Song lyrics and offline library", "SONG_LYRICS_OFFLINE", "md"),
        ("EeveeSpotify licence", "EeveeSpotify-LICENSE", "txt"),
        ("spoti.pw licence · GPL-3.0", "SpotiPW-GPL-3.0", "txt"),
        ("spoti.pw adaptation notices", "THIRD_PARTY_SPOTI_PW", "md"),
        ("JamesDSP licence", "JamesDSP-LICENSE", "txt"),
        ("JamesDSP origins and bundled assets", "JamesDSP-UPSTREAM-NOTICES", "md"),
        ("Spicy Mobile pinned credit adaptation", "THIRD_PARTY_SPICY_CREDITS", "md"),
        ("Spicy Mobile licence", "SpicyMobile-LICENSE", "txt"),
        ("Sweet Lyrics notices", "THIRD_PARTY_SWEET_LYRICS", "md"),
        ("Sweet Lyrics licence", "SweetLyrics-LICENSE", "txt"),
        ("Mild Lyrics notices", "THIRD_PARTY_MILD_LYRICS", "md"),
        ("Mild Lyrics licence", "MildLyrics-LICENSE", "txt"),
        ("Mild upstream notices", "MildLyrics-UPSTREAM-NOTICES", "md")
    ]
    var body: some View {
        List {
            Section {
                ASMText(ASMBrand.name).font(.title.bold())
                ASMText("asm_resources_intro".localized).font(.footnote).foregroundColor(.secondary)
                ASMText("Spotify \(EeveeSpotify.spotifyVersion) · Eevee base \(EeveeSpotify.version)").font(.footnote)
                ASMText("Local build: \(ASMBrand.build)").font(.footnote).foregroundColor(.secondary)
            }
            Section(header: ASMText("asm_resources_projects".localized)) {
                ForEach(projects, id: \.0) { project in
                    Link(destination: URL(string: project.2)!) {
                        VStack(alignment: .leading, spacing: 4) { ASMText(project.0); ASMText(project.1).font(.footnote).foregroundColor(.secondary) }
                    }
                }
            }
            Section(header: ASMText("asm_resources_licenses".localized)) {
                ForEach(documents, id: \.0) { document in
                    SettingsLink(title: document.0, icon: "doc.text", color: .gray) { ASMNoticeView(name: document.1, ext: document.2) }
                }
            }
            Section(header: ASMText("asm_resources_catalogues".localized)) {
                ForEach(catalogues, id: \.0) { item in ASMLink(item.0, destination: URL(string: item.1)!) }
            }
            Section {
                ASMButton("contributors".localized) { contributors = true }
                ASMButton("developer_note".localized) { note = true }
                ASMLink("asm_support_eevee".localized, destination: URL(string: "https://ko-fi.com/jaydenjcpy")!)
                ASMLink("asm_support_spoti".localized, destination: URL(string: "https://ko-fi.com/darkksh")!)
            }
        }
        .eeveeSettingsStyle()
        .sheet(isPresented: $contributors) { EeveeContributorsSheetView() }
        .sheet(isPresented: $note) { EeveeDevNoteView() }
    }
}

private struct ASMNoticeView: View {
    let name: String
    let ext: String
    var body: some View {
        ScrollView {
            ASMText(contents).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
        }
    }
    private var contents: String {
        guard let url = BundleHelper.shared.resourceURL(name, withExtension: ext), let text = try? String(contentsOf: url, encoding: .utf8) else { return "asm_resources_missing".localized }
        return text
    }
}
