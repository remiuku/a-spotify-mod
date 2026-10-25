import UIKit
import ImageIO

final class ASMDancerFrames: NSObject {
    let frames: [CGImage], ends: [Double], placements: [CGRect]
    let cost: Int
    init(frames: [CGImage], ends: [Double], placements: [CGRect], cost: Int) {
        self.frames = frames; self.ends = ends; self.placements = placements; self.cost = cost
    }
}
enum ASMDancerAssets {
    private struct Manifest: Decodable { let version: Int; let animations: [String: Animation] }
    private struct Animation: Decodable { let frames: [Frame]; let width: Int; let height: Int; let sourceSHA256: String? }
    private struct Frame: Decodable { let file: String; let seconds: Double; let bounds: [Int]? }
    private static let queue = DispatchQueue(label: "asm.dancer.png.decode", qos: .utility)
    private static let cache: NSCache<NSString, ASMDancerFrames> = {
        let cache = NSCache<NSString, ASMDancerFrames>(); cache.countLimit = 4; cache.totalCostLimit = 6 * 1024 * 1024; return cache
    }()
    static func load(_ animation: ASMDancerAnimation, completion: @escaping (ASMDancerFrames?, String) -> Void) {
        let manifest = BundleHelper.shared.resourceURL("frames", withExtension: "json", subdirectory: "DancingBoykisser")
        queue.async {
            func finish(_ frames: ASMDancerFrames?, _ status: String) { DispatchQueue.main.async { completion(frames, status) } }
            if let frames = cache.object(forKey: animation.rawValue as NSString) { finish(frames, "\(frames.frames.count) frames ready"); return }
            guard let manifest, let bytes = try? Data(contentsOf: manifest), bytes.count < 128 * 1024,
                  let metadata = try? JSONDecoder().decode(Manifest.self, from: bytes), metadata.version == 1,
                  let item = metadata.animations[animation.rawValue], !item.frames.isEmpty, item.frames.count <= 96 else {
                finish(nil, "Animation frames missing. Reimport the complete update."); return
            }
            let root = manifest.deletingLastPathComponent()
            var images: [CGImage] = [], ends: [Double] = [], boxes: [CGRect] = [], time = 0.0, cost = 0
            let tall = item.height > item.width * 3
            for entry in item.frames {
                guard !entry.file.hasPrefix("/"), !(entry.file as NSString).pathComponents.contains(".."), entry.file.hasSuffix(".png"),
                      entry.seconds.isFinite, (0.01...10).contains(entry.seconds),
                      let source = CGImageSourceCreateWithURL(root.appendingPathComponent(entry.file) as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
                      image.width <= 512, image.height <= 512 else {
                    finish(nil, "Could not decode bundled PNG frames."); return
                }
                cost += image.bytesPerRow * image.height
                guard cost <= 6 * 1024 * 1024 else { finish(nil, "Animation exceeds its memory budget."); return }
                if tall, let b = entry.bounds, b.count == 4, b[0] >= 0, b[1] >= 0, b[2] <= image.width, b[3] <= image.height, b[2] > b[0], b[3] > b[1] {
                    let box = CGRect(x: b[0], y: b[1], width: b[2] - b[0], height: b[3] - b[1])
                    guard let cropped = image.cropping(to: box) else { finish(nil, "Could not prepare bounce sprite."); return }
                    images.append(cropped); boxes.append(box)
                } else { images.append(image); boxes.append(CGRect(x: 0, y: 0, width: image.width, height: image.height)) }
                time += entry.seconds; ends.append(time)
            }
            if let closing = ASMDancerLoopPolicy.closingPose(animation: animation, sourceHash: item.sourceSHA256, frameCount: images.count) {
                // Another reference to the decoded image, not another bitmap.
                // A full pose interval avoids a half-frame disappearing at 30 Hz.
                images.append(images[closing]); boxes.append(boxes[closing])
                time += ASMDancerLoopPolicy.closingSeconds; ends.append(time)
            }
            let placements = tall ? ASMDancerSpritePolicy.placements(bounds: boxes) : images.map { _ in CGRect(x: 0, y: 0, width: 1, height: 1) }
            let result = ASMDancerFrames(frames: images, ends: ends, placements: placements, cost: cost)
            cache.setObject(result, forKey: animation.rawValue as NSString, cost: cost)
            finish(result, "\(images.count) frames ready · PNG")
        }
    }
}
