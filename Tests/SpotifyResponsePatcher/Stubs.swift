import Foundation
import FoundationNetworking

// Orion and protobuf dependencies are doubles here. These checks exercise the
// production routing/cache code, not protobuf serialization or ad playback.
var tweakInitTime = Date()
enum BasePremiumPatchingGroup { static var isActive = true }
enum PremiumBootstrapGroup { static var isActive = true }
enum BaseLyricsGroup { static var isActive = false }
extension UserDefaults {
    static var patchType = EeveePatchType.requests
    static var hasPatchedBootstrap = false
    static var persisted: Data?
    static var cacheWriteObserver: (() -> Void)?
    static var cachedCustomizeData: Data? {
        get { persisted }
        set { persisted = newValue; cacheWriteObserver?() }
    }
}
enum ASMActivityRecorder {
    static let store = Store()
    final class Store {
        var events: [String] = []
        func record(_ name: String, _ details: [String: String]) { events.append(name) }
    }
}
struct TestConfiguration { var byte: UInt8 = 1 }
struct BootstrapMessage {
    var ucsResponse = TestConfiguration()
    init(serializedBytes: Data) throws {}
    func serializedBytes() throws -> Data { Data([ucsResponse.byte]) }
}
struct CustomizeMessage {
    enum Result { case response(TestConfiguration), error }
    var result: Result?
    var response: TestConfiguration {
        get { if case .response(let c)? = result { return c }; return TestConfiguration() }
        set { result = .response(newValue) }
    }
    init(serializedBytes: Data) throws {
        result = (serializedBytes.first ?? 0) > 0 ? .response(TestConfiguration(byte: serializedBytes.first!)) : .error
    }
    func serializedData() throws -> Data { Data([response.byte]) }
}
func modifyRemoteConfiguration(_ config: inout TestConfiguration) { config.byte = 2 }
struct PremiumPlanRow { init(serializedBytes: Data) throws {} }
func getPremiumPlanRowData(originalPremiumPlanRow: PremiumPlanRow) throws -> Data { Data() }
func getPremiumPlanBadge() throws -> Data { Data() }
func getPlanOverviewData() throws -> Data { Data() }
enum BrowsitaSectionStripper {
    static func shouldHandle(_ url: URL) -> Bool { false }
    static func strip(_ data: Data, url: URL) -> Data? { nil }
}
func writeDebugLog(_ message: String) {}

