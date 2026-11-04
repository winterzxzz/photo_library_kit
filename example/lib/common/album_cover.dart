import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

/// Album cover thumbnail resolved lazily from [MediaAlbum.coverId].
/// Lookups are memoised so reopening the album list costs nothing.
class AlbumCover extends StatelessWidget {
  const AlbumCover({
    super.key,
    required this.album,
    this.size = 56,
    this.radius = 4,
    this.placeholder = const Color(0x22FFFFFF),
  });

  final MediaAlbum album;
  final double size;
  final double radius;
  final Color placeholder;

  static final Map<String, Future<MediaAsset?>> _cache = {};

  @override
  Widget build(BuildContext context) {
    final coverId = album.coverId;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: coverId == null
            ? ColoredBox(color: placeholder)
            : FutureBuilder<MediaAsset?>(
                future: _cache[coverId] ??= PhotoLibrary.getAsset(coverId),
                builder: (context, snap) {
                  final asset = snap.data;
                  return asset == null
                      ? ColoredBox(color: placeholder)
                      : AssetThumbnail(
                          asset: asset,
                          placeholderColor: placeholder,
                        );
                },
              ),
      ),
    );
  }
}
