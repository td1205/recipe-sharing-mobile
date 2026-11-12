import '../../../core/network/api_exception.dart';
import 'recipe.dart';
import 'recipe_comment.dart';
import 'recipe_tag.dart';

class RecipeIngredient {
  const RecipeIngredient({this.id, required this.name, this.amount, this.unit});
  final int? id;
  final String name;
  final String? amount;
  final String? unit;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu nguyên liệu không hợp lệ.',
      );
    }
    return RecipeIngredient(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : int.tryParse('${json['id']}'),
      name: name,
      amount: json['amount']?.toString(),
      unit: json['unit']?.toString(),
    );
  }

  String get quantity => [
    if (amount != null && amount!.trim().isNotEmpty) amount!.trim(),
    if (unit != null && unit!.trim().isNotEmpty) unit!.trim(),
  ].join(' ');
}

class RecipeStep {
  const RecipeStep({required this.number, required this.instruction});
  final int number;
  final String instruction;

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    final rawNumber = json['step_number'];
    final number = rawNumber is num
        ? rawNumber.toInt()
        : int.tryParse('$rawNumber');
    final instruction = json['instruction'];
    if (number == null ||
        instruction is! String ||
        instruction.trim().isEmpty) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu bước chế biến không hợp lệ.',
      );
    }
    return RecipeStep(number: number, instruction: instruction);
  }
}

class RecipeDetail {
  const RecipeDetail({
    required this.recipe,
    required this.ingredients,
    required this.steps,
    required this.id,
    required this.authorUserId,
    this.authorUsername,
    this.authorFullname,
    this.authorAvatarUrl,
    this.comments = const [],
    this.relatedRecipes = const [],
    this.tags = const [],
    this.isFavourite = false,
    this.userRating,
  });

  final int id;
  final Recipe recipe;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  /// Author of the recipe (`recipe.users` nested object).
  final int? authorUserId;
  final String? authorUsername;
  final String? authorFullname;
  final String? authorAvatarUrl;

  final List<RecipeComment> comments;
  final List<Recipe> relatedRecipes;
  final List<RecipeTag> tags;

  /// Saved state of the current viewer; always false for guests.
  final bool isFavourite;

  /// Star rating of the current viewer: `{"star_count": 4}` or null.
  final int? userRating;

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    final rawRecipe = json['recipe'];
    final rawIngredients = json['ingredients'];
    final rawSteps = json['steps'];
    if (rawRecipe is! Map || rawIngredients is! List || rawSteps is! List) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi chi tiết công thức không hợp lệ.',
      );
    }
    final recipeJson = Map<String, dynamic>.from(rawRecipe);
    final recipe = Recipe.fromJson(recipeJson);
    final maybeId = _int(rawRecipe['id']) ?? recipe.id;
    final users = rawRecipe['users'] is Map
        ? Map<String, dynamic>.from(rawRecipe['users'] as Map)
        : null;

    // `rating: {averageRating, totalRatings}` uses camelCase (backend
    // inconsistency); prefer it when present.
    final rating = json['rating'] is Map
        ? Map<String, dynamic>.from(json['rating'] as Map)
        : null;
    final average = _double(rating?['averageRating']);
    final count = _int(rating?['totalRatings']);
    final parsedRecipe = average == null && count == null
        ? recipe
        : Recipe(
            id: recipe.id,
            title: recipe.title,
            description: recipe.description,
            imageUrl: recipe.imageUrl,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            servings: recipe.servings,
            authorName: recipe.authorName,
            categoryName: recipe.categoryName,
            categoryId: recipe.categoryId,
            mealTimeId: recipe.mealTimeId,
            courseTypeId: recipe.courseTypeId,
            mealTimeName: recipe.mealTimeName,
            averageRating: average ?? recipe.averageRating,
            totalRatings: count ?? recipe.totalRatings,
            viewCount: recipe.viewCount,
          );

    return RecipeDetail(
      id: maybeId,
      recipe: parsedRecipe,
      ingredients: rawIngredients
          .whereType<Map>()
          .map(
            (item) =>
                RecipeIngredient.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      steps: rawSteps
          .whereType<Map>()
          .map((item) => RecipeStep.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      authorUserId: _int(recipeJson['user_id']) ?? _int(users?['id']),
      authorUsername:
          _string(recipeJson['author_name']) ?? _string(users?['username']),
      authorFullname: _string(users?['fullname']),
      authorAvatarUrl: _string(users?['avatar_url']),
      comments: _list(json['comments'], RecipeComment.tryFromJson),
      relatedRecipes: _list(json['relatedRecipes'], Recipe.tryFromJson),
      tags: _list(json['tags'], RecipeTag.tryFromJson),
      isFavourite: json['isFav'] == true,
      userRating: _int(_field(json['userRating'], 'star_count')),
    );
  }

  static Object? _field(Object? json, String key) =>
      json is Map ? json[key] : null;

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static List<T> _list<T>(Object? raw, T? Function(Object?) parse) {
    if (raw is! List) return const [];
    return raw.map(parse).whereType<T>().toList(growable: false);
  }
}
