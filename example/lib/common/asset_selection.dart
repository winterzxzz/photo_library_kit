import 'package:flutter/foundation.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

/// Ordered multi-selection with a cap, shared by the picker demos.
class AssetSelection extends ChangeNotifier {
  AssetSelection({this.max = 9, Iterable<MediaAsset> initial = const []})
    : _items = [...initial];

  final int max;
  final List<MediaAsset> _items;

  List<MediaAsset> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isFull => _items.length >= max;

  /// 0-based position in the selection, or -1.
  int indexOf(MediaAsset asset) => _items.indexWhere((a) => a.id == asset.id);

  bool contains(MediaAsset asset) => indexOf(asset) >= 0;

  /// Returns `false` when the asset could not be added because of [max].
  bool toggle(MediaAsset asset) {
    final i = indexOf(asset);
    if (i >= 0) {
      _items.removeAt(i);
    } else {
      if (isFull) return false;
      _items.add(asset);
    }
    notifyListeners();
    return true;
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
