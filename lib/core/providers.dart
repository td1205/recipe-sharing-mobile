import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/secure_token_store.dart';
import 'auth/token_store.dart';
import 'network/api_client.dart';

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => const SecureTokenStore(),
);

class AuthInvalidationController extends Notifier<int> {
  @override
  int build() => 0;

  void notifyUnauthorized() => state++;
}

final authInvalidationProvider =
    NotifierProvider<AuthInvalidationController, int>(
      AuthInvalidationController.new,
    );

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    onUnauthorized: () async =>
        ref.read(authInvalidationProvider.notifier).notifyUnauthorized(),
  ),
);
