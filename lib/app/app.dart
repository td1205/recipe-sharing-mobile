import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../features/recipes/application/cooking_sync_controller.dart';

class RecipeSharingApp extends ConsumerStatefulWidget {
  const RecipeSharingApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<RecipeSharingApp> createState() => _RecipeSharingAppState();
}

class _RecipeSharingAppState extends ConsumerState<RecipeSharingApp> {
  @override
  Widget build(BuildContext context) {
    final GoRouter activeRouter = widget.router ?? ref.watch(appRouterProvider);
    ref.watch(cookingSyncProvider);
    ref.listen<int?>(cookingSyncProvider, (_, recipeId) {
      if (recipeId == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final dialogContext = appNavigatorKey.currentContext;
        if (dialogContext == null) return;
        final shouldOpen = await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Mở công thức này?'),
            content: const Text(
              'Một thiết bị khác đã gửi cho bạn một công thức.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Mở'),
              ),
            ],
          ),
        );
        ref.read(cookingSyncProvider.notifier).dismiss();
        if (shouldOpen == true && mounted) {
          activeRouter.pushNamed(
            'recipe-detail',
            pathParameters: {'id': '$recipeId'},
          );
        }
      });
    });
    return MaterialApp.router(
      title: 'Recipe Sharing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: activeRouter,
    );
  }
}
