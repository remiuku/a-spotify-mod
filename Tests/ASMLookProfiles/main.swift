import Foundation

func require(_ value: @autoclosure () -> Bool, _ message: String) { precondition(value(), message) }
func object(_ data: Any?) -> [String: Any] { try! JSONSerialization.jsonObject(with: data as! Data) as! [String: Any] }
func normalized(_ value: Any) -> Any {
    if let data=value as? Data { return ["data":data.base64EncodedString()] }
    if let dictionary=value as? [String:Any] { return dictionary.mapValues(normalized) }
    if let array=value as? [Any] { return array.map(normalized) }
    return value
}
func same(_ a: Any, _ b: Any) -> Bool {
    let first=try! JSONSerialization.data(withJSONObject:normalized(a),options:.sortedKeys)
    let second=try! JSONSerialization.data(withJSONObject:normalized(b),options:.sortedKeys)
    return first==second
}
let suite = "asm-look-tests-" + UUID().uuidString
let store = UserDefaults(suiteName: suite)!
defer { store.removePersistentDomain(forName: suite) }
let shared: [String: Any] = ["asm.dsp": true, "asm.dsp.eq.gains": "1;2;3", "asm.dsp.postGain": -6.0,
    "lyricsOptions": Data([1,2,3]), "eeveeKaraokeOptions": Data([4,5]), "musixmatchToken": "private-test",
    "eeveePlayerExtrasOptions": Data([6,7]), "eeveeFlagOverrides": ["example": true], "Spotify.account": "test"]
for (key,value) in shared { store.set(value,forKey:key) }
func checkShared() {
    for (key,value) in shared { require(same(["value":store.object(forKey:key)!],["value":value]), "changed shared setting \(key)") }
}
store.set(0x123456, forKey:"eeveeAccent")
store.set(Data("original artwork options".utf8),forKey:"asm.artwork.options")
let original = ASMLookProfiles.capture(store:store)
require(ASMLookProfiles.selected(store:store) == .personal,"must keep current look on first launch")
require(!ASMLookProfiles.select(.vitrine,supportsGlass:false,store:store),"unavailable glass selected")
require(same(original, ASMLookProfiles.capture(store:store)),"unsupported selection mutated appearance")
require(ASMLookProfiles.select(.spotify,supportsGlass:true,store:store),"stock selection")
require(store.bool(forKey:"eeveeAmoled") == false && store.integer(forKey:"eeveeAccent") == -1,"stock theme")
require(object(store.object(forKey:"eeveeLiquidGlassOptions"))["enabled"] as? Bool == false,"stock glass enabled")
require(object(store.object(forKey:"eeveePlayerOptions"))["backdrop"] as? Bool == false,"stock backdrop enabled")
let artwork=try! JSONDecoder().decode(ASMArtworkOptions.self,from:store.data(forKey:"asm.artwork.options")!)
require(!artwork.enabled && artwork.motion == .off,"motion unexpectedly enabled")
checkShared()
store.set(0xABCDEF,forKey:"eeveeAccent")
require(ASMLookProfiles.select(.spotipw,supportsGlass:true,store:store),"spoti selection")
require(object(store.object(forKey:"eeveeLiquidGlassOptions"))["enabled"] as? Bool == true,"spoti glass disabled")
require(object(store.object(forKey:"eeveeHomeGradient"))["enabled"] as? Bool == true,"spoti gradient disabled")
require(ASMLookProfiles.select(.vitrine,supportsGlass:true,store:store),"vitrine selection")
require(store.bool(forKey:"eeveeAmoled") && store.integer(forKey:"eeveeAccent") == 0x37F200,"vitrine theme")
require(object(store.object(forKey:"eeveeHomeGradient"))["enabled"] as? Bool == false,"vitrine not black")
require(object(store.object(forKey:"eeveePlaylistOptions"))["fullCover"] as? Bool == true,"vitrine full cover")
checkShared()
require(ASMLookProfiles.select(.spotify,supportsGlass:true,store:store),"return to edited stock")
require(store.integer(forKey:"eeveeAccent") == 0xABCDEF,"lost per-style edits")
require(ASMLookProfiles.resetSelected(store:store),"reset selected")
require(store.integer(forKey:"eeveeAccent") == -1,"reset didn't restore factory")
require(ASMLookProfiles.select(.personal,supportsGlass:true,store:store),"return to personal")
require(same(original, ASMLookProfiles.capture(store:store)),"original look not exactly restored, including unset keys")
require(!ASMLookProfiles.resetSelected(store:store),"personal look must not have a destructive factory reset")
require(!ASMLookProfiles.select(.personal,supportsGlass:true,store:store),"repeat selection must be a no-op")
ASMLookProfiles.save(slot:1,store:store)
store.set(42,forKey:"eeveeAccent")
// Even old/malformed slots cannot cross the appearance allowlist.
var old=store.dictionary(forKey:"asm.look.1")!; old["asm.dsp"]=false; old["eeveePlayerExtrasOptions"]=Data([99])
store.set(old,forKey:"asm.look.1")
require(ASMLookProfiles.restore(slot:1,store:store),"old slot restore")
require(same(original, ASMLookProfiles.capture(store:store)),"slot restore did not restore original")
require(!ASMLookProfiles.restore(slot:9,store:store),"invalid slot accepted")
checkShared()
print("PASS appearance presets: stock/glass recipes, OS guard, per-style edits, exact personal recovery, factory reset and legacy slots; audio, lyrics, gestures, flags and account data preserved")
