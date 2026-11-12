import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_user.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final ApiClient _client;

  /// `POST /api/auth/token` → `{success, token, expiresAt, user}`.
  /// The backend issues a single opaque Bearer token (no refresh token);
  /// user data from this response may be minimal, callers should hydrate via
  /// `me()` after persisting the token.
  Future<({String token, AuthUser? user})> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final json = await _client.postJson(
      '/api/auth/token',
      data: {'username': username, 'password': password, 'remember': remember},
    );
    final token = json['token'];
    if (token is String && token.isNotEmpty) {
      final rawUser = json['user'];
      final user = rawUser is Map
          ? AuthUser.tryParseUser(Map<String, dynamic>.from(rawUser))
          : null;
      return (token: token, user: user);
    }
    throw const ApiException(
      ApiErrorKind.invalidResponse,
      'Phản hồi đăng nhập không hợp lệ.',
    );
  }

  /// `GET /api/auth/me` → `{success, user}` (SAFE_USER_SELECT).
  Future<AuthUser> me() async {
    final json = await _client.getJson('/api/auth/me');
    final user = json['user'];
    if (user is! Map) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi thiếu dữ liệu người dùng.',
      );
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(user));
  }

  /// `POST /api/logout` revokes the current server-side Bearer session.
  Future<void> logout() => _client.postJson('/api/logout');

  /// `POST /api/register` → `{success, message}` (no session is created).
  Future<void> register({
    required String username,
    required String email,
    required String fullname,
    required String password,
    required String confirmPassword,
  }) => _client.postJson(
    '/api/register',
    data: {
      'username': username,
      'email': email,
      'fullname': fullname,
      'password': password,
      'confirm_password': confirmPassword,
    },
  );

  Future<String?> requestPasswordResetOtp({
    required String email,
    String? sessionCookie,
  }) async {
    final response = await _client.postJsonWithSession(
      '/api/forgot-password',
      data: {'email': email},
      cookie: sessionCookie,
    );
    return response.cookie;
  }

  Future<String?> verifyPasswordResetOtp({
    required String otp,
    required String sessionCookie,
  }) async {
    final response = await _client.postJsonWithSession(
      '/api/otp',
      data: {'otp': otp},
      cookie: sessionCookie,
    );
    return response.cookie;
  }

  Future<void> changeForgottenPassword({
    required String password,
    required String confirmPassword,
    required String sessionCookie,
  }) async {
    await _client.postJsonWithSession(
      '/api/change-password',
      data: {'password': password, 'confirm_password': confirmPassword},
      cookie: sessionCookie,
    );
  }

  /// `POST /api/profile/edit` — multipart with optional `avatar` file plus
  /// fullname/email/bio. Returns the updated SAFE_USER_SELECT object.
  Future<AuthUser> updateProfile({
    required String fullname,
    required String email,
    required String bio,
    MultipartFile? avatarFile,
  }) async {
    final json = avatarFile == null
        ? await _client.postJson(
            '/api/profile/edit',
            data: {'fullname': fullname, 'email': email, 'bio': bio},
          )
        : await _client.uploadMultipart(
            '/api/profile/edit',
            file: avatarFile,
            fileFieldName: 'avatar',
            fields: {'fullname': fullname, 'email': email, 'bio': bio},
          );
    final user = json['user'];
    if (user is! Map) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Phản hồi cập nhật hồ sơ không chứa người dùng.',
      );
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(user));
  }
}
