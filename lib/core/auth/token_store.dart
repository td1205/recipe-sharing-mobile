/// Boundary for encrypted/authenticated token persistence.
///
/// The app reads the Bearer token through `ApiClient` on every request, so the
/// store must be safe to call from multiple scopes. Replace with another
/// implementation by overriding `tokenStoreProvider`.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<void> writeAccessToken(String token);
  Future<void> deleteAccessToken();
}

/// Default store used before authentication is wired up and in tests.
class EmptyTokenStore implements TokenStore {
  const EmptyTokenStore();
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> deleteAccessToken() async {}
}

/// In-memory store for tests.
final class InMemoryTokenStore implements TokenStore {
  String? _token;
  @override
  Future<String?> readAccessToken() async => _token;
  @override
  Future<void> writeAccessToken(String token) {
    _token = token;
    return Future.value();
  }

  @override
  Future<void> deleteAccessToken() {
    _token = null;
    return Future.value();
  }
}
