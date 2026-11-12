import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_providers.dart';
import 'recipe_providers.dart';

/// Toggles the saved/favourite state of a recipe, prompting unauthenticated
/// users to log in first. Refreshes profile + detail data on success.
Future<bool> toggleRecipeFavourite(
  BuildContext context,
  WidgetRef ref, {
  required int recipeId,
  required bool makingFavourite,
}) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) {
    final goLogin = await showLoginRequiredDialog(context, 'lưu món ăn');
    if (goLogin && context.mounted) {
      context.go('/login?from=/saved');
    }
    return false;
  }
  try {
    final isFav = await ref
        .read(recipeRepositoryProvider)
        .setFavorite(recipeId, isFav: makingFavourite);
    ref.invalidate(ownProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isFav ? 'Đã lưu món ăn vào mục đã lưu.' : 'Đã bỏ lưu món ăn.',
            ),
          ),
        );
    }
    return isFav;
  } on ApiException catch (error) {
    if (error.kind == ApiErrorKind.unauthorized && context.mounted) {
      final goLogin = await showLoginRequiredDialog(context, 'lưu món ăn');
      if (goLogin && context.mounted) {
        context.go('/login?from=/saved');
      }
      return false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
    return false;
  }
}

Future<bool> showLoginRequiredDialog(
  BuildContext context,
  String featureName,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      title: const Text('Cần đăng nhập'),
      content: Text('Bạn cần đăng nhập để có thể $featureName.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Đăng nhập'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
  return result ?? false;
}
