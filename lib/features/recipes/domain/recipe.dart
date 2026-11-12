import '../../../core/network/api_exception.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.authorName,
    this.categoryName,
    this.categoryId,
    this.mealTimeName,
    this.mealTimeId,
    this.courseTypeId,
    this.averageRating = 0,
    this.totalRatings = 0,
    this.viewCount = 0,
    this.recommendationScore,
    this.recommendationStrategy,
    this.recommendationReason,
  });

  final int id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? prepTime;
  final int? cookTime;
  final int? servings;
  final String? authorName;
  final String? categoryName;
  final int? categoryId;
  final String? mealTimeName;
  final int? mealTimeId;
  final int? courseTypeId;
  final double averageRating;
  final int totalRatings;
  final int viewCount;
  final double? recommendationScore;
  final String? recommendationStrategy;
  final String? recommendationReason;

  /// Total active cooking time when both halves are present.
  int? get totalMinutes {
    final prep = prepTime ?? 0;
    final cook = cookTime ?? 0;
    final total = prep + cook;
    return total > 0 ? total : null;
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final title = json['title'];
    if (id == null || title is! String || title.trim().isEmpty) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu công thức thiếu id hoặc title hợp lệ.',
      );
    }
    return Recipe(
      id: id,
      title: title,
      description: _asString(json['description']),
      imageUrl: _asString(json['image_url']),
      prepTime: _asInt(json['prep_time']),
      cookTime: _asInt(json['cook_time']),
      servings: _asInt(json['servings']),
      authorName: _asString(json['author_name']),
      categoryName: _asString(json['category_name']),
      categoryId: _asInt(json['category_id']),
      mealTimeName: _asString(json['meal_time_name']),
      mealTimeId: _asInt(json['meal_time_id']),
      courseTypeId: _asInt(json['course_type_id']),
      averageRating: _asDouble(json['avg_rating']) ?? 0,
      totalRatings: _asInt(json['total_ratings']) ?? 0,
      viewCount: _asInt(json['view_count']) ?? 0,
      recommendationScore: _asDouble(json['recommendation_score']),
      recommendationStrategy: _asString(json['recommendation_strategy']),
      recommendationReason: _asString(json['recommendation_reason']),
    );
  }

  /// Tolerant parsing for card payloads that may be partial or unknown shape;
  /// returns null instead of throwing.
  static Recipe? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return Recipe.fromJson(Map<String, dynamic>.from(raw));
    } on ApiException {
      return null;
    }
  }

  static String? _asString(Object? value) => value is String ? value : null;
  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}
