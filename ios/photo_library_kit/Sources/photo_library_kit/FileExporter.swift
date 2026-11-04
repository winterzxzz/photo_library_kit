import Foundation
import Photos
import UniformTypeIdentifiers

/// Exports asset resources to the app cache and saves/deletes library items.
final class FileExporter {
  let dir: URL = FileManager.default.temporaryDirectory.appendingPathComponent("photo_library_kit", isDirectory: true)

  /// Writes the current (edited) or original resource once and reuses it
  /// until the asset is modified.
  func export(_ asset: PHAsset, original: Bool, done: @escaping (Result<String?, Error>) -> Void) {
    let resources = PHAssetResource.assetResources(for: asset)
    let isVideo = asset.mediaType == .video
    let preferred: [PHAssetResourceType] = switch (isVideo, original) {
    case (true, true): [.video]
    case (true, false): [.fullSizeVideo, .video]
    case (false, true): [.photo]
    case (false, false): [.fullSizePhoto, .photo]
    }
    guard let resource = preferred.lazy.compactMap({ t in resources.first { $0.type == t } }).first
      ?? resources.first
    else { return done(.success(nil)) }

    let ext = UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension
      ?? (resource.originalFilename as NSString).pathExtension
    let stamp = (asset.modificationDate ?? asset.creationDate)?.ms ?? 0
    let safeId = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
    let url = dir.appendingPathComponent("\(safeId)_\(stamp)_\(original ? "o" : "c").\(ext)")
    if FileManager.default.fileExists(atPath: url.path) { return done(.success(url.path)) }

    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      return done(.failure(error))
    }
    // Unique per call so concurrent exports of the same asset never share it.
    let tmp = dir.appendingPathComponent("\(UUID().uuidString).part")
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    PHAssetResourceManager.default().writeData(for: resource, toFile: tmp, options: options) { error in
      if let error { try? FileManager.default.removeItem(at: tmp); return done(.failure(error)) }
      do {
        // Atomic publish so a concurrent caller never sees a half-written file.
        if FileManager.default.fileExists(atPath: url.path) {
          try? FileManager.default.removeItem(at: tmp)  // another call won
        } else {
          try FileManager.default.moveItem(at: tmp, to: url)
        }
        done(.success(url.path))
      } catch {
        try? FileManager.default.removeItem(at: tmp)
        // Losing a move race to an identical export is still a success.
        FileManager.default.fileExists(atPath: url.path) ? done(.success(url.path)) : done(.failure(error))
      }
    }
  }

  func clear() {
    try? FileManager.default.removeItem(at: dir)
  }

  func saveImage(data: Data, filename: String, done: @escaping (Result<String?, Error>) -> Void) {
    var placeholder: PHObjectPlaceholder?
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.forAsset()
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = filename
      request.addResource(with: .photo, data: data, options: options)
      placeholder = request.placeholderForCreatedAsset
    }) { ok, error in
      if let error { return done(.failure(error)) }
      done(.success(ok ? placeholder?.localIdentifier : nil))
    }
  }

  func saveVideo(path: String, filename: String?, done: @escaping (Result<String?, Error>) -> Void) {
    var placeholder: PHObjectPlaceholder?
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.forAsset()
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = filename ?? (path as NSString).lastPathComponent
      request.addResource(with: .video, fileURL: URL(fileURLWithPath: path), options: options)
      placeholder = request.placeholderForCreatedAsset
    }) { ok, error in
      if let error { return done(.failure(error)) }
      done(.success(ok ? placeholder?.localIdentifier : nil))
    }
  }

  func delete(_ assets: [PHAsset], done: @escaping ([String]) -> Void) {
    guard !assets.isEmpty else { return done([]) }
    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets(assets as NSArray)
    }) { ok, _ in
      done(ok ? assets.map(\.localIdentifier) : [])
    }
  }
}
