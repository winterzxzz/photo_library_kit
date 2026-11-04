import 'package:flutter_test/flutter_test.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

import 'fake_platform.dart';

void main() {
  late FakePlatform platform;

  setUp(() {
    platform = FakePlatform(total: 250);
    PhotoLibraryPlatform.instance = platform;
  });

  test('load fetches the count and only the first page', () async {
    final list = AssetPagedList(pageSize: 50, watchChanges: false);
    await list.load();
    expect(list.length, 250);
    expect(list.isLoaded, isTrue);
    expect(platform.assetCalls, [(0, 50)]);
    expect(list[10]?.id, 'a10');
  });

  test('unloaded index returns null then fills in with one call', () async {
    final list = AssetPagedList(pageSize: 50, watchChanges: false);
    await list.load();
    await pumpEventQueue();
    var notified = 0;
    list.addListener(() => notified++);

    expect(list[120], isNull);
    expect(list[121], isNull); // same page: no duplicate call
    await pumpEventQueue();
    expect(list[120]?.id, 'a120');
    expect(platform.assetCalls.where((c) => c == (100, 150)), hasLength(1));
    expect(notified, 1);
  });

  test('prefetches the next page near the end of a page', () async {
    final list = AssetPagedList(pageSize: 30, watchChanges: false);
    await list.load();
    list[25];
    await pumpEventQueue();
    expect(platform.assetCalls, contains((30, 60)));
  });

  test('evicts least recently used pages', () async {
    final list = AssetPagedList(
      pageSize: 10,
      maxCachedPages: 3,
      watchChanges: false,
    );
    await list.load();
    for (final i in [10, 20, 30]) {
      await list.getAsset(i);
    }
    expect(list.cachedAssets.length, 30);
    expect(list.cachedAssets.first.id, 'a10'); // page 0 evicted
  });

  test('clamps the last page to the total', () async {
    final list = AssetPagedList(pageSize: 100, watchChanges: false);
    await list.load();
    await list.getAsset(249);
    expect(platform.assetCalls.last, (200, 250));
    expect(list[250], isNull);
  });

  test('library change refreshes and keeps old rows until replaced', () async {
    final list = AssetPagedList(pageSize: 50);
    await list.load();
    expect(list[0]?.id, 'a0');

    platform.total = 10;
    platform.changeController.add(LibraryChange(timestamp: DateTime.now()));
    await pumpEventQueue();
    expect(list.length, 10);
    expect(list[9]?.id, 'a9');
    expect(list[10], isNull);
    list.dispose();
  });
}
