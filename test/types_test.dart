import 'package:flutter_test/flutter_test.dart';
import 'package:photo_library_kit/photo_library_kit.dart';

void main() {
  test('MediaAsset parses the wire format', () {
    final a = MediaAsset.fromWire({
      'id': 'x',
      'type': 1,
      'w': 1920,
      'h': 1080,
      'dur': 3500,
      'ct': 1000,
      'mt': 2000,
      'mime': 'video/mp4',
      'fav': true,
    });
    expect(a.isVideo, isTrue);
    expect(a.duration, const Duration(milliseconds: 3500));
    expect(a.aspectRatio, closeTo(16 / 9, 1e-9));
    expect(a.isFavorite, isTrue);
    expect(a.modifiedAt.millisecondsSinceEpoch, 2000);
  });

  test('asset equality includes modification date', () {
    final base = {'id': 'x', 'ct': 0, 'mt': 1};
    expect(MediaAsset.fromWire(base), MediaAsset.fromWire(base));
    expect(
      MediaAsset.fromWire(base),
      isNot(MediaAsset.fromWire({...base, 'mt': 2})),
    );
  });

  test('ThumbnailOptions.forCell buckets sizes', () {
    expect(ThumbnailOptions.forCell(95, 3).width, 288);
    expect(ThumbnailOptions.forCell(96, 3).width, 288);
    expect(ThumbnailOptions.forCell(97, 3).width, 320);
    expect(ThumbnailOptions.forCell(1000, 3).width, 1024);
  });

  test('MediaFilter equality is order independent', () {
    const a = MediaFilter(types: {MediaType.image, MediaType.video});
    const b = MediaFilter(types: {MediaType.video, MediaType.image});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(MediaFilter.images.toWire()['video'], isFalse);
  });

  test('PermissionState wire mapping', () {
    expect(PermissionState.fromWire(3), PermissionState.authorized);
    expect(PermissionState.fromWire(4).isLimited, isTrue);
    expect(PermissionState.fromWire(99), PermissionState.notDetermined);
  });

  test('MediaImageProvider.preview never upscales and keeps aspect', () {
    final asset = MediaAsset.fromWire({
      'id': 'x',
      'w': 4000,
      'h': 3000,
      'ct': 0,
      'mt': 0,
    });
    final p = MediaImageProvider.preview(asset, longestSide: 2000);
    expect(p.options.width, 2000);
    expect(p.options.height, 1500);
    expect(p.options.fit, ThumbnailFit.contain);

    final small = MediaAsset.fromWire({
      'id': 'y',
      'w': 400,
      'h': 300,
      'ct': 0,
      'mt': 0,
    });
    expect(MediaImageProvider.preview(small).options.width, 400);
  });
}
