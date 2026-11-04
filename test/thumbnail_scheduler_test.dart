import 'package:flutter_test/flutter_test.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import 'fake_platform.dart';

MediaAsset _a(String id) => MediaAsset(
  id: id,
  type: MediaType.image,
  width: 1,
  height: 1,
  createdAt: DateTime(2024),
  modifiedAt: DateTime(2024),
);

void main() {
  late FakePlatform platform;
  const opts = ThumbnailOptions.square(64);

  setUp(() {
    platform = FakePlatform();
    PhotoLibraryPlatform.instance = platform;
  });

  test('limits concurrency and serves newest requests first', () async {
    final scheduler = ThumbnailScheduler(maxConcurrent: 2);
    final futures = [
      for (var i = 0; i < 5; i++) scheduler.schedule(_a('a$i'), opts),
    ];
    expect(scheduler.activeCount, 2);
    expect(scheduler.pendingCount, 3);
    expect(platform.thumbOrder, ['a0', 'a1']);

    platform.completeThumb(platform.thumbs.keys.first);
    await futures[0];
    await pumpEventQueue();
    // The freed slot goes to the most recent queued request (LIFO).
    expect(platform.thumbOrder.last, 'a4');
  });

  test('cancelling a queued request never reaches the platform', () async {
    final scheduler = ThumbnailScheduler(maxConcurrent: 1);
    scheduler.schedule(_a('busy'), opts);
    final token = ThumbnailCancelToken();
    final queued = scheduler.schedule(_a('queued'), opts, token: token);
    token.cancel();
    expect(await queued, isNull);
    expect(scheduler.pendingCount, 0);
    expect(platform.thumbOrder, ['busy']);
  });

  test('cancelling a running request cancels natively', () async {
    final scheduler = ThumbnailScheduler(maxConcurrent: 1);
    final token = ThumbnailCancelToken();
    final running = scheduler.schedule(_a('a'), opts, token: token);
    token.cancel();
    expect(await running, isNull);
    expect(platform.cancelled, hasLength(1));
    await pumpEventQueue();
    expect(scheduler.activeCount, 0);
  });

  test('pre-cancelled token returns null immediately', () async {
    final scheduler = ThumbnailScheduler();
    final token = ThumbnailCancelToken()..cancel();
    expect(await scheduler.schedule(_a('a'), opts, token: token), isNull);
    expect(platform.thumbOrder, isEmpty);
  });
}
