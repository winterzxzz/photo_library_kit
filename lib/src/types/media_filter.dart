import 'package:flutter/foundation.dart';

import 'media_asset.dart';

/// Sort order for asset queries.
enum MediaSort {
  /// Newest creation date first (gallery default).
  newest,

  /// Oldest creation date first.
  oldest,

  /// Most recently modified first.
  recentlyModified,
}

/// Describes which assets a query returns. Filtering happens natively so only
/// matching rows ever cross the platform channel.
@immutable
class MediaFilter {
  const MediaFilter({
    this.types = const {MediaType.image, MediaType.video},
    this.sort = MediaSort.newest,
    this.createdAfter,
    this.createdBefore,
    this.minVideoDuration,
    this.maxVideoDuration,
    this.includeGifs = true,
  });

  /// Images and videos, newest first.
  static const MediaFilter all = MediaFilter();

  /// Only images.
  static const MediaFilter images = MediaFilter(types: {MediaType.image});

  /// Only videos.
  static const MediaFilter videos = MediaFilter(types: {MediaType.video});

  /// Media kinds to include. An empty set matches nothing.
  final Set<MediaType> types;
  final MediaSort sort;
  final DateTime? createdAfter;
  final DateTime? createdBefore;

  /// Applies to videos only.
  final Duration? minVideoDuration;

  /// Applies to videos only.
  final Duration? maxVideoDuration;

  /// Whether animated GIFs are returned with images.
  final bool includeGifs;

  MediaFilter copyWith({
    Set<MediaType>? types,
    MediaSort? sort,
    DateTime? createdAfter,
    DateTime? createdBefore,
    Duration? minVideoDuration,
    Duration? maxVideoDuration,
    bool? includeGifs,
  }) => MediaFilter(
    types: types ?? this.types,
    sort: sort ?? this.sort,
    createdAfter: createdAfter ?? this.createdAfter,
    createdBefore: createdBefore ?? this.createdBefore,
    minVideoDuration: minVideoDuration ?? this.minVideoDuration,
    maxVideoDuration: maxVideoDuration ?? this.maxVideoDuration,
    includeGifs: includeGifs ?? this.includeGifs,
  );

  Map<String, Object?> toWire() => {
    'image': types.contains(MediaType.image),
    'video': types.contains(MediaType.video),
    'sort': sort.index,
    'after': createdAfter?.millisecondsSinceEpoch,
    'before': createdBefore?.millisecondsSinceEpoch,
    'minDur': minVideoDuration?.inMilliseconds,
    'maxDur': maxVideoDuration?.inMilliseconds,
    'gif': includeGifs,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaFilter &&
      setEquals(other.types, types) &&
      other.sort == sort &&
      other.createdAfter == createdAfter &&
      other.createdBefore == createdBefore &&
      other.minVideoDuration == minVideoDuration &&
      other.maxVideoDuration == maxVideoDuration &&
      other.includeGifs == includeGifs;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(types),
    sort,
    createdAfter,
    createdBefore,
    minVideoDuration,
    maxVideoDuration,
    includeGifs,
  );
}
