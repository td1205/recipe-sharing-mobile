import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// Session state: resolved states are `AuthUser` (logged in) or `null`.
/// While the first `build()` check is still running the state is loading.
class AuthController extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    ref.listen<int>(authInvalidationProvider, (previous, next) {
      if (previous != null && next > previous) {
        state = const AsyncData<AuthUser?>(null);
      }
    });
    final token = await ref.watch(tokenStoreProvider).readAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      return await ref.watch(authRepositoryProvider).me();
    } on ApiException catch (error) {
      // Invalid/expired tokens act like being logged out.
      if (error.kind == ApiErrorKind.unauthorized) {
        await ref.read(tokenStoreProvider).deleteAccessToken();
        return null;
      }
      rethrow;
    }
  }

  Future<AuthUser> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.login(
      username: username,
      password: password,
      remember: remember,
    );
    await ref.read(tokenStoreProvider).writeAccessToken(result.token);
    final hydrated = result.user ?? await repository.me();
    state = AsyncData<AuthUser?>(hydrated);
    return hydrated;
  }

  Future<void> register({
    required String username,
    required String email,
    required String fullname,
    required String password,
    required String confirmPassword,
  }) => ref
      .read(authRepositoryProvider)
      .register(
        username: username,
        email: email,
        fullname: fullname,
        password: password,
        confirmPassword: confirmPassword,
      );

  Future<bool> logout() async {
    var revoked = false;
    try {
      await ref.read(authRepositoryProvider).logout();
      revoked = true;
    } on ApiException {
      // Local credentials must still be removed when the network is unavailable.
    } finally {
      await ref.read(tokenStoreProvider).deleteAccessToken();
      state = const AsyncData<AuthUser?>(null);
    }
    return revoked;
  }

  Future<void> updateProfile({
    required String fullname,
    required String email,
    required String bio,
    MultipartFile? avatarFile,
  }) async {
    final updated = await ref
        .read(authRepositoryProvider)
        .updateProfile(
          fullname: fullname,
          email: email,
          bio: bio,
          avatarFile: avatarFile,
        );
    state = AsyncData<AuthUser?>(updated);
  }
}

final authStateProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);
