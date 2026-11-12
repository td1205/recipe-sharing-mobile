import 'category.dart';

/// Option lists for the recipe form: `GET /api/recipes/create` /
/// `GET /api/recipes/edit/:id` return categories, courseTypes and mealTimes.
class RecipeFormData {
  const RecipeFormData({
    this.categories = const [],
    this.courseTypes = const [],
    this.mealTimes = const [],
  });

  final List<RecipeCategory> categories;
  final List<RecipeCategory> courseTypes;
  final List<RecipeCategory> mealTimes;

  factory RecipeFormData.fromJson(
    Map<String, dynamic> json, {
    List<RecipeCategory> Function()? fallbackIds,
  }) {
    return RecipeFormData(
      categories: _options(json['categories']),
      courseTypes: _options(json['courseTypes'] ?? json['course_types']),
      mealTimes: _options(json['mealTimes'] ?? json['meal_times']),
    );
  }

  static List<RecipeCategory> _options(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final id = item['id'];
          final name = item['name'];
          if (id is! num || name is! String) return null;
          return RecipeCategory(id: id.toInt(), name: name);
        })
        .whereType<RecipeCategory>()
        .toList(growable: false);
  }
}
