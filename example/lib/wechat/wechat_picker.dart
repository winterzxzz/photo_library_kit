import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import '../common/album_cover.dart';
import '../common/asset_selection.dart';
import '../common/formatters.dart';
import '../common/permission_gate.dart';
import 'wechat_preview.dart';
import 'wechat_theme.dart';

/// Thumbnail options shared by the grid and the preview placeholder so both
/// hit the same [ImageCache] entry. Cells are (width - padding - gaps) / 4.
ThumbnailOptions wechatCellOptions(BuildContext context) =>
    ThumbnailOptions.forCell(
      (MediaQuery.sizeOf(context).width - 10) / 4,
      MediaQuery.devicePixelRatioOf(context),
      quality: 80,
    );

/// Result of the WeChat picker.
class WeChatPickResult {
  const WeChatPickResult(this.assets, {required this.original});

  final List<MediaAsset> assets;

  /// The "Original" toggle: send full-quality files.
  final bool original;
}

/// A WeChat-style dark picker: album drop-down, numbered multi-select,
/// preview, and "Original" toggle.
class WeChatPicker extends StatefulWidget {
  const WeChatPicker({
    super.key,
    this.maxAssets = 9,
    this.initial = const [],
    this.filter = MediaFilter.all,
  });

  final int maxAssets;
  final List<MediaAsset> initial;
  final MediaFilter filter;

  static Future<WeChatPickResult?> show(
    BuildContext context, {
    int maxAssets = 9,
    List<MediaAsset> initial = const [],
  }) => Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, _, _) =>
          WeChatPicker(maxAssets: maxAssets, initial: initial),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );

  @override
  State<WeChatPicker> createState() => _WeChatPickerState();
}

class _WeChatPickerState extends State<WeChatPicker> {
  late final AssetSelection _selection = AssetSelection(
    max: widget.maxAssets,
    initial: widget.initial,
  );
  final ValueNotifier<bool> _original = ValueNotifier(false);
  List<MediaAlbum> _albums = const [];
  MediaAlbum? _album;
  AssetPagedList? _assets;
  bool _albumsOpen = false;
  bool _albumsRequested = false;

  @override
  void dispose() {
    _assets?.dispose();
    _selection.dispose();
    _original.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoLibrary.getAlbums(filter: widget.filter);
    if (!mounted) return;
    setState(() => _albums = albums);
    if (_album == null && albums.isNotEmpty) _openAlbum(albums.first);
  }

  void _openAlbum(MediaAlbum album) {
    _assets?.dispose();
    setState(() {
      _album = album;
      _albumsOpen = false;
      _assets = AssetPagedList(albumId: album.id, filter: widget.filter)
        ..load();
    });
  }

