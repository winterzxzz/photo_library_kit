import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/photo_library_platform.dart';
import '../types/thumbnail_options.dart';

/// Cancels a scheduled thumbnail request.
class ThumbnailCancelToken {
  bool _cancelled = false;
  VoidCallback? _onCancel;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final cb = _onCancel;
    _onCancel = null;
    cb?.call();
  }
}

/// Throttles native thumbnail requests.
///
/// Fast scrolling creates far more requests than the platform can serve.
/// Requests are kept in a **LIFO** stack so cells that just became visible
/// are served first, at most [maxConcurrent] run natively at once, and a
/// request whose cell scrolled away is dropped from the stack or cancelled
/// natively (PHImageManager / CancellationSignal).
class ThumbnailScheduler {
  ThumbnailScheduler({this.maxConcurrent = 8}) : assert(maxConcurrent > 0);

  /// Shared scheduler used by `MediaImageProvider`.
  static final ThumbnailScheduler instance = ThumbnailScheduler();

  static int _nextRequestId = 1;

  /// Unique id for a native request.
  static int nextRequestId() => _nextRequestId++;

  int maxConcurrent;

  final List<_Job> _stack = [];
  int _active = 0;

  @visibleForTesting
  int get pendingCount => _stack.length;

  @visibleForTesting
  int get activeCount => _active;

  /// Resolves to the encoded bytes, or `null` when the asset is gone or the
  /// request was cancelled.
  Future<Uint8List?> schedule(
    String assetId,
    ThumbnailOptions options, {
    ThumbnailCancelToken? token,
  }) {
    if (token?.isCancelled ?? false) return SynchronousFuture(null);
    final job = _Job(assetId, options, nextRequestId());
    token?._onCancel = () => _cancel(job);
    _stack.add(job);
    _pump();
    return job.completer.future;
  }

  void _cancel(_Job job) {
    if (job.done) return;
    if (_stack.remove(job)) {
      job.finish(null);
    } else if (job.started) {
      job.cancelled = true;
      PhotoLibraryPlatform.instance.cancelThumbnail(job.requestId).ignore();
    }
  }

  void _pump() {
    while (_active < maxConcurrent && _stack.isNotEmpty) {
      _run(_stack.removeLast());
    }
  }

  Future<void> _run(_Job job) async {
    _active++;
    job.started = true;
    try {
      final bytes = await PhotoLibraryPlatform.instance.getThumbnail(
        job.assetId,
        job.options,
        requestId: job.requestId,
      );
      job.finish(job.cancelled ? null : bytes);
    } catch (e, s) {
      job.fail(e, s);
    } finally {
      _active--;
      _pump();
    }
  }
}

class _Job {
  _Job(this.assetId, this.options, this.requestId);

  final String assetId;
  final ThumbnailOptions options;
  final int requestId;
  final Completer<Uint8List?> completer = Completer();
  bool started = false;
  bool cancelled = false;

  bool get done => completer.isCompleted;

  void finish(Uint8List? bytes) {
    if (!done) completer.complete(bytes);
  }

  void fail(Object error, StackTrace stack) {
    if (!done) completer.completeError(error, stack);
  }
}
