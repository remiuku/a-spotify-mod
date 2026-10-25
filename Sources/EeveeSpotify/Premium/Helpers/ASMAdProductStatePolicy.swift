import Foundation

/// Restrict this override to the client ad flag. Keep licence, catalogue,
/// country, streaming rules and all other account data byte-for-byte equivalent.
enum ASMAdProductStatePolicy {
    static func string(for key: String) -> String? { key == "ads" ? "0" : nil }

    static func rewrite(_ values: NSDictionary) -> NSDictionary {
        if let ads = values["ads"] as? String, ads == "0" { return values }
        let copy = values.mutableCopy() as! NSMutableDictionary
        copy["ads"] = "0"
        return copy
    }

    // Only report a small known flag vocabulary, never arbitrary account values.
    static func describe(_ value: Any?) -> String {
        guard let value else { return "missing" }
        if let text = value as? String, ["0", "1", "true", "false"].contains(text) { return text }
        if let number = value as? NSNumber, number == 0 || number == 1 { return number.stringValue }
        return "other"
    }
}
