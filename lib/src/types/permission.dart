/// Authorization state of the photo library.
enum PermissionState {
  /// The user has not been asked yet.
  notDetermined,

  /// Access is restricted by parental controls or device policy (iOS only).
  restricted,

  /// The user denied access.
  denied,

  /// Full access to the library.
  authorized,

  /// Access to a user-selected subset of the library
  /// (iOS 14+ "Selected Photos", Android 14+ "Allow limited access").
  limited;

  /// Whether assets can be read (fully or partially).
  bool get hasAccess => this == authorized || this == limited;

  /// Whether the app can only see a user-selected subset of assets.
  bool get isLimited => this == limited;

  static PermissionState fromWire(Object? value) {
    final index = value is int ? value : 0;
    return index >= 0 && index < values.length
        ? values[index]
        : PermissionState.notDetermined;
  }
}

/// Options for [PhotoLibrary.requestPermission].
class PermissionRequest {
  const PermissionRequest({
    this.images = true,
    this.videos = true,
    this.addOnly = false,
  }) : assert(images || videos || addOnly, 'Request at least one access type');

  /// Request access to images (Android 13+ maps to `READ_MEDIA_IMAGES`).
  final bool images;

  /// Request access to videos (Android 13+ maps to `READ_MEDIA_VIDEO`).
  final bool videos;

  /// iOS only: request add-only access (save to library without reading).
  final bool addOnly;

  Map<String, Object?> toWire() => {
        'images': images,
        'videos': videos,
        'addOnly': addOnly,
      };
}
