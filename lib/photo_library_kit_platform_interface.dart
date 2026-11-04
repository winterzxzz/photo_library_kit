import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'photo_library_kit_method_channel.dart';

abstract class PhotoLibraryKitPlatform extends PlatformInterface {
  /// Constructs a PhotoLibraryKitPlatform.
  PhotoLibraryKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static PhotoLibraryKitPlatform _instance = MethodChannelPhotoLibraryKit();

  /// The default instance of [PhotoLibraryKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelPhotoLibraryKit].
  static PhotoLibraryKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PhotoLibraryKitPlatform] when
  /// they register themselves.
  static set instance(PhotoLibraryKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
