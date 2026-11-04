import 'package:flutter/foundation.dart';

/// Where an album comes from.
enum AlbumKind {
  /// The virtual "all media" album (Recents / Camera Roll).
  all,

  /// A system album such as Favorites, Screenshots or Videos (iOS smart album).
  system,

  /// A user-created album (iOS) or a storage folder (Android bucket).
  user;

  static AlbumKind fromWire(Object? value) => switch (value) {
        0 => AlbumKind.all,
        1 => AlbumKind.system,
        _ => AlbumKind.user,
      };
}

/// An album (iOS asset collection) or folder (Android bucket).
///
/// [count] reflects the filter used when the album list was fetched.
@immutable
class MediaAlbum {
  const MediaAlbum({
    required this.id,
    required this.name,
    required this.count,
    required this.kind,
    this.coverId,
  });

  /// Identifier of the virtual album that contains every asset.
  static const String allId = '__all__';

  final String id;
  final String name;

  /// Number of assets matching the filter at fetch time.
  final int count;

  final AlbumKind kind;

  /// Id of the asset to use as a cover (newest first), if any.
  final String? coverId;

  bool get isAll => kind == AlbumKind.all;

  factory MediaAlbum.fromWire(Map<Object?, Object?> map) => MediaAlbum(
        id: map['id']! as String,
        name: (map['name'] as String?) ?? '',
        count: (map['count'] as int?) ?? 0,
        kind: AlbumKind.fromWire(map['kind']),
        coverId: map['cover'] as String?,
      );

  MediaAlbum copyWith({int? count, String? coverId}) => MediaAlbum(
        id: id,
        name: name,
        count: count ?? this.count,
        kind: kind,
        coverId: coverId ?? this.coverId,
      );

  @override
  bool operator ==(Object other) =>
      other is MediaAlbum &&
      other.id == id &&
      other.count == count &&
      other.coverId == coverId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, count, coverId, name);

  @override
  String toString() => 'MediaAlbum($id, "$name", $count)';
}