  void _toggle(MediaAsset asset) {
    if (!_selection.toggle(asset)) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('You can select up to ${widget.maxAssets} items'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _send() =>
      Navigator.of(context)
          .pop(WeChatPickResult(_selection.items, original: _original.value));

  Future<void> _preview(int index, {bool selectedOnly = false}) async {
    final assets = _assets;
    if (assets == null) return;
    final send = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => WeChatPreview(
          source: selectedOnly ? null : assets,
          fixed: selectedOnly ? _selection.items : null,
          initialIndex: index,
          selection: _selection,
          original: _original,
          onToggle: _toggle,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (send == true && mounted) _send();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: WeChatColors.background,
        body: PermissionGate(
          builder: (context, state) {
            if (!_albumsRequested) {
              _albumsRequested = true;
              _loadAlbums();
            }
            return Column(
              children: [
                _TopBar(
                  title: _album?.name ?? '',
                  albumsOpen: _albumsOpen,
                  selection: _selection,
                  onClose: () => Navigator.of(context).pop(),
                  onTitle: () => setState(() => _albumsOpen = !_albumsOpen),
                  onSend: _send,
                ),
                if (state.isLimited)
                  const LimitedAccessBanner(
                    background: WeChatColors.bar,
                    foreground: WeChatColors.secondary,
                    accent: WeChatColors.green,
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      if (_assets case final assets?)
                        _Grid(
                          assets: assets,
                          selection: _selection,
                          onTap: _preview,
                          onToggle: _toggle,
                        ),
                      _AlbumDropdown(
                        open: _albumsOpen,
                        albums: _albums,
                        current: _album,
                        onSelect: _openAlbum,
                        onDismiss: () => setState(() => _albumsOpen = false),
                      ),
                    ],
                  ),
                ),
                _BottomBar(
                  selection: _selection,
                  original: _original,
                  onPreview: () => _preview(0, selectedOnly: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.albumsOpen,
    required this.selection,
    required this.onClose,
    required this.onTitle,
    required this.onSend,
  });

  final String title;
  final bool albumsOpen;
  final AssetSelection selection;
  final VoidCallback onClose;
  final VoidCallback onTitle;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WeChatColors.bar,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: WeChatColors.text),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onTitle,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WeChatColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: albumsOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0x88FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ListenableBuilder(
                  listenable: selection,
                  builder: (context, _) => WeChatSendButton(
                    count: selection.length,
                    max: selection.max,
                    onPressed: onSend,
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

class _Grid extends StatelessWidget {
  const _Grid({
    required this.assets,
    required this.selection,
    required this.onTap,
    required this.onToggle,
  });

  final AssetPagedList assets;
  final AssetSelection selection;
  final void Function(int index) onTap;
  final void Function(MediaAsset asset) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: assets,
      builder: (context, _) {
        if (assets.isLoaded && assets.isEmpty) {
          return const Center(
            child: Text(
              'No photos or videos',
              style: TextStyle(color: WeChatColors.secondary),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          // Builds cells slightly ahead of the viewport so thumbnails are
          // requested before they scroll in.
          scrollCacheExtent: const ScrollCacheExtent.pixels(600),
          itemCount: assets.length,
          itemBuilder: (context, i) {
            final asset = assets[i];
            if (asset == null) {
              return const ColoredBox(color: WeChatColors.tile);
            }
            return _Tile(
              key: ValueKey(asset.id),
              asset: asset,
              selection: selection,
              onTap: () => onTap(i),
              onToggle: () => onToggle(asset),
            );
          },
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.asset,
    required this.selection,
    required this.onTap,
    required this.onToggle,
  });

  final MediaAsset asset;
  final AssetSelection selection;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetThumbnail(
            asset: asset,
            options: wechatCellOptions(context),
            placeholderColor: WeChatColors.tile,
          ),
          if (asset.isVideo)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, 0.3),
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          if (asset.isVideo)
            Positioned(
              left: 6,
              right: 6,
              bottom: 4,
              child: Row(
                children: [
                  const Icon(Icons.videocam, size: 16, color: Colors.white),
                  const Spacer(),
                  Text(
                    formatDuration(asset.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (asset.isGif)
            const Positioned(left: 6, bottom: 4, child: _Tag('GIF')),
          // Only this part rebuilds when the selection changes.
          ListenableBuilder(
            listenable: selection,
            builder: (context, _) {
              final index = selection.indexOf(asset);
              final dimmed = index < 0 && selection.isFull;
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    color: index >= 0
                        ? const Color(0x66000000)
                        : dimmed
                        ? const Color(0x99FFFFFF)
                        : Colors.transparent,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: WeChatCheck(index: index),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selection,
    required this.original,
    required this.onPreview,
  });

  final AssetSelection selection;
  final ValueNotifier<bool> original;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WeChatColors.bar,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              ListenableBuilder(
                listenable: selection,
                builder: (context, _) => TextButton(
                  onPressed: selection.isEmpty ? null : onPreview,
                  child: Text(
                    selection.isEmpty
                        ? 'Preview'
                        : 'Preview (${selection.length})',
                    style: TextStyle(
                      color: selection.isEmpty
                          ? WeChatColors.secondary
                          : WeChatColors.text,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              OriginalToggle(original: original),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "◯ Original" radio.
class OriginalToggle extends StatelessWidget {
  const OriginalToggle({super.key, required this.original});

  final ValueNotifier<bool> original;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: original,
      builder: (context, on, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => original.value = !on,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? WeChatColors.green : Colors.transparent,
                border: on
                    ? null
                    : Border.all(color: WeChatColors.secondary, width: 1.5),
              ),
              child: on
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
            const Text(
              'Original',
              style: TextStyle(color: WeChatColors.text, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumDropdown extends StatelessWidget {
  const _AlbumDropdown({
    required this.open,
    required this.albums,
    required this.current,
    required this.onSelect,
    required this.onDismiss,
  });

  final bool open;
  final List<MediaAlbum> albums;
  final MediaAlbum? current;
  final ValueChanged<MediaAlbum> onSelect;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 240);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight * 0.72;
        return IgnorePointer(
          ignoring: !open,
          child: Stack(
            children: [
              GestureDetector(
                onTap: onDismiss,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: open ? 1 : 0,
                  child: const ColoredBox(
                    color: Color(0x99000000),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                top: open ? 0 : -height,
                left: 0,
                right: 0,
                height: height,
                child: Material(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: albums.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 84,
                      color: WeChatColors.divider,
                    ),
                    itemBuilder: (context, i) {
                      final album = albums[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: AlbumCover(album: album),
                        title: Text(
                          album.name,
                          style: const TextStyle(color: WeChatColors.text),
                        ),
                        subtitle: Text(
                          '${album.count}',
                          style: const TextStyle(color: WeChatColors.secondary),
                        ),
                        trailing: album.id == current?.id
                            ? const Icon(Icons.check, color: WeChatColors.green)
                            : null,
                        onTap: () => onSelect(album),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
