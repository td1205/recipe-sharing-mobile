import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_sharing_mobile/app/theme/app_theme.dart';
import 'package:recipe_sharing_mobile/core/network/api_client.dart';
import 'package:recipe_sharing_mobile/features/auth/data/auth_repository.dart';
import 'package:recipe_sharing_mobile/features/auth/presentation/auth_providers.dart';
import 'package:recipe_sharing_mobile/features/auth/presentation/forgot_password_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(dio: Dio()));

  @override
  Future<String?> requestPasswordResetOtp({
    required String email,
    String? sessionCookie,
  }) async => 'connect.sid=test-session';

  @override
  Future<String?> verifyPasswordResetOtp({
    required String otp,
    required String sessionCookie,
  }) async => sessionCookie;

  @override
  Future<void> changeForgottenPassword({
    required String password,
    required String confirmPassword,
    required String sessionCookie,
  }) async {}
}

void main() {
  testWidgets('completes email, OTP and new-password flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ForgotPasswordScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('reset-email')),
      'demo@example.com',
    );
    await tester.tap(find.byKey(const Key('password-reset-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-otp')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-otp')), '123456');
    await tester.tap(find.byKey(const Key('password-reset-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-password')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reset-password')),
      'MatKhauMoi123!',
    );
    await tester.enterText(
      find.byKey(const Key('reset-confirmation')),
      'MatKhauMoi123!',
    );
    await tester.tap(find.byKey(const Key('password-reset-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu thành công'), findsOneWidget);
    expect(find.byKey(const Key('password-reset-login')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
