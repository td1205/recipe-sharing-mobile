import '../../../core/network/api_exception.dart';

class RecipeCategory {
  const RecipeCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory RecipeCategory.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
    final name = json['name'];
    if (id == null || name is! String || name.trim().isEmpty) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu danh mục không hợp lệ.',
      );
    }
    return RecipeCategory(id: id, name: name);
  }
}
