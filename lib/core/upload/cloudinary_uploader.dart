import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';

final cloudinaryUploaderProvider = Provider<CloudinaryUploader>(
  (ref) => const CloudinaryUploader(),
);

class CloudinaryUploadResult {
  const CloudinaryUploadResult({required this.url, required this.mediaType});
  final String url;
  final String mediaType;
}

/// Uploads recipe media straight to Cloudinary with an unsigned upload preset,
/// mirroring the web frontend (`frontend/src/utils/cloudinary.js`).
/// Configure via dart-define:
///   --dart-define=CLOUDINARY_CLOUD_NAME=... --dart-define=CLOUDINARY_UPLOAD_PRESET=...
class CloudinaryUploader {
  const CloudinaryUploader({this.dio});

  final Dio? dio;

  bool get isConfigured => ApiConfig.isCloudinaryConfigured;

  Future<CloudinaryUploadResult> upload({
    required List<int> fileBytes,
    required String filename,
    required String mimeType,
  }) async {
    if (!isConfigured) {
      throw const CloudinaryException(
        'Chưa cấu hình Cloudinary (thiếu CLOUDINARY_CLOUD_NAME / '
        'CLOUDINARY_UPLOAD_PRESET). Bạn có thể dán đường dẫn ảnh thay thế.',
      );
    }
    final mediaType = mimeType.startsWith('video/') ? 'video' : 'image';
    final form = FormData();
    form.files.add(
      MapEntry('file', MultipartFile.fromBytes(fileBytes, filename: filename)),
    );
    form.fields.add(
      MapEntry('upload_preset', ApiConfig.cloudinaryUploadPreset),
    );
    form.fields.add(
      MapEntry(
        'public_id',
        'recipe_${DateTime.now().millisecondsSinceEpoch}_'
            '${DateTime.now().microsecondsSinceEpoch.remainder(100000)}',
      ),
    );
    try {
      final client =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
      final response = await client.post(
        'https://api.cloudinary.com/v1_1/'
        '${ApiConfig.cloudinaryCloudName}/$mediaType/upload',
        data: form,
      );
      final data = response.data;
      final url = data is Map ? data['secure_url'] : null;
      if (url is String && url.isNotEmpty) {
        return CloudinaryUploadResult(url: url, mediaType: mediaType);
      }
      throw const CloudinaryException('Cloudinary không trả về đường dẫn tệp.');
    } on CloudinaryException {
      rethrow;
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map && data['error'] is Map
          ? (data['error'] as Map)['message']
          : null;
      throw CloudinaryException(
        message is String && message.isNotEmpty
            ? 'Lỗi tải tệp lên: $message'
            : 'Lỗi tải tệp lên, vui lòng thử lại.',
      );
    } catch (_) {
      throw const CloudinaryException('Lỗi tải tệp lên, vui lòng thử lại.');
    }
  }
}

class CloudinaryException implements Exception {
  const CloudinaryException(this.message);
  final String message;
  @override
  String toString() => message;
}
