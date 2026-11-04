import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import '../common/album_cover.dart';
import '../common/asset_selection.dart';
import '../common/formatters.dart';
import '../common/permission_gate.dart';
import 'instagram_post_page.dart';

abstract final class _Ig {
  static const blue = Color(0xFF0095F6);
  static const bg = Colors.black;
  static const tile = Color(0xFF1C1C1C);
  static const secondary = Color(0x99FFFFFF);
}

/// Grid cell options, shared with the preview placeholder (same cache key).
ThumbnailOptions _cellOptions(BuildContext context) => ThumbnailOptions.forCell(
  (MediaQuery.sizeOf(context).width - 4.5) / 4,
  MediaQuery.devicePixelRatioOf(context),
  quality: 80,
);

/// Instagram-style "New post": square crop preview on top, album grid below,
/// optional multi-select (up to 10) with numbered badges.
class InstagramPicker extends StatefulWidget {
  const InstagramPicker({super.key});

  @override
  State<InstagramPicker> createState() => _InstagramPickerState();
}

class _InstagramPickerState extends State<InstagramPicker> {
  final ScrollController _scroll = ScrollController();
  final AssetSelection _selection = AssetSelection(max: 10);
  List<MediaAlbum> _albums = const [];
  MediaAlbum? _album;
  AssetPagedList? _assets;
  MediaAsset? _focused;
  bool _multi = false;
  bool _fill = true;
  bool _started = false;

  @override
  void dispose() {
    _scroll.dispose();
    _assets?.dispose();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final albums = await PhotoLibrary.getAlbums();
    if (!mounted || albums.isEmpty) return;
    setState(() => _albums = albums);
    _openAlbum(albums.first);
  }

  void _openAlbum(MediaAlbum album) {
    _assets?.dispose();
    final assets = AssetPagedList(albumId: album.id);
    setState(() {
      _album = album;
      _assets = assets;
    });
    assets.load().then((_) async {
      if (_focused == null && mounted && !assets.isEmpty) {
        final first = await assets.getAsset(0);
        if (mounted) setState(() => _focused = first);
      }
    });
  }

