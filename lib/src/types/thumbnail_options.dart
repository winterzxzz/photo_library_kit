import 'package:flutter/foundation.dart';

/// Encoding of bytes returned by the platform.
enum ThumbnailFormat { jpeg, png }

/// How the image is fitted into the requested box.
enum ThumbnailFit {
  /// Scale to fill the box and center-crop (grid cells).
  cover,

  /// Scale to fit inside the box, keeping the whole image (previews).
  contain,
}

/// Parameters for a native thumbnail request.
///
/// Sizes are in **physical pixels**. Use `ThumbnailOptions.forCell` to derive
/// them from a logical size and the device pixel ratio.
@immutable
class ThumbnailOptions {
  const ThumbnailOptions({
    required this.width,
    required this.height,
    this.quality = 85,
    this.format = ThumbnailFormat.jpeg,
    this.fit = ThumbnailFit.cover,
    this.allowNetwork = true,
  }) : assert(width > 0 && height > 0),
       assert(quality > 0 && quality <= 100);

  /// Square thumbnail of [size] physical pixels.
  const ThumbnailOptions.square(
    int size, {
    int quality = 85,
    ThumbnailFit fit = ThumbnailFit.cover,
  }) : this(width: size, height: size, quality: quality, fit: fit);

  /// Thumbnail for a grid cell of [logicalSize] at [devicePixelRatio], rounded
  /// up to a bucket of 32px so neighbouring layouts share cache entries.
  factory ThumbnailOptions.forCell(
    double logicalSize,
    double devicePixelRatio, {
    int quality = 85,
  }) {
    final px = (logicalSize * devicePixelRatio / 32).ceil() * 32;
    return ThumbnailOptions.square(px.clamp(32, 1024), quality: quality);
  }

  final int width;
  final int height;

  /// JPEG quality 1-100. Ignored for PNG.
  final int quality;

  final ThumbnailFormat format;
  final ThumbnailFit fit;

  /// iOS: allow downloading from iCloud when the asset is not on device.
  final bool allowNetwork;

  Map<String, Object?> toWire() => {
    'w': width,
    'h': height,
    'q': quality,
    'fmt': format.index,
    'fit': fit.index,
    'net': allowNetwork,
  };

  @override
  bool operator ==(Object other) =>
      other is ThumbnailOptions &&
      other.width == width &&
      other.height == height &&
      other.quality == quality &&
      other.format == format &&
      other.fit == fit &&
      other.allowNetwork == allowNetwork;

  @override
  int get hashCode =>
      Object.hash(width, height, quality, format, fit, allowNetwork);

  @override
  String toString() => 'ThumbnailOptions(${width}x$height, ${fit.name})';
}
