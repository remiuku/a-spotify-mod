// Adapted from Vitrine AdNetwork.x, GPL-3.0. See THIRD_PARTY_CORE_ADS.md.
import Foundation
import Orion
import ObjectiveC.runtime

struct ASMCoreAudioAdsGroup: HookGroup {}
private var coreAdTaskKey: UInt8 = 0

// 9.1.x's native player core uses a different delegate from the two application
// HTTP delegates. Intercept only identified ad routes; never cancel its tasks or
// apply account/session spoofing to this delegate.
class ASMCoreAudioAdRequestsHook: ClassHook<NSObject> {
    typealias Group = ASMCoreAudioAdsGroup
    static let targetName = "SPTCoreURLSessionDataDelegate"

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask,
                    didReceiveResponse response: URLResponse,
                    completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let url = task.currentRequest?.url ?? task.originalRequest?.url
        let endpoint = url.flatMap(ASMCoreAdPolicy.endpoint)
            ?? task.originalRequest?.url.flatMap(ASMCoreAdPolicy.endpoint)
        if let url, let endpoint,
           let empty = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:]) {
            objc_setAssociatedObject(task, &coreAdTaskKey, endpoint as NSString, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            ASMActivityRecorder.store.record("ads.core_response", ["endpoint": endpoint,
                "original_status": String((response as? HTTPURLResponse)?.statusCode ?? 0)])
            orig.URLSession(session, dataTask: task, didReceiveResponse: empty, completionHandler: handler)
        } else {
            objc_setAssociatedObject(task, &coreAdTaskKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
        }
    }

    func URLSession(_ session: URLSession, dataTask task: URLSessionDataTask, didReceiveData data: Data) {
        guard objc_getAssociatedObject(task, &coreAdTaskKey) == nil else { return }
        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }

    func URLSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let endpoint = objc_getAssociatedObject(task, &coreAdTaskKey) as? String
        objc_setAssociatedObject(task, &coreAdTaskKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if let endpoint {
            ASMActivityRecorder.store.record("ads.core_completion", ["endpoint": endpoint, "failed": String(error != nil)])
            if error == nil, let dataTask = task as? URLSessionDataTask {
                // orig calls the saved IMP, so this synthetic body bypasses our
                // didReceiveData suppression without reentry or a shared flag.
                orig.URLSession(session, dataTask: dataTask, didReceiveData: Data())
            }
        }
        orig.URLSession(session, task: task, didCompleteWithError: error)
    }
}

func activateASMCoreAudioAds() {
    // The iOS 14 bootstrap hook uses this class too. Keep that legacy path intact.
    guard EeveeSpotify.hookTarget == .v91 else { return }
    let selectors = ["URLSession:dataTask:didReceiveResponse:completionHandler:",
                     "URLSession:dataTask:didReceiveData:", "URLSession:task:didCompleteWithError:"]
    guard let cls = NSClassFromString(ASMCoreAudioAdRequestsHook.targetName), cls is NSObject.Type,
          selectors.allSatisfy({ class_getInstanceMethod(cls, NSSelectorFromString($0)) != nil }) else {
        ASMActivityRecorder.store.record("ads.core_hook", ["state": "unavailable"])
        return
    }
    ASMCoreAudioAdsGroup().activate()
    ASMActivityRecorder.store.record("ads.core_hook", ["state": "activated"])
}
