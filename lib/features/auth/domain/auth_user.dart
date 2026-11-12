import '../../../core/config/api_config.dart';
import '../../../core/network/api_exception.dart';

/// Authenticated user as returned by `/api/auth/me` (SAFE_USER_SELECT).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.fullname,
    this.email,
    this.role = 'user',
    this.bio,
    this.avatarUrl,
    this.createdAt,
  });

  final int id;
  final String username;
  final String? fullname;
  final String? email;
  final String role;
  final String? bio;
  final String? avatarUrl;
  final String? createdAt;

  bool get isAdmin => role == 'admin';

  String get displayName {
    final name = fullname?.trim();
    return (name == null || name.isEmpty) ? username : name;
  }

  String? get avatar => avatarUrl == null ? null : ImageUrl.resolve(avatarUrl);

  /// Null-safe parse for payloads (like `/api/auth/token`) that may return
  /// a minimal user object.
  static AuthUser? tryParseUser(Map<String, dynamic> json) {
    try {
      return AuthUser.fromJson(json);
    } on ApiException {
      return null;
    }
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final username = json['username'];
    if (id is! num || username is! String) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Dữ liệu người dùng không hợp lệ.',
      );
    }
    return AuthUser(
      id: id.toInt(),
      username: username,
      fullname: _string(json['fullname']),
      email: _string(json['email']),
      role: _string(json['role']) ?? 'user',
      bio: _string(json['bio']),
      avatarUrl: _string(json['avatar_url']),
      createdAt: _string(json['created_at']),
    );
  }

  static String? _string(Object? value) => value is String ? value : null;
}
