import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_sharing_mobile/app/theme/app_theme.dart';
import 'package:recipe_sharing_mobile/app/widgets/app_back_button.dart';
import 'package:recipe_sharing_mobile/app/widgets/app_error_banner.dart';

void main() {
  testWidgets('error banner uses high-contrast foreground colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppErrorBanner(message: 'Hệ thống AI đang quá tải.'),
        ),
      ),
    );

    final context = tester.element(find.byType(AppErrorBanner));
    final colors = Theme.of(context).colorScheme;
    final text = tester.widget<Text>(find.text('Hệ thống AI đang quá tải.'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));

    expect(text.style?.color, colors.onError);
    expect(icon.color, colors.onError);
    expect(colors.onError, Colors.white);
  });

  testWidgets('back button uses fallback for a directly opened screen', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Trang chủ')),
        GoRoute(
          path: '/login',
          builder: (_, _) => Scaffold(
            appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
  });
}
