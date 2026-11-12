import '../../../core/network/api_exception.dart';
import 'recipe.dart';

class RecommendationFeed {
  const RecommendationFeed({required this.recipes, required this.explanation});

  final List<Recipe> recipes;
  final RecommendationExplanation explanation;
}

class RecommendationExplanation {
  const RecommendationExplanation({
    required this.interactedRecipes,
    required this.strategy,
    required this.modelRecipeCount,
    required this.usersWithHistory,
    required this.modelBuiltAt,
  });

  final int interactedRecipes;
  final String strategy;
  final int modelRecipeCount;
  final int usersWithHistory;
  final DateTime? modelBuiltAt;

  String get summary => switch (strategy) {
    'hybrid' => 'Kết hợp sở thích của bạn với những người có khẩu vị tương tự.',
    'content' => 'Dựa trên đặc điểm của những công thức bạn đã quan tâm.',
    'cf' => 'Dựa trên lựa chọn của những người có khẩu vị tương tự bạn.',
    _ => 'Dựa trên những công thức đang được cộng đồng yêu thích.',
  };

  factory RecommendationExplanation.fromJson(Map<String, dynamic> json) {
    final interactedRecipes = _asInt(json['interactedRecipes']);
    final strategy = json['strategy'];
    final model = json['model'];
    if (interactedRecipes == null || strategy is! String || model is! Map) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi giải thích gợi ý không hợp lệ.',
      );
    }
    final modelJson = Map<String, dynamic>.from(model);
    final recipeCount = _asInt(modelJson['recipes']);
    final usersWithHistory = _asInt(modelJson['usersWithHistory']);
    if (recipeCount == null || usersWithHistory == null) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi mô hình gợi ý không hợp lệ.',
      );
    }
    return RecommendationExplanation(
      interactedRecipes: interactedRecipes,
      strategy: strategy,
      modelRecipeCount: recipeCount,
      usersWithHistory: usersWithHistory,
      modelBuiltAt: DateTime.tryParse('${modelJson['builtAt'] ?? ''}'),
    );
  }

  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');
}
