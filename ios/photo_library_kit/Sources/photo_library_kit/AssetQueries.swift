import Foundation
import Photos
import UniformTypeIdentifiers

/// Native mirror of the Dart `MediaFilter`.
struct MediaFilter: Hashable {
  var image = true
  var video = true
  var sort = 0
  var after: Int64?
  var before: Int64?
  var minDuration: Int64?
  var maxDuration: Int64?

  init(_ raw: Any?) {
    guard let m = raw as? [String: Any] else { return }
    image = m["image"] as? Bool ?? true
    video = m["video"] as? Bool ?? true
    sort = m["sort"] as? Int ?? 0
    after = (m["after"] as? NSNumber)?.int64Value
    before = (m["before"] as? NSNumber)?.int64Value
    minDuration = (m["minDur"] as? NSNumber)?.int64Value
    maxDuration = (m["maxDur"] as? NSNumber)?.int64Value
    // `gif` cannot be expressed as a PhotoKit predicate; it is ignored on iOS.
  }

  func fetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    var preds: [NSPredicate] = []
    var videoPred = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
    var durationPreds: [NSPredicate] = [videoPred]
    if let min = minDuration { durationPreds.append(NSPredicate(format: "duration >= %f", Double(min) / 1000)) }
    if let max = maxDuration { durationPreds.append(NSPredicate(format: "duration <= %f", Double(max) / 1000)) }
    videoPred = NSCompoundPredicate(andPredicateWithSubpredicates: durationPreds)
    let imagePred = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    switch (image, video) {
    case (true, true): preds.append(NSCompoundPredicate(orPredicateWithSubpredicates: [imagePred, videoPred]))
    case (true, false): preds.append(imagePred)
    case (false, true): preds.append(videoPred)
    case (false, false): preds.append(NSPredicate(value: false))
    }
    if let after { preds.append(NSPredicate(format: "creationDate >= %@", Date(ms: after) as NSDate)) }
    if let before { preds.append(NSPredicate(format: "creationDate <= %@", Date(ms: before) as NSDate)) }
    options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: preds)
    switch sort {
    case 1: options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    case 2: options.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
    default: options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    }
    return options
  }
}

extension Date {
  init(ms: Int64) { self.init(timeIntervalSince1970: TimeInterval(ms) / 1000) }
  var ms: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
}

/// PhotoKit queries. Fetch results are lazy and cached per (album, filter) so
/// paging through them is O(page) instead of re-running the fetch each time.
/// All methods must run on `queue`.
final class AssetQueries {
  static let allId = "__all__"

  let queue = DispatchQueue(label: "photo_library_kit.query", qos: .userInitiated)

  private struct Key: Hashable { let album: String; let filter: MediaFilter }
  private var results: [Key: PHFetchResult<PHAsset>] = [:]
  private var resultOrder: [Key] = []
  private let maxResults = 8

  /// PHAsset lookups by id, filled while paging so thumbnails skip a fetch.
  let assetCache: NSCache<NSString, PHAsset> = {
    let c = NSCache<NSString, PHAsset>()
    c.countLimit = 4000
    return c
  }()

  func fetchResult(album: String, filter: MediaFilter) -> PHFetchResult<PHAsset> {
    let key = Key(album: album, filter: filter)
    if let cached = results[key] { return cached }
    let options = filter.fetchOptions()
    let result: PHFetchResult<PHAsset>
    if album == Self.allId {
      result = PHAsset.fetchAssets(with: options)
    } else if let collection = PHAssetCollection.fetchAssetCollections(
      withLocalIdentifiers: [album], options: nil
    ).firstObject {
      result = PHAsset.fetchAssets(in: collection, options: options)
    } else {
      result = PHFetchResult<PHAsset>()
    }
    results[key] = result
    resultOrder.append(key)
    if resultOrder.count > maxResults { results.removeValue(forKey: resultOrder.removeFirst()) }
    return result
  }

  /// Applies a library change to cached results and collects changed ids.
  func apply(_ change: PHChange, inserted: inout Set<String>, removed: inout Set<String>, updated: inout Set<String>) {
    for (key, result) in results {
      guard let details = change.changeDetails(for: result) else { continue }
      details.insertedObjects.forEach { inserted.insert($0.localIdentifier) }
      details.removedObjects.forEach { removed.insert($0.localIdentifier); assetCache.removeObject(forKey: $0.localIdentifier as NSString) }
      details.changedObjects.forEach { updated.insert($0.localIdentifier); assetCache.removeObject(forKey: $0.localIdentifier as NSString) }
      results[key] = details.fetchResultAfterChanges
    }
  }

