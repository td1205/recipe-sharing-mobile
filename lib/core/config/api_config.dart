import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Android Emulator uses 10.0.2.2. Physical devices and production provide
  /// API_BASE_URL with --dart-define (a LAN URL and an HTTPS URL respectively).
  static String get baseUrl {
    if (_override.isNotEmpty) return _normalise(_override);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Cloudinary unsigned upload credentials for recipe media. Mirrors the web
  /// frontend's VITE_CLOUDINARY_* variables; empty means "not configured" and
  /// the recipe form falls back to pasting an image URL.
  static String get cloudinaryCloudName =>
      const String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static String get cloudinaryUploadPreset =>
      const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static String _normalise(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}

/// Resolves backend-returned image URLs to absolute ones. Recipe media and
/// Cloudinary assets arrive as absolute https URLs, while avatars are served
/// statically as relative paths such as `/avatars/avatar-1-2.jpg`.
abstract final class ImageUrl {
  static String resolve(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return ApiConfig.baseUrl + trimmed;
    return trimmed;
  }
}
