
import 'photo_library_kit_platform_interface.dart';

class PhotoLibraryKit {
  Future<String?> getPlatformVersion() {
    return PhotoLibraryKitPlatform.instance.getPlatformVersion();
  }
}
