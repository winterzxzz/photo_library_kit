import Photos
import UIKit

struct ThumbnailRequest {
  let width: Int
  let height: Int
  let quality: Int
  let png: Bool
  let cover: Bool
  let allowNetwork: Bool

  init(_ m: [String: Any]) {
    width = max(1, m["w"] as? Int ?? 256)
    height = max(1, m["h"] as? Int ?? 256)
    quality = m["q"] as? Int ?? 85
    png = (m["fmt"] as? Int) == 1
    cover = (m["fit"] as? Int) != 1
    allowNetwork = m["net"] as? Bool ?? true
  }

  var size: CGSize { CGSize(width: width, height: height) }
  var contentMode: PHImageContentMode { cover ? .aspectFill : .aspectFit }

  var options: PHImageRequestOptions {
    let o = PHImageRequestOptions()
    // One callback with the final image; no degraded first pass to encode.
    o.deliveryMode = .highQualityFormat
    o.resizeMode = .fast
    o.isNetworkAccessAllowed = allowNetwork
    o.isSynchronous = false
    return o
  }
}

/// Thumbnails through `PHCachingImageManager`, with per-request cancellation
/// and cropping/encoding on a background queue.
final class ThumbnailManager {
  private let manager = PHCachingImageManager()
  private let encodeQueue = DispatchQueue(label: "photo_library_kit.encode", qos: .userInitiated, attributes: .concurrent)
  private let lock = NSLock()
  private var inFlight: [Int: PHImageRequestID] = [:]
  private var cancelledEarly = Set<Int>()
  private var finishedEarly = Set<Int>()

  init() {
    manager.allowsCachingHighQualityImages = false
  }

  func request(asset: PHAsset, rid: Int, req: ThumbnailRequest, done: @escaping (Data?) -> Void) {
    lock.lock()
    if cancelledEarly.remove(rid) != nil { lock.unlock(); return done(nil) }
    lock.unlock()

    let id = manager.requestImage(for: asset, targetSize: req.size, contentMode: req.contentMode, options: req.options) {
      [weak self] image, info in
      guard let self else { return done(nil) }
      self.lock.lock()
      if self.inFlight.removeValue(forKey: rid) == nil { self.finishedEarly.insert(rid) }
      self.lock.unlock()
      if (info?[PHImageCancelledKey] as? Bool) == true { return done(nil) }
      guard let image else { return done(nil) }
      self.encodeQueue.async { done(Self.encode(image, req)) }
    }
    lock.lock()
    // The handler may already have run synchronously for cached images.
    var cancelNow = false
    if finishedEarly.remove(rid) == nil && id != PHInvalidImageRequestID {
      // A cancel may have arrived while requestImage was running.
      if cancelledEarly.remove(rid) != nil { cancelNow = true } else { inFlight[rid] = id }
    }
    lock.unlock()
    if cancelNow { manager.cancelImageRequest(id) }
  }

  func cancel(rid: Int) {
    lock.lock()
    let id = inFlight.removeValue(forKey: rid)
    if id == nil { cancelledEarly.insert(rid) }
    if cancelledEarly.count > 512 { cancelledEarly.removeAll() }
    lock.unlock()
    if let id { manager.cancelImageRequest(id) }
  }

  func startCaching(_ assets: [PHAsset], _ req: ThumbnailRequest) {
    manager.startCachingImages(for: assets, targetSize: req.size, contentMode: req.contentMode, options: req.options)
  }

  func stopCaching(_ assets: [PHAsset], _ req: ThumbnailRequest) {
    manager.stopCachingImages(for: assets, targetSize: req.size, contentMode: req.contentMode, options: req.options)
  }

  func reset() { manager.stopCachingImagesForAllAssets() }

  /// Crops (cover) or scales (contain) to the requested box at scale 1,
  /// baking in the orientation, then encodes.
  private static func encode(_ image: UIImage, _ req: ThumbnailRequest) -> Data? {
    let src = image.size
    guard src.width > 0, src.height > 0 else { return nil }
    let target: CGSize
    let drawRect: CGRect
    if req.cover {
      let scale = min(1, max(CGFloat(req.width) / src.width, CGFloat(req.height) / src.height))
      let drawn = CGSize(width: src.width * scale, height: src.height * scale)
      target = CGSize(width: min(CGFloat(req.width), drawn.width).rounded(), height: min(CGFloat(req.height), drawn.height).rounded())
      drawRect = CGRect(x: (target.width - drawn.width) / 2, y: (target.height - drawn.height) / 2, width: drawn.width, height: drawn.height)
    } else {
      let scale = min(1, min(CGFloat(req.width) / src.width, CGFloat(req.height) / src.height))
      target = CGSize(width: (src.width * scale).rounded(), height: (src.height * scale).rounded())
      drawRect = CGRect(origin: .zero, size: target)
    }
    guard target.width >= 1, target.height >= 1 else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    // 8-bit output: avoid wide-color/extended buffers for P3 photos.
    format.preferredRange = .standard
    format.opaque = !req.png
    let renderer = UIGraphicsImageRenderer(size: target, format: format)
    if req.png {
      return renderer.pngData { _ in image.draw(in: drawRect) }
    }
    return renderer.jpegData(withCompressionQuality: CGFloat(req.quality) / 100) { _ in image.draw(in: drawRect) }
  }
}
