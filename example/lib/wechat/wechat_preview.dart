import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import '../common/asset_selection.dart';
import 'wechat_picker.dart';
import 'wechat_theme.dart';

/// Full-screen swipeable preview with zoom, selection and send.
///
/// Pops with `true` when the user taps Send.
class WeChatPreview extends StatefulWidget {
  const WeChatPreview({
    super.key,
    this.source,
    this.fixed,
    required this.initialIndex,
    required this.selection,
    required this.original,
    required this.onToggle,
  }) : assert((source == null) != (fixed == null));

  /// Browse the whole album...
  final AssetPagedList? source;

  /// ...or only these assets (the "Preview (n)" button).
  final List<MediaAsset>? fixed;

  final int initialIndex;
  final AssetSelection selection;
  final ValueNotifier<bool> original;
  final void Function(MediaAsset asset) onToggle;

  @override
  State<WeChatPreview> createState() => _WeChatPreviewState();
}

class _WeChatPreviewState extends State<WeChatPreview> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chrome = true;

  int get _count => widget.source?.length ?? widget.fixed!.length;

  MediaAsset? _at(int i) {
    if (i < 0 || i >= _count) return null;
    return widget.source?[i] ?? widget.fixed![i];
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _previewSide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (math.max(size.width, size.height) * dpr).round().clamp(512, 2560);
  }

  void _onPage(int i) {
    setState(() => _index = i);
    // Decode neighbours ahead of the swipe.
    final side = _previewSide(context);
    for (final n in [i - 1, i + 1]) {
      final a = _at(n);
      if (a != null && a.isImage) {
        precacheImage(
          MediaImageProvider.preview(a, longestSide: side),
          context,
        ).ignore();
      }
    }
  }

  void _jumpTo(MediaAsset asset) {
    final fixed = widget.fixed;
    if (fixed == null) return;
    final i = fixed.indexWhere((a) => a.id == asset.id);
    if (i >= 0) _pages.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final side = _previewSide(context);
    final page = PageView.builder(
      controller: _pages,
      itemCount: _count,
      onPageChanged: _onPage,
      itemBuilder: (context, i) {
        final asset = _at(i);
        if (asset == null) return const SizedBox.expand();
        return _ZoomablePage(
          key: ValueKey(asset.id),
          asset: asset,
          longestSide: side,
          onTap: () => setState(() => _chrome = !_chrome),
        );
      },
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.source == null
                ? page
                : ListenableBuilder(
                    listenable: widget.source!,
                    builder: (_, _) => page,
                  ),
          ),
          _AnimatedChrome(
            visible: _chrome,
            alignment: Alignment.topCenter,
            child: _PreviewTopBar(
              current: _at(_index),
              selection: widget.selection,
              onToggle: widget.onToggle,
            ),
          ),
          _AnimatedChrome(
            visible: _chrome,
            alignment: Alignment.bottomCenter,
            child: _PreviewBottomBar(
              current: _at(_index),
              selection: widget.selection,
              original: widget.original,
              onThumbTap: _jumpTo,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedChrome extends StatelessWidget {
  const _AnimatedChrome({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        offset: visible ? Offset.zero : Offset(0, alignment.y),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    ),
  );
}

class _ZoomablePage extends StatelessWidget {
  const _ZoomablePage({
    super.key,
    required this.asset,
    required this.longestSide,
    required this.onTap,
  });

  final MediaAsset asset;
  final int longestSide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = MediaImageProvider.preview(asset, longestSide: longestSide);
    return GestureDetector(
      onTap: onTap,
      child: InteractiveViewer(
        maxScale: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The grid thumbnail is usually cached already: show it instantly
            // and cross-fade the sharp image on top.
            Image(
              image: MediaImageProvider(asset, wechatCellOptions(context)),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            Image(
              image: full,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: sync
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: child,
              ),
            ),
            if (asset.isVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 72,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({
    required this.current,
    required this.selection,
    required this.onToggle,
  });

  final MediaAsset? current;
  final AssetSelection selection;
  final void Function(MediaAsset asset) onToggle;

  @override
  Widget build(BuildContext context) {
    final asset = current;
    return Material(
      color: WeChatColors.bar,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: Colors.white,
              ),
              const Spacer(),
              if (asset != null)
                ListenableBuilder(
                  listenable: selection,
                  builder: (context, _) => GestureDetector(
                    onTap: () => onToggle(asset),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: WeChatCheck(
                        index: selection.indexOf(asset),
                        size: 26,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBottomBar extends StatelessWidget {
  const _PreviewBottomBar({
    required this.current,
    required this.selection,
    required this.original,
    required this.onThumbTap,
  });

  final MediaAsset? current;
  final AssetSelection selection;
  final ValueNotifier<bool> original;
  final ValueChanged<MediaAsset> onThumbTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WeChatColors.bar,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: selection,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!selection.isEmpty)
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: selection.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final a = selection.items[i];
                      final active = a.id == current?.id;
                      return GestureDetector(
                        onTap: () => onThumbTap(a),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: active
                                  ? WeChatColors.green
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: AssetThumbnail(asset: a),
                        ),
                      );
                    },
                  ),
                ),
              if (!selection.isEmpty)
                const Divider(height: 1, color: WeChatColors.divider),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    OriginalToggle(original: original),
                    const Spacer(),
                    WeChatSendButton(
                      count: selection.length,
                      max: selection.max,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
