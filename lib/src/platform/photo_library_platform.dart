import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../types/library_change.dart';
import '../types/media_album.dart';
import '../types/media_asset.dart';
import '../types/media_filter.dart';
import '../types/permission.dart';
import '../types/thumbnail_options.dart';
import 'method_channel_photo_library.dart';

/// Platform contract. Swap [instance] in tests with a fake implementation.
abstract class PhotoLibraryPlatform extends PlatformInterface {
  PhotoLibraryPlatform() : super(token: _token);

  static final Object _token = Object();

  static PhotoLibraryPlatform _instance = MethodChannelPhotoLibrary();

  static PhotoLibraryPlatform get instance => _instance;

  static set instance(PhotoLibraryPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<PermissionState> getPermissionState(PermissionRequest request);

  Future<PermissionState> requestPermission(PermissionRequest request);

  /// iOS 14+: show the system sheet to change the limited selection.
  /// Android 14+: re-launches the permission prompt.
  Future<void> presentLimitedPicker();

  Future<bool> openSettings();

  Future<List<MediaAlbum>> getAlbums(MediaFilter filter, {bool includeEmpty});

  Future<int> getAssetCount(String albumId, MediaFilter filter);

  /// Returns assets in `[start, end)` of [albumId] under [filter].
  Future<List<MediaAsset>> getAssets(
    String albumId,
    MediaFilter filter, {
    required int start,
    required int end,
  });

  Future<MediaAsset?> getAsset(String id);

  /// Encoded thumbnail bytes or `null` if the asset vanished or was cancelled.
  /// [requestId] lets [cancelThumbnail] abort the native work.
  Future<Uint8List?> getThumbnail(
    String id,
    ThumbnailOptions options, {
    required int requestId,
  });

  Future<void> cancelThumbnail(int requestId);

  /// Warms the native thumbnail cache (iOS `PHCachingImageManager`).
  Future<void> startCaching(List<String> ids, ThumbnailOptions options);

  Future<void> stopCaching(List<String> ids, ThumbnailOptions options);

  /// Absolute path of a readable file for the asset. On iOS the file is
  /// exported to the app cache when needed.
  Future<String?> getFilePath(String id, {required bool original});

  Future<MediaAsset?> saveImage(Uint8List bytes, {required String filename});

  Future<MediaAsset?> saveVideo(String path, {String? filename});

  /// Returns the ids that were actually deleted (the user may decline).
  Future<List<String>> deleteAssets(List<String> ids);

  /// Deletes files exported by [getFilePath].
  Future<void> clearFileCache();

  Stream<LibraryChange> get changes;
}
