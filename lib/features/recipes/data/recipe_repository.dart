import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/profile_data.dart';
import '../domain/recipe.dart';
import '../domain/recipe_detail.dart';
import '../domain/recipe_filter.dart';
import '../domain/recipe_form_data.dart';
import '../domain/recipe_page.dart';
import '../domain/recommendation_feed.dart';
import '../domain/home_data.dart';
import '../domain/image_scan_result.dart';

class RecipeRepository {
  const RecipeRepository(this._client);
  final ApiClient _client;

  static const maxScanImageBytes = 5 * 1024 * 1024;
  static const scanImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  // ---------------------------------------------------------------------------
  // Listing
  // ---------------------------------------------------------------------------

  /// `GET /api/recipes?page&limit` with filters, sort and server pagination.
  Future<RecipePage> getRecipes({
    RecipeFilter filter = const RecipeFilter(),
    int page = 1,
    int limit = 12,
  }) async {
    final json = await _client.getJson(
      '/api/recipes',
      queryParameters: filter.toQuery(page: page, limit: limit),
    );
    return RecipePage.fromJson(json);
  }

  Future<HomeData> getHomeData() async {
    final pages = await Future.wait([
      getRecipes(
        filter: const RecipeFilter().copyWith(sort: RecipeSort.popular),
        page: 1,
        limit: 8,
      ),
      getRecipes(
        filter: const RecipeFilter().copyWith(sort: RecipeSort.newest),
        page: 1,
        limit: 12,
      ),
    ]);
    return HomeData(
      featured: pages[0].recipes,
      latest: pages[1].recipes,
      categories: pages[1].categories,
    );
  }

  /// `GET /api/nav-data` — public option lists (categories, meal times,
  /// course types) for filter sheets and forms.
  Future<RecipeFormData> getNavData() async {
    final json = await _client.getJson('/api/nav-data');
    return RecipeFormData.fromJson(json);
  }

  Future<RecipeDetail> getRecipeDetail(int id) async {
    final json = await _client.getJson('/api/recipes/$id');
    return RecipeDetail.fromJson(json);
  }

