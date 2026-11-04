import 'package:flutter/material.dart';

import '../image/media_image_provider.dart';
import '../types/media_asset.dart';
import '../types/thumbnail_options.dart';

/// A grid-friendly thumbnail for a [MediaAsset].
///
/// * Picks the request size from its layout and the device pixel ratio,
///   bucketed so similar cells share [ImageCache] entries.
/// * Fades in only when the image was not already cached (no flicker when
///   scrolling back).
/// * Cancels the native request if it is disposed before the image arrives.
class AssetThumbnail extends StatefulWidget {
  const AssetThumbnail({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.options,
    this.quality = 80,
    this.fadeInDuration = const Duration(milliseconds: 160),
    this.placeholderColor,
    this.errorBuilder,
  });

  final MediaAsset asset;
  final BoxFit fit;

  /// Overrides the automatic size selection.
  final ThumbnailOptions? options;

  /// JPEG quality used when [options] is null.
  final int quality;

  final Duration fadeInDuration;

  /// Background shown while loading. Defaults to a subtle surface color.
  final Color? placeholderColor;

  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<AssetThumbnail> {
  MediaImageProvider? _provider;
  bool _loaded = false;

  @override
  void dispose() {
    _evictIfPending();
    super.dispose();
  }

  /// A pending (not yet decoded) cache entry keeps the native request alive.
  /// Evicting it lets [MediaImageProvider] cancel the work.
  void _evictIfPending() {
    final p = _provider;
    if (p != null && !_loaded) {
      PaintingBinding.instance.imageCache.evict(p, includeLive: false);
    }
  }

  MediaImageProvider _providerFor(BoxConstraints constraints) {
    final options =
        widget.options ??
        ThumbnailOptions.forCell(
          _side(constraints),
          MediaQuery.devicePixelRatioOf(context),
          quality: widget.quality,
        );
    final next = MediaImageProvider(widget.asset, options);
    if (next != _provider) {
      _evictIfPending();
      _provider = next;
      _loaded = false;
    }
    return next;
  }

  static double _side(BoxConstraints c) {
    final w = c.hasBoundedWidth ? c.maxWidth : 0.0;
    final h = c.hasBoundedHeight ? c.maxHeight : 0.0;
    final side = w > h ? w : h;
    return side > 0 ? side : 120;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder =
        widget.placeholderColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (context, constraints) {
        final provider = _providerFor(constraints);
        return ColoredBox(
          color: placeholder,
          child: Image(
            image: provider,
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder:
                widget.errorBuilder ??
                (context, error, stack) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            frameBuilder: (context, child, frame, sync) {
              if (frame == null) return const SizedBox.expand();
              _loaded = true;
              if (sync || widget.fadeInDuration == Duration.zero) return child;
              return _FadeIn(duration: widget.fadeInDuration, child: child);
            },
          ),
        );
      },
    );
  }
}

class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _c, child: widget.child);
}
