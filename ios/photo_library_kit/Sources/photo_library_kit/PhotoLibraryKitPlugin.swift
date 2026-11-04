import Flutter
import Photos
import PhotosUI
import UIKit

public class PhotoLibraryKitPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, PHPhotoLibraryChangeObserver {
  private let queries = AssetQueries()
  private let thumbnails = ThumbnailManager()
  private let exporter = FileExporter()

  private var sink: FlutterEventSink?
  private var observing = false
  private var pendingInserted = Set<String>()
  private var pendingRemoved = Set<String>()
  private var pendingUpdated = Set<String>()
  private var flushScheduled = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PhotoLibraryKitPlugin()
    let channel = FlutterMethodChannel(name: "photo_library_kit", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(name: "photo_library_kit/changes", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let reply: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    let fail: (String, String?) -> Void = { code, message in
      DispatchQueue.main.async { result(FlutterError(code: code, message: message, details: nil)) }
    }

    switch call.method {
    case "getPermissionState":
      result(Self.wire(PHPhotoLibrary.authorizationStatus(for: Self.level(args))))
    case "requestPermission":
      PHPhotoLibrary.requestAuthorization(for: Self.level(args)) { reply(Self.wire($0)) }
    case "presentLimitedPicker":
      guard let vc = Self.topViewController() else { return fail("no_activity", "No view controller to present from") }
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc) { _ in reply(nil) }
    case "openSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return result(false) }
      UIApplication.shared.open(url) { result($0) }

    case "getAlbums":
      onQueue(reply) { $0.albums(filter: MediaFilter(args["filter"]), includeEmpty: args["includeEmpty"] as? Bool ?? false) }
    case "getAssetCount":
      onQueue(reply) { $0.count(album: args["album"] as? String ?? AssetQueries.allId, filter: MediaFilter(args["filter"])) }
    case "getAssets":
      onQueue(reply) {
        $0.assets(album: args["album"] as? String ?? AssetQueries.allId, filter: MediaFilter(args["filter"]),
                  start: args["start"] as? Int ?? 0, end: args["end"] as? Int ?? 0)
      }
    case "getAsset":
      onQueue(reply) { $0.detail(id: args["id"] as? String ?? "") }

    case "getThumbnail":
      let rid = args["rid"] as? Int ?? 0
      let req = ThumbnailRequest(args)
      let id = args["id"] as? String ?? ""
      queries.queue.async { [queries, thumbnails] in
        guard let asset = queries.asset(id: id) else { return reply(nil) }
        thumbnails.request(asset: asset, rid: rid, req: req) { data in
          reply(data.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    case "cancelThumbnail":
      thumbnails.cancel(rid: args["rid"] as? Int ?? 0)
      result(nil)
    case "startCaching", "stopCaching":
      let ids = args["ids"] as? [String] ?? []
      let req = ThumbnailRequest(args)
      let start = call.method == "startCaching"
      queries.queue.async { [queries, thumbnails] in
        let assets = queries.assets(ids: ids)
        if start { thumbnails.startCaching(assets, req) } else { thumbnails.stopCaching(assets, req) }
        reply(nil)
      }

    case "getFilePath":
      let id = args["id"] as? String ?? ""
      let original = args["original"] as? Bool ?? false
      queries.queue.async { [queries, exporter] in
        guard let asset = queries.asset(id: id) else { return reply(nil) }
        exporter.export(asset, original: original) { r in
          switch r {
          case .success(let path): reply(path)
          case .failure(let e): fail("io_error", e.localizedDescription)
          }
        }
      }
    case "saveImage":
      guard let data = (args["bytes"] as? FlutterStandardTypedData)?.data else { return fail("invalid_args", "bytes") }
      exporter.saveImage(data: data, filename: args["filename"] as? String ?? "image.jpg") { [weak self] r in
        self?.replySaved(r, reply: reply, fail: fail)
      }
    case "saveVideo":
      guard let path = args["path"] as? String else { return fail("invalid_args", "path") }
      exporter.saveVideo(path: path, filename: args["filename"] as? String) { [weak self] r in
        self?.replySaved(r, reply: reply, fail: fail)
      }
    case "deleteAssets":
      let ids = args["ids"] as? [String] ?? []
      queries.queue.async { [queries, exporter] in
        exporter.delete(queries.assets(ids: ids)) { reply($0) }
      }
    case "clearFileCache":
      queries.queue.async { [exporter] in exporter.clear(); reply(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func onQueue(_ reply: @escaping (Any?) -> Void, _ work: @escaping (AssetQueries) -> Any?) {
    queries.queue.async { [queries] in reply(work(queries)) }
  }

  private func replySaved(_ r: Result<String?, Error>, reply: @escaping (Any?) -> Void, fail: @escaping (String, String?) -> Void) {
    switch r {
    case .failure(let e): fail("io_error", e.localizedDescription)
    case .success(let id):
      guard let id else { return reply(nil) }
      queries.queue.async { [queries] in reply(queries.detail(id: id)) }
    }
  }

  // MARK: - Permissions

  private static func level(_ args: [String: Any]) -> PHAccessLevel {
    (args["addOnly"] as? Bool ?? false) ? .addOnly : .readWrite
  }

  /// Order matches the Dart `PermissionState` enum.
  private static func wire(_ s: PHAuthorizationStatus) -> Int {
    switch s {
    case .notDetermined: return 0
    case .restricted: return 1
    case .denied: return 2
    case .authorized: return 3
    case .limited: return 4
    @unknown default: return 2
    }
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
    var vc = window?.rootViewController
    while let presented = vc?.presentedViewController { vc = presented }
    return vc
  }

  // MARK: - Change stream

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if !observing {
      PHPhotoLibrary.shared().register(self)
      observing = true
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    if observing {
      PHPhotoLibrary.shared().unregisterChangeObserver(self)
      observing = false
    }
    return nil
  }

  public func photoLibraryDidChange(_ changeInstance: PHChange) {
    queries.queue.async { [weak self] in
      guard let self else { return }
      var inserted = Set<String>(), removed = Set<String>(), updated = Set<String>()
      self.queries.apply(changeInstance, inserted: &inserted, removed: &removed, updated: &updated)
      // Album membership and counts may change in ways cached results don't
      // cover (new albums, limited selection), so drop them all.
      self.queries.invalidate()
      DispatchQueue.main.async {
        self.pendingInserted.formUnion(inserted)
        self.pendingRemoved.formUnion(removed)
        self.pendingUpdated.formUnion(updated)
        self.scheduleFlush()
      }
    }
  }

  private func scheduleFlush() {
    guard !flushScheduled else { return }
    flushScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self else { return }
      self.flushScheduled = false
      self.pendingUpdated.subtract(self.pendingInserted)
      self.sink?([
        "inserted": Array(self.pendingInserted),
        "removed": Array(self.pendingRemoved),
        "updated": Array(self.pendingUpdated),
      ])
      self.pendingInserted.removeAll()
      self.pendingRemoved.removeAll()
      self.pendingUpdated.removeAll()
    }
  }
}
