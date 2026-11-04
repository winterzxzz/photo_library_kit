import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../platform/photo_library_platform.dart';
import '../types/media_album.dart';
import '../types/media_asset.dart';
import '../types/media_filter.dart';

/// A lazily paged, random-access view over an album, made for
/// `GridView.builder` / `ListView.builder`.
///
/// ```dart
/// final assets = AssetPagedList(albumId: album.id)..load();
/// ListenableBuilder(
///   listenable: assets,
///   builder: (context, _) => GridView.builder(
///     itemCount: assets.length,
///     itemBuilder: (context, i) {
///       final asset = assets[i];          // null while its page loads
///       return asset == null ? const SizedBox() : AssetThumbnail(asset: asset);
///     },
///   ),
/// );
/// ```
///
/// * Only the total count is fetched up front; pages of [pageSize] are
///   fetched on first access and the next page is prefetched near the end.
/// * At most [maxCachedPages] pages are kept (LRU), so memory stays flat in
///   libraries with 100k+ assets.
/// * Concurrent accesses to the same page share one platform call.
/// * With [watchChanges] the list refreshes itself on library changes and
///   keeps showing the old rows until the new ones arrive (no flicker).
class AssetPagedList extends ChangeNotifier {
  AssetPagedList({
    this.albumId = MediaAlbum.allId,
    this.filter = MediaFilter.all,
    this.pageSize = 60,
    this.maxCachedPages = 24,
    this.watchChanges = true,
  }) : assert(pageSize > 0),
       assert(maxCachedPages > 1);

  final String albumId;
  final MediaFilter filter;
  final int pageSize;
  final int maxCachedPages;
  final bool watchChanges;

  final LinkedHashMap<int, List<MediaAsset>> _pages = LinkedHashMap();
  final Map<int, Future<List<MediaAsset>>> _inFlight = {};
  final Set<int> _stale = {};
  StreamSubscription<Object?>? _changesSub;

  int _length = 0;
  int _generation = 0;
  bool _loaded = false;
  bool _disposed = false;
  bool _notifyScheduled = false;
  Object? _error;

  PhotoLibraryPlatform get _platform => PhotoLibraryPlatform.instance;

  /// Total number of assets. 0 until [load] completes.
  int get length => _length;

  bool get isEmpty => _length == 0;

  /// Whether the first [load] has completed.
  bool get isLoaded => _loaded;

  /// Last error from a platform call, if any.
  Object? get error => _error;

  /// Assets currently held in memory, in index order.
  Iterable<MediaAsset> get cachedAssets sync* {
    final keys = _pages.keys.toList()..sort();
    for (final k in keys) {
      yield* _pages[k]!;
    }
  }

  /// Fetches the count and the first page. Safe to call more than once.
  Future<void> load() async {
    if (watchChanges && _changesSub == null) {
      _changesSub = _platform.changes.listen((_) => refresh());
    }
    await refresh();
  }

  /// Re-reads the count and invalidates cached pages. Old rows stay visible
  /// until fresh ones arrive.
  Future<void> refresh() async {
    final gen = ++_generation;
    try {
      final count = await _platform.getAssetCount(albumId, filter);
      if (_disposed || gen != _generation) return;
      _length = count;
      _error = null;
      _inFlight.clear();
      _stale
        ..clear()
        ..addAll(_pages.keys);
      _pages.removeWhere((page, _) => page * pageSize >= count);
      await _fetch(0, gen);
    } catch (e) {
      if (_disposed || gen != _generation) return;
      _error = e;
    }
    if (_disposed || gen != _generation) return;
    _loaded = true;
    _notify();
  }

  /// The asset at [index], or `null` while its page is loading.
  /// Accessing an index schedules its page (and prefetches the next one).
  MediaAsset? operator [](int index) {
    if (index < 0 || index >= _length) return null;
    final page = index ~/ pageSize;
    final rows = _touch(page);
    if (rows == null || _stale.contains(page)) _request(page);
    final offset = index - page * pageSize;
    if (offset >= pageSize * 2 ~/ 3) _request(page + 1);
    return rows != null && offset < rows.length ? rows[offset] : null;
  }

  /// The asset at [index], loading its page if necessary.
  Future<MediaAsset?> getAsset(int index) async {
    if (index < 0 || index >= _length) return null;
    final page = index ~/ pageSize;
    final rows = _touch(page) ?? await _fetch(page, _generation);
    final offset = index - page * pageSize;
    return offset < rows.length ? rows[offset] : null;
  }

  /// Fetches `[start, end)` in one platform call, bypassing the page cache.
  /// Useful for "select all" style operations.
  Future<List<MediaAsset>> getRange(int start, int end) async {
    end = end.clamp(0, _length);
    if (start >= end) return const [];
    return _platform.getAssets(albumId, filter, start: start, end: end);
  }

  List<MediaAsset>? _touch(int page) {
    final rows = _pages.remove(page);
    if (rows != null) _pages[page] = rows;
    return rows;
  }

  void _request(int page) {
    if (page * pageSize >= _length || _inFlight.containsKey(page)) return;
    if (_pages.containsKey(page) && !_stale.contains(page)) return;
    final gen = _generation;
    _fetch(page, gen)
        .then(
          (_) {
            if (!_disposed && gen == _generation) _notify();
          },
          onError: (Object e) {
            _error = e;
          },
        )
        .ignore();
  }

  Future<List<MediaAsset>> _fetch(int page, int gen) {
    return _inFlight[page] ??= () async {
      try {
        final start = page * pageSize;
        final rows = await _platform.getAssets(
          albumId,
          filter,
          start: start,
          end: (start + pageSize).clamp(0, _length),
        );
        if (!_disposed && gen == _generation) {
          _stale.remove(page);
          _pages.remove(page);
          _pages[page] = rows;
          while (_pages.length > maxCachedPages) {
            _pages.remove(_pages.keys.first);
          }
        }
        return rows;
      } finally {
        if (gen == _generation) _inFlight.remove(page);
      }
    }();
  }

  /// Coalesces bursts of page arrivals into one rebuild.
  void _notify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _changesSub?.cancel();
    super.dispose();
  }
}
