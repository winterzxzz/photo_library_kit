import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_library_kit_platform_interface.dart';

/// An implementation of [PhotoLibraryKitPlatform] that uses method channels.
class MethodChannelPhotoLibraryKit extends PhotoLibraryKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('photo_library_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
