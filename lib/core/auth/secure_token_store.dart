import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// Persists the Bearer token in platform-protected storage
/// (Keychain on iOS/macOS, encrypted storage backed by Keystore on Android).
final class SecureTokenStore implements TokenStore {
  const SecureTokenStore();

  static const _key = 'auth.bearer_token';
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  @override
  Future<String?> readAccessToken() => _storage.read(key: _key);

  @override
  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> deleteAccessToken() => _storage.delete(key: _key);
}
