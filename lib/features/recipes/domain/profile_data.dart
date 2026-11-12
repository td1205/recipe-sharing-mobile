import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_user.dart';
import 'recipe.dart';

/// Response of `GET /api/profile` — own profile with saved (favourite) and
/// authored recipes.
class OwnProfileData {
  const OwnProfileData({
    required this.user,
    required this.savedRecipes,
    required this.myRecipes,
  });

  final AuthUser user;
  final List<Recipe> savedRecipes;
  final List<Recipe> myRecipes;

  factory OwnProfileData.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi hồ sơ thiếu dữ liệu người dùng.',
      );
    }
    return OwnProfileData(
      user: AuthUser.fromJson(Map<String, dynamic>.from(user)),
      savedRecipes: _cards(json['favouriteRecipes']),
      myRecipes: _cards(json['myRecipes']),
    );
  }

  static List<Recipe> _cards(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Recipe.tryFromJson(Map<String, dynamic>.from(item)))
        .whereType<Recipe>()
        .toList(growable: false);
  }
}

/// Response of `GET /api/users/:id/profile?page=`.
class PublicProfilePage {
  const PublicProfilePage({
    required this.username,
    required this.fullname,
    required this.avatarUrl,
    required this.bio,
    required this.createdAt,
    required this.recipeCount,
    required this.favoritesReceived,
    required this.recipes,
    required this.page,
    required this.totalPages,
  });

  final String username;
  final String? fullname;
  final String? avatarUrl;
  final String? bio;
  final String? createdAt;
  final int recipeCount;
  final int favoritesReceived;
  final List<Recipe> recipes;
  final int page;
  final int totalPages;

  factory PublicProfilePage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final stats = json['stats'];
    final pageRaw = json['page'];
    final totalPagesRaw = json['totalPages'];
    if (user is! Map || user['username'] is! String) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi hồ sơ công khai không hợp lệ.',
      );
    }
    return PublicProfilePage(
      username: user['username'] as String,
      fullname: _string(user['fullname']),
      avatarUrl: _string(user['avatar_url']),
      bio: _string(user['bio']),
      createdAt: _string(user['created_at']),
      recipeCount: _int(_field(stats, 'recipeCount')),
      favoritesReceived: _int(_field(stats, 'favoritesReceived')),
      recipes: OwnProfileData._cards(json['recipes']),
      page: pageRaw is num ? pageRaw.toInt() : 1,
      totalPages: totalPagesRaw is num ? totalPagesRaw.toInt() : 1,
    );
  }

  static Object? _field(Map<String, dynamic>? json, String key) => json?[key];

  static String? _string(Object? value) => value is String ? value : null;

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
