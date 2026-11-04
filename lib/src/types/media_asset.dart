import 'package:flutter/foundation.dart';

/// Kind of media an asset holds.
enum MediaType {
  image,
  video;

  static MediaType fromWire(Object? value) =>
      value == 1 ? MediaType.video : MediaType.image;
}

/// An immutable snapshot of one photo or video in the device library.
///
/// Assets are cheap value objects: they hold metadata only. Pixels and files
/// are loaded lazily via `MediaThumbnailProvider`, `MediaImageProvider` or
/// [PhotoLibrary.getFile].
///
/// Two assets are equal when they share the same [id] and [modifiedAt], so an
/// edited photo produces a new cache key and never shows a stale thumbnail.
@immutable
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.type,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.modifiedAt,
    this.duration = Duration.zero,
    this.orientation = 0,
    this.title,
    this.mimeType,
    this.isFavorite = false,
    this.isLivePhoto = false,
  });

  /// Platform identifier (`PHAsset.localIdentifier` on iOS, MediaStore `_ID`
  /// on Android). Stable across app launches.
  final String id;

  final MediaType type;

  /// Pixel width as displayed (orientation already applied).
  final int width;

  /// Pixel height as displayed (orientation already applied).
  final int height;

  final DateTime createdAt;
  final DateTime modifiedAt;

  /// Video duration, [Duration.zero] for images.
  final Duration duration;

  /// Clockwise rotation in degrees stored in the file (0, 90, 180, 270).
  /// [width] and [height] already account for it.
  final int orientation;

  /// File name, when the platform exposes it cheaply.
  final String? title;

  final String? mimeType;
  final bool isFavorite;

  /// iOS Live Photo.
  final bool isLivePhoto;

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;

  /// `width / height`, or 1 when dimensions are unknown.
  double get aspectRatio => width > 0 && height > 0 ? width / height : 1;

  /// Whether this is an animated GIF.
  bool get isGif => mimeType == 'image/gif';

  factory MediaAsset.fromWire(Map<Object?, Object?> map) {
    return MediaAsset(
      id: map['id']! as String,
      type: MediaType.fromWire(map['type']),
      width: (map['w'] as int?) ?? 0,
      height: (map['h'] as int?) ?? 0,
      duration: Duration(milliseconds: (map['dur'] as int?) ?? 0),
      createdAt: _date(map['ct']),
      modifiedAt: _date(map['mt']),
      orientation: (map['ori'] as int?) ?? 0,
      title: map['title'] as String?,
      mimeType: map['mime'] as String?,
      isFavorite: (map['fav'] as bool?) ?? false,
      isLivePhoto: (map['live'] as bool?) ?? false,
    );
  }

  static DateTime _date(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as int?) ?? 0);

  @override
  bool operator ==(Object other) =>
      other is MediaAsset && other.id == id && other.modifiedAt == modifiedAt;

  @override
  int get hashCode => Object.hash(id, modifiedAt);

  @override
  String toString() => 'MediaAsset($id, ${type.name}, ${width}x$height'
      '${isVideo ? ', $duration' : ''})';
}
