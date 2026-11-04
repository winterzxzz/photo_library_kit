import 'dart:io';
import 'dart:typed_data';

import 'image/thumbnail_scheduler.dart';
import 'platform/photo_library_platform.dart';
import 'types/library_change.dart';
import 'types/media_album.dart';
import 'types/media_asset.dart';
import 'types/media_filter.dart';
import 'types/permission.dart';
import 'types/thumbnail_options.dart';

/// Entry point for reading and writing the device photo library.
///
/// ```dart
/// final state = await PhotoLibrary.requestPermission();
/// if (!state.hasAccess) return;
/// final albums = await PhotoLibrary.getAlbums();
/// final firstPage = await albums.first.getAssets(end: 60);
/// ```
abstract final class PhotoLibrary {
  static PhotoLibraryPlatform get _p => PhotoLibraryPlatform.instance;

  /// Current authorization without prompting the user.
  static Future<PermissionState> getPermissionState([
    PermissionRequest request = const PermissionRequest(),
  ]) => _p.getPermissionState(request);

  /// Prompts the user if needed and returns the resulting state.
  static Future<PermissionState> requestPermission([
    PermissionRequest request = const PermissionRequest(),
  ]) => _p.requestPermission(request);

  /// Lets a user with [PermissionState.limited] change the selected assets.
  static Future<void> presentLimitedPicker() => _p.presentLimitedPicker();

  /// Opens the app's system settings page.
  static Future<bool> openSettings() => _p.openSettings();

  /// Albums that contain assets matching [filter]. The virtual "all" album is
  /// always first; the others are sorted by asset count.
  static Future<List<MediaAlbum>> getAlbums({
    MediaFilter filter = MediaFilter.all,
    bool includeEmpty = false,
  }) => _p.getAlbums(filter, includeEmpty: includeEmpty);

  /// Number of assets in [albumId] matching [filter].
  static Future<int> getAssetCount({
    String albumId = MediaAlbum.allId,
    MediaFilter filter = MediaFilter.all,
  }) => _p.getAssetCount(albumId, filter);

  /// Assets in `[start, end)` for [albumId]. Prefer `AssetPagedList` for
  /// scrolling UIs; it pages, caches and de-duplicates for you.
  static Future<List<MediaAsset>> getAssets({
    String albumId = MediaAlbum.allId,
    MediaFilter filter = MediaFilter.all,
    int start = 0,
    required int end,
  }) {
    RangeError.checkNotNegative(start, 'start');
    return _p.getAssets(albumId, filter, start: start, end: end);
  }

  /// Looks up a single asset. Returns `null` if it no longer exists.
  static Future<MediaAsset?> getAsset(String id) => _p.getAsset(id);

  /// Encoded thumbnail bytes. For widgets use `MediaThumbnailProvider`,
  /// which adds decoding, caching, request throttling and cancellation.
  static Future<Uint8List?> getThumbnailBytes(
    MediaAsset asset,
    ThumbnailOptions options,
  ) => _p.getThumbnail(
    asset.id,
    options,
    requestId: ThumbnailScheduler.nextRequestId(),
  );

  /// Pre-renders thumbnails natively so they appear instantly later.
  /// A no-op on platforms without a native thumbnail cache.
  static Future<void> startCaching(
    List<MediaAsset> assets,
    ThumbnailOptions options,
  ) => _p.startCaching([for (final a in assets) a.id], options);

  static Future<void> stopCaching(
    List<MediaAsset> assets,
    ThumbnailOptions options,
  ) => _p.stopCaching([for (final a in assets) a.id], options);

  /// A readable file for [asset].
  ///
  /// With [original] `false` (default) you get the display version: on iOS
  /// edits are applied and HEIC stays HEIC. With [original] `true` you get the
  /// unedited original resource. On iOS the file is exported into the app
  /// cache once and reused; call [clearFileCache] to reclaim space.
  static Future<File?> getFile(
    MediaAsset asset, {
    bool original = false,
  }) async {
    final path = await _p.getFilePath(asset.id, original: original);
    return path == null ? null : File(path);
  }

  /// Saves encoded image [bytes] (JPEG, PNG, HEIC, GIF...) to the library.
  static Future<MediaAsset?> saveImage(
    Uint8List bytes, {
    required String filename,
  }) => _p.saveImage(bytes, filename: filename);

  /// Saves the video at [path] to the library.
  static Future<MediaAsset?> saveVideo(String path, {String? filename}) =>
      _p.saveVideo(path, filename: filename);

  /// Deletes [assets]. The system may ask the user to confirm; the returned
  /// ids are the ones that were actually deleted.
  static Future<List<String>> deleteAssets(List<MediaAsset> assets) =>
      _p.deleteAssets([for (final a in assets) a.id]);

  /// Removes files exported into the app cache by [getFile].
  static Future<void> clearFileCache() => _p.clearFileCache();

  /// Debounced library change notifications. The native observer only runs
  /// while this stream has listeners.
  static Stream<LibraryChange> get changes => _p.changes;
}

/// Convenience accessors so call sites read naturally.
extension MediaAlbumQueries on MediaAlbum {
  Future<List<MediaAsset>> getAssets({
    MediaFilter filter = MediaFilter.all,
    int start = 0,
    required int end,
  }) => PhotoLibrary.getAssets(
    albumId: id,
    filter: filter,
    start: start,
    end: end,
  );
}

extension MediaAssetFiles on MediaAsset {
  Future<File?> file({bool original = false}) =>
      PhotoLibrary.getFile(this, original: original);

  Future<Uint8List?> thumbnailBytes(ThumbnailOptions options) =>
      PhotoLibrary.getThumbnailBytes(this, options);
}
