import 'package:flutter/services.dart';

/// Thrown when a platform call fails.
class PhotoLibraryException implements Exception {
  const PhotoLibraryException(this.code, [this.message]);

  factory PhotoLibraryException.fromPlatform(PlatformException e) =>
      PhotoLibraryException(e.code, e.message);

  /// Machine readable code, e.g. `permission_denied`, `not_found`,
  /// `io_error`, `cancelled`, `no_activity`.
  final String code;
  final String? message;

  @override
  String toString() =>
      'PhotoLibraryException($code${message == null ? '' : ': $message'})';
}
