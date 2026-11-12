import '../../../core/network/api_exception.dart';

class RecipeComment {
  const RecipeComment({
    required this.id,
    required this.userId,
    required this.content,
    this.username,
    this.authorFullname,
    this.avatarUrl,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String content;
  final String? username;
  final String? authorFullname;
  final String? avatarUrl;
  final String? createdAt;

  String get authorDisplayName {
    final name = authorFullname?.trim();
    return (name == null || name.isEmpty) ? (username ?? 'Người dùng') : name;
  }

  factory RecipeComment.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final content = json['content'];
    if (id == null || content is! String) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu bình luận không hợp lệ.',
      );
    }
    final users = json['users'];
    final fallbackUser = json['user'];
    final userNameMap = users is Map
        ? Map<String, dynamic>.from(users)
        : fallbackUser is Map
        ? Map<String, dynamic>.from(fallbackUser)
        : null;
    final userId = _asInt(json['user_id']) ?? _asInt(userNameMap?['id']) ?? 0;
    return RecipeComment(
      id: id,
      userId: userId,
      content: content,
      username:
          _asString(json['username']) ?? _asString(userNameMap?['username']),
      authorFullname: _asString(userNameMap?['fullname']),
      avatarUrl: _asString(userNameMap?['avatar_url']),
      createdAt: _asString(json['created_at']),
    );
  }

  static String? _asString(Object? value) => value is String ? value : null;
  static int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  static RecipeComment? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return RecipeComment.fromJson(Map<String, dynamic>.from(raw));
    } on ApiException {
      return null;
    }
  }
}