  void _tap(MediaAsset asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_multi) {
        final selected = _selection.contains(asset);
        if (selected && _focused?.id == asset.id) {
          _selection.toggle(asset);
          _focused = _selection.isEmpty ? asset : _selection.items.last;
        } else {
          if (!selected) _selection.toggle(asset);
          _focused = asset;
        }
      } else {
        _focused = asset;
      }
    });
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleMulti() {
    setState(() {
      _multi = !_multi;
      _selection.clear();
      if (_multi && _focused != null) _selection.toggle(_focused!);
    });
  }

  Future<void> _chooseAlbum() async {
    final album = await showModalBottomSheet<MediaAlbum>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: _albums.length,
          itemBuilder: (context, i) {
            final a = _albums[i];
            return ListTile(
              leading: AlbumCover(album: a, size: 64, radius: 6),
              title: Text(a.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                '${a.count}',
                style: const TextStyle(color: _Ig.secondary),
              ),
              onTap: () => Navigator.of(context).pop(a),
            );
          },
        ),
      ),
    );
    if (album != null && album.id != _album?.id) _openAlbum(album);
  }

  void _next() {
    final assets = _multi ? _selection.items : [?_focused];
    if (assets.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstagramPostPage(assets: assets, fill: _fill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Ig.bg,
        appBar: AppBar(
          backgroundColor: _Ig.bg,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'New post',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: _focused == null ? null : _next,
              child: const Text(
                'Next',
                style: TextStyle(
                  color: _Ig.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: PermissionGate(
          accent: _Ig.blue,
          builder: (context, state) {
            if (!_started) {
              _started = true;
              _start();
            }
            return CustomScrollView(
              controller: _scroll,
              slivers: [
                if (state.isLimited)
                  const SliverToBoxAdapter(
                    child: LimitedAccessBanner(
                      background: Color(0xFF121212),
                      foreground: _Ig.secondary,
                      accent: _Ig.blue,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _CropPreview(
                      asset: _focused,
                      fill: _fill,
                      onToggleFill: () => setState(() => _fill = !_fill),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _HeaderDelegate(
                    title: _album?.name ?? '',
                    multi: _multi,
                    onAlbum: _chooseAlbum,
                    onMulti: _toggleMulti,
                  ),
                ),
                if (_assets case final assets?)
                  ListenableBuilder(
                    listenable: assets,
                    builder: (context, _) => SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 1.5,
                            crossAxisSpacing: 1.5,
                          ),
                      itemCount: assets.length,
                      itemBuilder: (context, i) {
                        final asset = assets[i];
                        if (asset == null) {
                          return const ColoredBox(color: _Ig.tile);
                        }
                        return _Tile(
                          key: ValueKey(asset.id),
                          asset: asset,
                          focused: asset.id == _focused?.id,
                          multi: _multi,
                          selection: _selection,
                          onTap: () => _tap(asset),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CropPreview extends StatefulWidget {
  const _CropPreview({
    required this.asset,
    required this.fill,
    required this.onToggleFill,
  });

  final MediaAsset? asset;
  final bool fill;
  final VoidCallback onToggleFill;

  @override
  State<_CropPreview> createState() => _CropPreviewState();
}

class _CropPreviewState extends State<_CropPreview> {
  bool _interacting = false;

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    if (asset == null) return const ColoredBox(color: _Ig.tile);
    final side =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context) *
                1.5)
            .round();
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0E0E0E)),
          // Cached grid thumbnail shows instantly while the sharp one decodes.
          Image(
            image: MediaImageProvider(asset, _cellOptions(context)),
            fit: widget.fill ? BoxFit.cover : BoxFit.contain,
            gaplessPlayback: true,
          ),
          InteractiveViewer(
            key: ValueKey('${asset.id}-${widget.fill}'),
            maxScale: 5,
            onInteractionStart: (_) => setState(() => _interacting = true),
            onInteractionEnd: (_) => setState(() => _interacting = false),
            child: Image(
              image: MediaImageProvider.preview(asset, longestSide: side),
              fit: widget.fill ? BoxFit.cover : BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
            ),
          ),
          // Rule-of-thirds guide while the user drags or pinches.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _interacting ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const CustomPaint(painter: _ThirdsPainter()),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _RoundButton(
              icon: widget.fill
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              onTap: widget.onToggleFill,
            ),
          ),
          if (asset.isVideo)
            Positioned(
              right: 12,
              bottom: 12,
              child: _Pill(formatDuration(asset.duration)),
            ),
        ],
      ),
    );
  }
}

class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x99FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => false;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.active});

  final IconData icon;
  final VoidCallback onTap;
  final bool? active;

  @override
  Widget build(BuildContext context) => Material(
    color: active == true ? _Ig.blue : const Color(0xB3262626),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xB3262626),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate({
    required this.title,
    required this.multi,
    required this.onAlbum,
    required this.onMulti,
  });

  final String title;
  final bool multi;
  final VoidCallback onAlbum;
  final VoidCallback onMulti;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    // Must fill the extent exactly, or the sliver geometry is invalid.
    return SizedBox.expand(
      child: ColoredBox(
        color: _Ig.bg,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onAlbum,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              label: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            _RoundButton(
              icon: Icons.copy_all_outlined,
              active: multi,
              onTap: onMulti,
            ),
            const SizedBox(width: 10),
            const _RoundButton(icon: Icons.photo_camera_outlined, onTap: _noop),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  static void _noop() {}

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.title != title || old.multi != multi;
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.asset,
    required this.focused,
    required this.multi,
    required this.selection,
    required this.onTap,
  });

  final MediaAsset asset;
  final bool focused;
  final bool multi;
  final AssetSelection selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetThumbnail(
            asset: asset,
            options: _cellOptions(context),
            placeholderColor: _Ig.tile,
          ),
          if (focused) const ColoredBox(color: Color(0x66FFFFFF)),
          if (asset.isVideo)
            Positioned(
              right: 5,
              bottom: 4,
              child: Text(
                formatDuration(asset.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          if (multi)
            Positioned(
              top: 5,
              right: 5,
              child: ListenableBuilder(
                listenable: selection,
                builder: (context, _) {
                  final i = selection.indexOf(asset);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i >= 0 ? _Ig.blue : const Color(0x33000000),
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                    child: i >= 0
                        ? Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
