import Foundation

let values: NSDictionary = ["ads": "1", "type": "free", "catalogue": "free",
    "country": "US", "player-license": "free", "streaming-rules": "original",
    "nested": ["value": 17], "flag": true]
let changed = ASMAdProductStatePolicy.rewrite(values)
precondition(values["ads"] as? String == "1", "Never mutate the incoming state")
precondition(changed["ads"] as? String == "0")
precondition(changed.count == values.count)
for key in ["type", "catalogue", "country", "player-license", "streaming-rules", "nested", "flag"] {
    precondition(NSDictionary(object: changed[key]!, forKey: key as NSString).isEqual(to: [key: values[key]!]), "Unrelated value changed: \(key)")
    precondition(String(reflecting: type(of: changed[key]!)) == String(reflecting: type(of: values[key]!)))
    precondition(ASMAdProductStatePolicy.string(for: key) == nil)
}
precondition(ASMAdProductStatePolicy.string(for: "ads") == "0")
let unchanged: NSDictionary = ["ads": "0", "country": "US"]
precondition(ASMAdProductStatePolicy.rewrite(unchanged) === unchanged)
let missing: NSDictionary = ["type": "free", "country": "FR"]
let seeded = ASMAdProductStatePolicy.rewrite(missing)
precondition(seeded.count == missing.count + 1 && seeded["ads"] as? String == "0")
precondition(missing["ads"] == nil && seeded["type"] as? String == "free")
for incoming: Any in ["1", "true", 1, true, NSNull()] {
    precondition(ASMAdProductStatePolicy.rewrite(["ads": incoming])["ads"] as? String == "0")
}
precondition(ASMAdProductStatePolicy.describe("private-value") == "other")
precondition(ASMAdProductStatePolicy.describe(["unrelated": "private-value"]) == "other")
precondition(ASMAdProductStatePolicy.describe(nil) == "missing")
precondition(ASMAdProductStatePolicy.describe("1") == "1")
print("PASS ad product state: incoming dictionary preserved, only ads changed, licence/account/rules types retained, cached identity, missing flag and bounded diagnostics")