  func invalidate() {
    results.removeAll()
    resultOrder.removeAll()
  }

  func albums(filter: MediaFilter, includeEmpty: Bool) -> [[String: Any?]] {
    var out: [[String: Any?]] = []
    let all = fetchResult(album: Self.allId, filter: filter)
    if all.count > 0 || includeEmpty {
      out.append(["id": Self.allId, "name": "Recents", "count": all.count, "kind": 0,
                  "cover": all.firstObject?.localIdentifier])
    }
    let options = filter.fetchOptions()
    var rest: [[String: Any?]] = []
    func add(_ collection: PHAssetCollection, kind: Int) {
      let assets = PHAsset.fetchAssets(in: collection, options: options)
      guard assets.count > 0 || includeEmpty else { return }
      rest.append(["id": collection.localIdentifier, "name": collection.localizedTitle ?? "",
                   "count": assets.count, "kind": kind, "cover": assets.firstObject?.localIdentifier])
    }
    let smartTypes: [PHAssetCollectionSubtype] = [
      .smartAlbumFavorites, .smartAlbumVideos, .smartAlbumSelfPortraits, .smartAlbumLivePhotos,
      .smartAlbumPanoramas, .smartAlbumScreenshots, .smartAlbumBursts, .smartAlbumSlomoVideos,
      .smartAlbumAnimated, .smartAlbumRAW,
    ]
    for subtype in smartTypes {
      PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
        .enumerateObjects { c, _, _ in add(c, kind: 1) }
    }
    PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
      .enumerateObjects { c, _, _ in add(c, kind: 2) }
    rest.sort { ($0["count"] as? Int ?? 0) > ($1["count"] as? Int ?? 0) }
    return out + rest
  }

  func count(album: String, filter: MediaFilter) -> Int {
    fetchResult(album: album, filter: filter).count
  }

  func assets(album: String, filter: MediaFilter, start: Int, end: Int) -> [[String: Any?]] {
    let result = fetchResult(album: album, filter: filter)
    let upper = min(end, result.count)
    guard start < upper else { return [] }
    let page = result.objects(at: IndexSet(integersIn: start..<upper))
    return page.map { asset in
      assetCache.setObject(asset, forKey: asset.localIdentifier as NSString)
      return Self.serialize(asset)
    }
  }

  func asset(id: String) -> PHAsset? {
    if let cached = assetCache.object(forKey: id as NSString) { return cached }
    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
    assetCache.setObject(asset, forKey: id as NSString)
    return asset
  }

  func assets(ids: [String]) -> [PHAsset] {
    var found: [PHAsset] = []
    var missing: [String] = []
    for id in ids {
      if let a = assetCache.object(forKey: id as NSString) { found.append(a) } else { missing.append(id) }
    }
    if !missing.isEmpty {
      PHAsset.fetchAssets(withLocalIdentifiers: missing, options: nil).enumerateObjects { a, _, _ in found.append(a) }
    }
    return found
  }

  /// Full detail for a single asset, including the file name and MIME type,
  /// which require a (slower) resource lookup and are skipped when paging.
  func detail(id: String) -> [String: Any?]? {
    guard let asset = asset(id: id) else { return nil }
    var map = Self.serialize(asset)
    if let resource = PHAssetResource.assetResources(for: asset).first {
      map["title"] = resource.originalFilename
      map["mime"] = UTType(resource.uniformTypeIdentifier)?.preferredMIMEType
    }
    return map
  }

  static func serialize(_ a: PHAsset) -> [String: Any?] {
    [
      "id": a.localIdentifier,
      "type": a.mediaType == .video ? 1 : 0,
      "w": a.pixelWidth,
      "h": a.pixelHeight,
      "dur": Int64((a.duration * 1000).rounded()),
      "ct": (a.creationDate ?? Date(timeIntervalSince1970: 0)).ms,
      "mt": (a.modificationDate ?? a.creationDate ?? Date(timeIntervalSince1970: 0)).ms,
      "ori": 0,
      "fav": a.isFavorite,
      "live": a.mediaSubtypes.contains(.photoLive),
      "mime": a.playbackStyle == .imageAnimated ? "image/gif" : nil,
    ]
  }
}
