import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../types/media_asset.dart';
import '../types/photo_library_exception.dart';
import '../types/thumbnail_options.dart';
import 'thumbnail_scheduler.dart';

/// Loads an asset's pixels at a given size through the native image pipeline.
///
/// * Native code decodes **only** the requested size (no full-resolution
///   decode on the Dart side) and returns compact JPEG bytes.
/// * Requests go through [ThumbnailScheduler]: LIFO, throttled, and cancelled
///   natively when no widget is listening any more.
/// * Results live in Flutter's [ImageCache]; the key includes
///   [MediaAsset.modifiedAt], so edited assets never show stale pixels.
@immutable
class MediaImageProvider extends ImageProvider<MediaImageProvider> {
  const MediaImageProvider(
    this.asset,
    this.options, {
    this.scale = 1.0,
    this.scheduler,
  });

  /// Square, center-cropped grid thumbnail of [size] physical pixels.
  MediaImageProvider.thumbnail(
    MediaAsset asset, {
    int size = 256,
    int quality = 80,
  }) : this(asset, ThumbnailOptions.square(size, quality: quality));

  /// Full-screen quality image whose longest side is at most [longestSide]
  /// physical pixels (never upscaled).
  factory MediaImageProvider.preview(
    MediaAsset asset, {
    int longestSide = 2048,
    int quality = 90,
  }) {
    final w = asset.width > 0 ? asset.width : longestSide;
    final h = asset.height > 0 ? asset.height : longestSide;
    final factor = math.min(1.0, longestSide / math.max(w, h));
    return MediaImageProvider(
      asset,
      ThumbnailOptions(
        width: math.max(1, (w * factor).round()),
        height: math.max(1, (h * factor).round()),
        quality: quality,
        fit: ThumbnailFit.contain,
      ),
    );
  }

  final MediaAsset asset;
  final ThumbnailOptions options;
  final double scale;

  /// Defaults to [ThumbnailScheduler.instance]. Not part of the cache key.
  final ThumbnailScheduler? scheduler;

  @override
  Future<MediaImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    MediaImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final token = ThumbnailCancelToken();
    final completer = MultiFrameImageStreamCompleter(
      codec: _load(key, decode, token),
      scale: key.scale,
      debugLabel: '${asset.id}@${options.width}x${options.height}',
      informationCollector: () => [
        DiagnosticsProperty<MediaAsset>('Asset', asset),
        DiagnosticsProperty<ThumbnailOptions>('Options', options),
      ],
    );
    // Fires when the ImageCache entry was evicted and no widget listens any
    // more, e.g. the cell scrolled off screen before the image arrived.
    completer.addOnLastListenerRemovedCallback(token.cancel);
    return completer;
  }

  Future<ui.Codec> _load(
    MediaImageProvider key,
    ImageDecoderCallback decode,
    ThumbnailCancelToken token,
  ) async {
    final Uint8List? bytes;
    try {
      bytes = await (scheduler ?? ThumbnailScheduler.instance).schedule(
        key.asset,
        key.options,
        token: token,
      );
    } catch (_) {
      // A native error for a request nobody waits for is not worth reporting.
      if (token.isCancelled) return Completer<ui.Codec>().future;
      rethrow;
    }
    if (token.isCancelled) {
      // Nobody is listening: never complete instead of reporting a bogus error.
      return Completer<ui.Codec>().future;
    }
    if (bytes == null || bytes.isEmpty) {
      throw PhotoLibraryException(
        'not_found',
        'No image data for asset ${key.asset.id}',
      );
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is MediaImageProvider &&
      other.asset == asset &&
      other.options == options &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(asset, options, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'MediaImageProvider')}'
      '(${asset.id}, $options, scale: $scale)';
}