  /// `GET /api/recipes/suggest?q=` — typeahead titles.
  Future<List<Recipe>> getSuggestions(String query) async {
    if (query.trim().isEmpty) return const [];
    final json = await _client.getJson(
      '/api/recipes/suggest',
      queryParameters: {'q': query.trim()},
    );
    final suggestions = json['suggestions'];
    if (suggestions is! List) return const [];
    return suggestions
        .whereType<Map>()
        .map((item) => Recipe.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Recipe>()
        .toList(growable: false);
  }

  /// `GET /api/recipes/popular?period=` — period: all | month | week.
  Future<RecipePage> getPopular({String period = 'month'}) async {
    final json = await _client.getJson(
      '/api/recipes/popular',
      queryParameters: {'limit': 36, 'period': period},
    );
    final recipes = json['recipes'] is List
        ? json['recipes'] as List
        : const [];
    final cards = recipes
        .whereType<Map>()
        .map((item) => Recipe.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Recipe>()
        .toList(growable: false);
    return RecipePage(
      recipes: cards,
      total: cards.length,
      page: 1,
      limit: cards.length,
    );
  }

  /// `GET /api/recommendations/by-ingredients?items=` — cook with what you
  /// have. Returns matched recipes plus the matched ingredient names.
  Future<RecipePage> getByIngredients({
    required List<String> ingredients,
  }) async {
    final json = await _client.getJson(
      '/api/recommendations/by-ingredients',
      queryParameters: {'items': ingredients.take(15).join(','), 'limit': 24},
    );
    final recipes = json['recipes'] is List
        ? json['recipes'] as List
        : const [];
    final cards = recipes
        .whereType<Map>()
        .map((item) => Recipe.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Recipe>()
        .toList(growable: false);
    return RecipePage(
      recipes: cards,
      total: json['total'] is num
          ? (json['total'] as num).toInt()
          : cards.length,
      page: 1,
      limit: cards.length,
    );
  }

  /// Personalized cards and the server's explanation of the active strategy.
  /// Both endpoints derive the user from the Bearer-hydrated backend session.
  Future<RecommendationFeed> getPersonalizedRecommendations({
    int limit = 8,
  }) async {
    final responses = await Future.wait([
      _client.getJson(
        '/api/recommendations/for-me',
        queryParameters: {'limit': limit},
      ),
      _client.getJson('/api/recommendations/explain'),
    ]);
    final rawRecipes = responses[0]['recipes'];
    if (rawRecipes is! List) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi gợi ý thiếu danh sách công thức.',
      );
    }
    final recipes = rawRecipes
        .map(Recipe.tryFromJson)
        .whereType<Recipe>()
        .toList(growable: false);
    if (recipes.length != rawRecipes.length) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Danh sách công thức gợi ý có dữ liệu không hợp lệ.',
      );
    }
    return RecommendationFeed(
      recipes: recipes,
      explanation: RecommendationExplanation.fromJson(responses[1]),
    );
  }

  /// `POST /api/ai/scan-image` with multipart field `image`.
  Future<ImageScanResult> scanDishImage({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Ảnh đã chọn không có dữ liệu.',
      );
    }
    if (bytes.length > maxScanImageBytes) {
      throw const ApiException(ApiErrorKind.invalidResponse, 'Ảnh tối đa 5MB.');
    }
    if (!scanImageMimeTypes.contains(mimeType)) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Chỉ chấp nhận ảnh JPG, PNG, WEBP hoặc HEIC.',
      );
    }
    final json = await _client.uploadMultipart(
      '/api/ai/scan-image',
      file: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mimeType),
      ),
      fileFieldName: 'image',
      receiveTimeout: const Duration(seconds: 40),
    );
    return ImageScanResult.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Form data + create/edit/delete
  // ---------------------------------------------------------------------------

  /// `GET /api/recipes/create` — option lists for the form.
  Future<RecipeFormData> getFormData() async {
    final json = await _client.getJson('/api/recipes/create');
    return RecipeFormData.fromJson(json);
  }

  /// `GET /api/recipes/edit/:id` — recipe payload + option lists.
  Future<(RecipeDetail, RecipeFormData)> getEditData(int id) async {
    final json = await _client.getJson('/api/recipes/edit/$id');
    final detail = RecipeDetail.fromJson(json);
    final formData = RecipeFormData.fromJson(json);
    return (detail, formData);
  }

  /// `POST /api/recipes/create` — plain JSON (images are uploaded to
  /// Cloudinary first).
  Future<int> createRecipe(Map<String, Object?> payload) async {
    final json = await _client.postJson('/api/recipes/create', data: payload);
    final recipeId = json['recipeId'];
    final id = recipeId is num ? recipeId.toInt() : int.tryParse('$recipeId');
    if (id == null) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi tạo công thức thiếu recipeId.',
      );
    }
    return id;
  }

  Future<void> updateRecipe(int id, Map<String, Object?> payload) =>
      _client.postJson('/api/recipes/edit/$id', data: payload);

  Future<void> deleteRecipe(int id) =>
      _client.postJson('/api/recipes/delete/$id');

  // ---------------------------------------------------------------------------
  // Interactions
  // ---------------------------------------------------------------------------

  Future<void> addComment(int recipeId, String content) => _client.postJson(
    '/api/recipes/$recipeId/comments',
    data: {'content': content},
  );

  Future<(double average, int total)> rateRecipe(
    int recipeId,
    int starCount,
  ) async {
    final json = await _client.postJson(
      '/api/recipes/$recipeId/rate',
      data: {'star_count': starCount},
    );
    final average = json['newRating'];
    final total = json['newCount'];
    final parsedAverage = average is num ? average.toDouble() : null;
    final parsedTotal = total is num ? total.toInt() : null;
    if (parsedAverage == null || parsedTotal == null) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi đánh giá không hợp lệ.',
      );
    }
    return (parsedAverage, parsedTotal);
  }

  /// `POST /api/recipes/:id/favorite` with `{isFav}` — omitted body toggles.
  Future<bool> setFavorite(int recipeId, {bool? isFav}) async {
    final json = await _client.postJson(
      '/api/recipes/$recipeId/favorite',
      data: isFav == null ? null : {'isFav': isFav},
    );
    return json['isFav'] is bool ? json['isFav'] as bool : isFav ?? true;
  }

  Future<Set<int>> getShoppingList(int recipeId) async {
    final json = await _client.getJson('/api/recipes/$recipeId/shopping-list');
    final raw = json['checkedIngredientIds'];
    return raw is List
        ? raw
              .map((id) => id is num ? id.toInt() : int.tryParse('$id'))
              .whereType<int>()
              .toSet()
        : <int>{};
  }

  Future<void> setShoppingListItem(
    int recipeId,
    int ingredientId,
    bool checked,
  ) => _client.postJson(
    '/api/recipes/$recipeId/shopping-list/$ingredientId',
    data: {'checked': checked},
  );

  Future<void> setShoppingListServings(int recipeId, int servings) =>
      _client.postJson(
        '/api/recipes/$recipeId/shopping-list/servings',
        data: {'servings': servings},
      );

  /// View tracking — fired once after a dwell time on the detail page.
  Future<void> markViewed(int recipeId) =>
      _client.postJson('/api/recipes/$recipeId/view');

  /// Community tag vote/unvote.
  Future<bool> voteTag(int recipeId, String tagName) async {
    final json = await _client.postJson(
      '/api/recipes/$recipeId/tags',
      data: {'tagName': tagName},
    );
    final isAdded = json['isAdded'];
    if (isAdded is! bool) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi bình chọn tag không hợp lệ.',
      );
    }
    return isAdded;
  }

  Future<void> createReport({
    required String targetType,
    required int targetId,
    required String reason,
  }) => _client.postJson(
    '/api/reports',
    data: {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason.trim(),
    },
  );

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<OwnProfileData> getOwnProfile() async {
    final json = await _client.getJson('/api/profile');
    return OwnProfileData.fromJson(json);
  }

  Future<PublicProfilePage> getPublicProfile(int userId, {int page = 1}) async {
    final json = await _client.getJson(
      '/api/users/$userId/profile',
      queryParameters: {'page': page},
    );
    return PublicProfilePage.fromJson(json);
  }

  /// `GET /api/recipe-cards?ids=1,2` — refresh arbitrary card sets.
  Future<List<Recipe>> getRecipeCards(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final json = await _client.getJson(
      '/api/recipe-cards',
      queryParameters: {'ids': ids.join(',')},
    );
    final cards = json['recipes'] is List
        ? json['recipes'] as List
        : json['cards'] is List
        ? json['cards'] as List
        : const [];
    return cards
        .whereType<Map>()
        .map((item) => Recipe.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Recipe>()
        .toList(growable: false);
  }

  /// Multipart avatar file helper for the profile editor.
  static MultipartFile avatarFileFromBytes({
    required List<int> bytes,
    required String filename,
    String contentType = 'image/jpeg',
  }) => MultipartFile.fromBytes(
    bytes,
    filename: filename,
    contentType: DioMediaType.parse(contentType),
  );
}
