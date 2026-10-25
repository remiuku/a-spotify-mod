import Foundation
extension String { var localized: String { self } }
let domain = "asm-lyric-profiles-" + UUID().uuidString
let store = UserDefaults(suiteName: domain)!
defer { store.removePersistentDomain(forName: domain) }
var options = KaraokeOptions(); options.renderer = .vitrine; options.enabled = false; options.blurIntensity = 3; options.textAlignment = .trailing
store.set(try JSONEncoder().encode(options), forKey: "karaokeOptions")
var mild = MildLyricsOptions(); mild.numbers["spin"] = 2; mild.choices["blend"] = "triblend"; mild.disabledSources = ["qq"]; mild.sourceOrder = ["apple", "spicy"]; mild.flags["uncensor"] = false
store.set(try JSONEncoder().encode(mild), forKey: "mildLyricsOptions")
store.set(12, forKey: "asm.dsp.bass.gain"); store.set(6, forKey: "lyricsSource")
store.set("keep", forKey: "asm.interface.vitrine.redesign.tabs")
store.set(1, forKey: "asm.interface.vitrine.redesign.lyricsLook")
store.set(300, forKey: "asm.interface.vitrine.lyricsDelay")
store.set(true, forKey: "asm.interface.vitrine.lyricsProviders")
store.set(9, forKey: "asm.interface.spotipw.redesign.lyricsLook")
ASMLyricProfiles.save(.sweetLyrics, slot: 1, store: store)
mild.numbers["spin"] = 0; mild.choices["blend"] = "neblend"; mild.disabledSources = ["qq", "apple"]
store.set(try JSONEncoder().encode(mild), forKey: "mildLyricsOptions")
precondition(ASMLyricProfiles.restore(.sweetLyrics, slot: 1, store: store))
let restored = try JSONDecoder().decode(MildLyricsOptions.self, from: store.data(forKey: "mildLyricsOptions")!)
precondition(restored.number("spin") == 2 && restored.choice("blend") == "neblend" && restored.disabledSources == ["qq", "apple"] && !restored.flag("uncensor"))
ASMLyricProfiles.apply([:], viewer: .eevee, store: store)
let shared = try JSONDecoder().decode(KaraokeOptions.self, from: store.data(forKey: "karaokeOptions")!)
let eevee = try JSONDecoder().decode(KaraokeOptions.self, from: store.data(forKey: "asm.viewer.eevee")!)
precondition(shared == options && eevee.blurIntensity == 1.5 && eevee.textAlignment == .center)
ASMLyricProfiles.save(.vitrine, slot: 2, store: store)
ASMLyricProfiles.apply([:], viewer: .vitrine, store: store)
precondition(store.object(forKey: "asm.interface.vitrine.redesign.lyricsLook") == nil && store.object(forKey: "asm.interface.vitrine.lyricsDelay") == nil)
precondition(store.bool(forKey: "asm.interface.vitrine.lyricsProviders"))
precondition(ASMLyricProfiles.restore(.vitrine, slot: 2, store: store))
precondition(store.integer(forKey: "asm.interface.vitrine.lyricsDelay") == 300)
ASMLyricProfiles.apply(["asm.dsp.bass.gain": -100, "lyricsSource": 0, "asm.interface.spotipw.redesign.lyricsLook": 2, "mild": ["choices": ["blend": "off"]]], viewer: .vitrine, store: store)
precondition(store.integer(forKey: "asm.dsp.bass.gain") == 12 && store.integer(forKey: "lyricsSource") == 6)
precondition(store.integer(forKey: "asm.interface.spotipw.redesign.lyricsLook") == 9 && store.string(forKey: "asm.interface.vitrine.redesign.tabs") == "keep")
precondition(!ASMLyricProfiles.restore(.eevee, slot: 3, store: store))
precondition(!ASMLyricProfiles.restore(.eevee, slot: 4, store: store))
print("PASS lyric profiles: independent viewer reset, empty/invalid slots, source/blend/audio isolation and modified snapshot containment")
