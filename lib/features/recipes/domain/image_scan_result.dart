import '../../../core/network/api_exception.dart';

class ImageScanResult {
  const ImageScanResult({required this.keyword});

  final String keyword;

  factory ImageScanResult.fromJson(Map<String, dynamic> json) {
    final keyword = json['keyword'];
    if (keyword is! String || keyword.trim().isEmpty || keyword.length > 60) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi nhận diện ảnh thiếu tên món hợp lệ.',
      );
    }
    return ImageScanResult(keyword: keyword.trim());
  }
}
