import 'package:flutter/material.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import '../common/formatters.dart';
import '../common/permission_gate.dart';

/// Plain Material gallery showing the core API: filters, albums, paging,
/// metadata and file access.
class BasicGallery extends StatefulWidget {
  const BasicGallery({super.key});

  @override
  State<BasicGallery> createState() => _BasicGalleryState();
}

class _BasicGalleryState extends State<BasicGallery> {
  MediaFilter _filter = MediaFilter.all;
  List<MediaAlbum> _albums = const [];
  String _albumId = MediaAlbum.allId;
  AssetPagedList? _assets;
  bool _started = false;

  @override
  void dispose() {
    _assets?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final albums = await PhotoLibrary.getAlbums(filter: _filter);
    if (!mounted) return;
    if (!albums.any((a) => a.id == _albumId)) _albumId = MediaAlbum.allId;
    _assets?.dispose();
    setState(() {
      _albums = albums;
      _assets = AssetPagedList(albumId: _albumId, filter: _filter)..load();
    });
  }

  void _setFilter(MediaFilter f) {
    _filter = f;
    _reload();
  }

  void _setAlbum(String id) {
    _albumId = id;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: PermissionGate(
        foreground: scheme.onSurface,
        accent: scheme.primary,
        builder: (context, state) {
          if (!_started) {
            _started = true;
            _reload();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SegmentedButton<MediaFilter>(
                  segments: const [
                    ButtonSegment(value: MediaFilter.all, label: Text('All')),
                    ButtonSegment(
                      value: MediaFilter.images,
                      label: Text('Photos'),
                      icon: Icon(Icons.photo_outlined),
                    ),
                    ButtonSegment(
                      value: MediaFilter.videos,
                      label: Text('Videos'),
                      icon: Icon(Icons.videocam_outlined),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => _setFilter(s.first),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final a in _albums)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${a.name} · ${a.count}'),
                          selected: a.id == _albumId,
                          onSelected: (_) => _setAlbum(a.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_assets case final assets?)
                Expanded(
                  child: ListenableBuilder(
                    listenable: assets,
                    builder: (context, _) => GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 130,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                          ),
                      itemCount: assets.length,
                      itemBuilder: (context, i) {
                        final asset = assets[i];
                        if (asset == null) {
                          return ColoredBox(
                            color: scheme.surfaceContainerHighest,
                          );
                        }
                        return InkWell(
                          onTap: () => _showDetails(asset),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AssetThumbnail(asset: asset),
                              if (asset.isVideo)
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Text(
                                    formatDuration(asset.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      shadows: [Shadow(blurRadius: 3)],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDetails(MediaAsset asset) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _Details(asset: asset),
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.asset});

  final MediaAsset asset;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  late final Future<MediaAsset?> _full = PhotoLibrary.getAsset(widget.asset.id);
  String? _path;
  bool _loading = false;

  Future<void> _loadFile() async {
    setState(() => _loading = true);
    try {
      final file = await widget.asset.file();
      final size = await file?.length();
      _path = file == null ? 'Unavailable' : '${file.path}\n${size ?? 0} bytes';
    } on PhotoLibraryException catch (e) {
      _path = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MediaAsset?>(
      future: _full,
      builder: (context, snap) {
        final a = snap.data ?? widget.asset;
        final rows = <(String, String)>[
          ('Type', a.type.name),
          ('Size', '${a.width} × ${a.height}'),
          if (a.isVideo) ('Duration', formatDuration(a.duration)),
          ('Created', a.createdAt.toString()),
          ('Modified', a.modifiedAt.toString()),
          if (a.title != null) ('Name', a.title!),
          if (a.mimeType != null) ('MIME', a.mimeType!),
          ('Favorite', a.isFavorite ? 'Yes' : 'No'),
          if (a.isLivePhoto) ('Live Photo', 'Yes'),
        ];
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: a.aspectRatio.clamp(0.6, 2.0),
                child: Image(
                  image: MediaImageProvider.preview(a, longestSide: 1200),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        k,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(child: Text(v)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _loadFile,
              icon: const Icon(Icons.insert_drive_file_outlined),
              label: const Text('Get file'),
            ),
            if (_path != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  _path!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}
