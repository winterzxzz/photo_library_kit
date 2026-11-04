import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../types/library_change.dart';
import '../types/media_album.dart';
import '../types/media_asset.dart';
import '../types/media_filter.dart';
import '../types/permission.dart';
import '../types/photo_library_exception.dart';
import '../types/thumbnail_options.dart';
import 'photo_library_platform.dart';

/// [PhotoLibraryPlatform] backed by a [MethodChannel] and an [EventChannel].
class MethodChannelPhotoLibrary extends PhotoLibraryPlatform {
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('photo_library_kit');

  @visibleForTesting
  static const EventChannel changeChannel = EventChannel(
    'photo_library_kit/changes',
  );

  Stream<LibraryChange>? _changes;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw PhotoLibraryException.fromPlatform(e);
    }
  }

  @override
  Future<PermissionState> getPermissionState(PermissionRequest request) async =>
      PermissionState.fromWire(
        await _invoke<int>('getPermissionState', request.toWire()),
      );

  @override
  Future<PermissionState> requestPermission(PermissionRequest request) async =>
      PermissionState.fromWire(
        await _invoke<int>('requestPermission', request.toWire()),
      );

  @override
  Future<void> presentLimitedPicker() => _invoke<void>('presentLimitedPicker');

  @override
  Future<bool> openSettings() async =>
      (await _invoke<bool>('openSettings')) ?? false;

  @override
  Future<List<MediaAlbum>> getAlbums(
    MediaFilter filter, {
    bool includeEmpty = false,
  }) async {
    final raw = await _invoke<List<Object?>>('getAlbums', {
      'filter': filter.toWire(),
      'includeEmpty': includeEmpty,
    });
    return [
      for (final item in raw ?? const [])
        MediaAlbum.fromWire(item! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<int> getAssetCount(String albumId, MediaFilter filter) async =>
      (await _invoke<int>('getAssetCount', {
        'album': albumId,
        'filter': filter.toWire(),
      })) ??
      0;

  @override
  Future<List<MediaAsset>> getAssets(
    String albumId,
    MediaFilter filter, {
    required int start,
    required int end,
  }) async {
    if (end <= start) return const [];
    final raw = await _invoke<List<Object?>>('getAssets', {
      'album': albumId,
      'filter': filter.toWire(),
      'start': start,
      'end': end,
    });
    return [
      for (final item in raw ?? const [])
        MediaAsset.fromWire(item! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<MediaAsset?> getAsset(String id) async {
    final raw = await _invoke<Map<Object?, Object?>>('getAsset', {'id': id});
    return raw == null ? null : MediaAsset.fromWire(raw);
  }

  @override
  Future<Uint8List?> getThumbnail(
    MediaAsset asset,
    ThumbnailOptions options, {
    required int requestId,
  }) =>
      _invoke<Uint8List>('getThumbnail', {
        'id': asset.id,
        'type': asset.type.index,
        'rid': requestId,
        ...options.toWire(),
      });

  @override
  Future<void> cancelThumbnail(int requestId) =>
      _invoke<void>('cancelThumbnail', {'rid': requestId});

  @override
  Future<void> startCaching(List<String> ids, ThumbnailOptions options) =>
      _invoke<void>('startCaching', {'ids': ids, ...options.toWire()});

  @override
  Future<void> stopCaching(List<String> ids, ThumbnailOptions options) =>
      _invoke<void>('stopCaching', {'ids': ids, ...options.toWire()});

  @override
  Future<String?> getFilePath(String id, {required bool original}) =>
      _invoke<String>('getFilePath', {'id': id, 'original': original});

  @override
  Future<MediaAsset?> saveImage(
    Uint8List bytes, {
    required String filename,
  }) async {
    final raw = await _invoke<Map<Object?, Object?>>('saveImage', {
      'bytes': bytes,
      'filename': filename,
    });
    return raw == null ? null : MediaAsset.fromWire(raw);
  }

  @override
  Future<MediaAsset?> saveVideo(String path, {String? filename}) async {
    final raw = await _invoke<Map<Object?, Object?>>('saveVideo', {
      'path': path,
      'filename': filename,
    });
    return raw == null ? null : MediaAsset.fromWire(raw);
  }

  @override
  Future<List<String>> deleteAssets(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final raw = await _invoke<List<Object?>>('deleteAssets', {'ids': ids});
    return raw?.cast<String>() ?? const [];
  }

  @override
  Future<void> clearFileCache() => _invoke<void>('clearFileCache');

  @override
  // Broadcast: the native observer runs only while at least one listener is
  // attached, and is torn down when the last one cancels.
  Stream<LibraryChange> get changes => _changes ??=
      changeChannel.receiveBroadcastStream().map(LibraryChange.fromWire);
}
