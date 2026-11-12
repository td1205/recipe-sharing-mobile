import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../core/network/api_exception.dart';
import 'recipe_providers.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Authored recipes of the signed-in user with delete affordances.
class MyRecipesScreen extends ConsumerStatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  ConsumerState<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends ConsumerState<MyRecipesScreen> {
  final _busyRecipeIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownProfileProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/profile'),
        title: const Text('Công thức của tôi'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: profile.when(
        loading: () => const RecipeLoadingView(),
        error: (error, _) => RecipeErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
        data: (data) {
          final recipes = data.myRecipes;
          if (recipes.isEmpty) {
            return RecipeEmptyView(
              title: 'Chưa có công thức nào',
              message: 'Đăng món ăn đầu tiên để chia sẻ với cộng đồng.',
              icon: Icons.menu_book_rounded,
              onAction: () => context.push('/recipes/create'),
              actionLabel: 'Đăng công thức mới',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownProfileProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final busy = _busyRecipeIds.contains(recipe.id);
                      return GridRecipeCard(
                        recipe: recipe,
                        onTap: () => context.pushNamed(
                          'recipe-detail',
                          pathParameters: {'id': '${recipe.id}'},
                        ),
                        trailing: _RecipeActions(
                          recipeId: recipe.id,
                          busy: busy,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecipeActions extends ConsumerWidget {
  const _RecipeActions({required this.recipeId, required this.busy});

  final int recipeId;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: AppColors.white.withValues(alpha: 0.92),
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: PopupMenuButton<_Action>(
      padding: EdgeInsets.zero,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert_rounded, size: 18),
      onSelected: (action) async {
        if (action == _Action.edit) {
          await context.push('/recipes/$recipeId/edit');
          ref.invalidate(ownProfileProvider);
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Xoá công thức?'),
            content: const Text('Công thức sẽ bị xoá vĩnh viễn.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Xoá'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        try {
          await ref.read(recipeRepositoryProvider).deleteRecipe(recipeId);
          ref.invalidate(ownProfileProvider);
          ref.invalidate(homeProvider);
          ref.invalidate(exploreProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Đã xoá công thức.')),
              );
          }
        } on ApiException catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error.message)));
          }
        }
      },
      itemBuilder: (menuContext) => const [
        PopupMenuItem(
          value: _Action.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.edit_rounded),
            title: Text('Chỉnh sửa'),
          ),
        ),
        PopupMenuItem(
          value: _Action.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Xoá'),
          ),
        ),
      ],
    ),
  );
}

enum _Action { edit, delete }
