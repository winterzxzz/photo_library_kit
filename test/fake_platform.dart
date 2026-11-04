import 'dart:async';
import 'dart:typed_data';

import 'package:photo_library_kit/photo_library_kit.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

MediaAsset fakeAsset(int i) => MediaAsset(
  id: 'a$i',
  type: MediaType.image,
  width: 100,
  height: 100,
  createdAt: DateTime(2024),
  modifiedAt: DateTime(2024),
);

/// In-memory platform. Thumbnail requests stay pending until [completeThumb].
class FakePlatform extends PhotoLibraryPlatform
    with MockPlatformInterfaceMixin {
  FakePlatform({this.total = 0});

  int total;
  final List<(int, int)> assetCalls = [];
  final Map<int, Completer<Uint8List?>> thumbs = {};
  final List<String> thumbOrder = [];
  final List<int> cancelled = [];
  final StreamController<LibraryChange> changeController =
      StreamController.broadcast();

  void completeThumb(int requestId, [Uint8List? bytes]) =>
      thumbs.remove(requestId)!.complete(bytes ?? Uint8List(1));

  @override
  Future<int> getAssetCount(String albumId, MediaFilter filter) async => total;

  @override
  Future<List<MediaAsset>> getAssets(
    String albumId,
    MediaFilter filter, {
    required int start,
    required int end,
  }) async {
    assetCalls.add((start, end));
    return [for (var i = start; i < end && i < total; i++) fakeAsset(i)];
  }

  @override
  Future<Uint8List?> getThumbnail(
    MediaAsset asset,
    ThumbnailOptions options, {
    required int requestId,
  }) {
    thumbOrder.add(asset.id);
    return (thumbs[requestId] = Completer()).future;
  }

  @override
  Future<void> cancelThumbnail(int requestId) async {
    cancelled.add(requestId);
    thumbs.remove(requestId)?.complete(null);
  }

  @override
  Stream<LibraryChange> get changes => changeController.stream;

  @override
  Future<List<MediaAlbum>> getAlbums(
    MediaFilter filter, {
    bool includeEmpty = false,
  }) async => [
    MediaAlbum(
      id: MediaAlbum.allId,
      name: 'Recent',
      count: total,
      kind: AlbumKind.all,
    ),
  ];

  @override
  Future<PermissionState> getPermissionState(PermissionRequest r) async =>
      PermissionState.authorized;

  @override
  Future<PermissionState> requestPermission(PermissionRequest r) async =>
      PermissionState.authorized;

  @override
  Future<MediaAsset?> getAsset(String id) async => null;

  @override
  Future<void> presentLimitedPicker() async {}

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<void> startCaching(List<String> ids, ThumbnailOptions o) async {}

  @override
  Future<void> stopCaching(List<String> ids, ThumbnailOptions o) async {}

  @override
  Future<String?> getFilePath(String id, {required bool original}) async =>
      null;

  @override
  Future<MediaAsset?> saveImage(
    Uint8List bytes, {
    required String filename,
  }) async => null;

  @override
  Future<MediaAsset?> saveVideo(String path, {String? filename}) async => null;

  @override
  Future<List<String>> deleteAssets(List<String> ids) async => ids;

  @override
  Future<void> clearFileCache() async {}
}
