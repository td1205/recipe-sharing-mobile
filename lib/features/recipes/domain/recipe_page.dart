import '../../../core/network/api_exception.dart';
import 'recipe.dart';
import 'category.dart';

class RecipePage {
  const RecipePage({
    required this.recipes,
    required this.total,
    required this.page,
    required this.limit,
    this.categories = const [],
  });
  final List<Recipe> recipes;
  final int total;
  final int page;
  final int limit;
  final List<RecipeCategory> categories;

  factory RecipePage.fromJson(Map<String, dynamic> json) {
    final rawRecipes = json['recipes'];
    if (rawRecipes is! List) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi thiếu danh sách recipes.',
      );
    }
    int readInt(String key) {
      final value = json[key];
      final parsed = value is num ? value.toInt() : int.tryParse('$value');
      if (parsed == null) {
        throw ApiException(
          ApiErrorKind.invalidResponse,
          'Trường $key không hợp lệ.',
        );
      }
      return parsed;
    }

    final rawCategories = json['categories'];
    return RecipePage(
      recipes: rawRecipes
          .map((item) {
            if (item is! Map) {
              throw const ApiException(
                ApiErrorKind.invalidResponse,
                'Một công thức không phải JSON object.',
              );
            }
            return Recipe.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
      total: readInt('total'),
      page: readInt('page'),
      limit: readInt('limit'),
      categories: rawCategories is List
          ? rawCategories
                .whereType<Map>()
                .map(
                  (item) =>
                      RecipeCategory.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}
