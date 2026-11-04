import 'package:flutter_test/flutter_test.dart';
import 'package:photo_library_kit/photo_library_kit.dart';
import 'package:photo_library_kit/photo_library_kit_platform_interface.dart';
import 'package:photo_library_kit/photo_library_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPhotoLibraryKitPlatform
    with MockPlatformInterfaceMixin
    implements PhotoLibraryKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PhotoLibraryKitPlatform initialPlatform = PhotoLibraryKitPlatform.instance;

  test('$MethodChannelPhotoLibraryKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPhotoLibraryKit>());
  });

  test('getPlatformVersion', () async {
    PhotoLibraryKit photoLibraryKitPlugin = PhotoLibraryKit();
    MockPhotoLibraryKitPlatform fakePlatform = MockPhotoLibraryKitPlatform();
    PhotoLibraryKitPlatform.instance = fakePlatform;

    expect(await photoLibraryKitPlugin.getPlatformVersion(), '42');
  });
}
