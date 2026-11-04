import 'package:flutter/foundation.dart';

/// Emitted by [PhotoLibrary.changes] when the device library changes.
///
/// Native observers are debounced, so a burst of edits (for example a camera
/// burst or a bulk import) produces a single event.
@immutable
class LibraryChange {
  const LibraryChange({
    required this.timestamp,
    this.insertedIds = const [],
    this.removedIds = const [],
    this.updatedIds = const [],
  });

  final DateTime timestamp;

  /// Ids reported as inserted. Empty when the platform only reports that
  /// something changed (Android), so treat empty lists as "unknown".
  final List<String> insertedIds;
  final List<String> removedIds;
  final List<String> updatedIds;

  /// Whether the platform reported per-asset details.
  bool get hasDetails =>
      insertedIds.isNotEmpty || removedIds.isNotEmpty || updatedIds.isNotEmpty;

  factory LibraryChange.fromWire(Object? event) {
    final map = event is Map ? event : const {};
    List<String> ids(String key) =>
        (map[key] as List?)?.cast<String>() ?? const [];
    return LibraryChange(
      timestamp: DateTime.now(),
      insertedIds: ids('inserted'),
      removedIds: ids('removed'),
      updatedIds: ids('updated'),
    );
  }

  @override
  String toString() =>
      'LibraryChange(+${insertedIds.length} -${removedIds.length} '
      '~${updatedIds.length})';
}
