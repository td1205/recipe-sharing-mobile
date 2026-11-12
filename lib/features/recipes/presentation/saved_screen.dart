import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/recipe.dart';
import 'recipe_providers.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Recipe box: saved (favourite) recipes from `GET /api/profile`.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _busyRecipeIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(ownProfileProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mục đã lưu'),
      ),
      body: auth.when(
        loading: () => const RecipeLoadingView(),
        error: (error, _) => RecipeErrorView(
          message: 'Lỗi phiên đăng nhập: $error',
          onRetry: () => ref.invalidate(authStateProvider),
        ),
        data: (user) {
          if (user == null) {
            return RecipeEmptyView(
              title: 'Chưa đăng nhập',
              message: 'Đăng nhập để xem danh sách món ăn bạn đã lưu.',
              icon: Icons.bookmark_border_rounded,
              onAction: () => context.go('/login?from=/saved'),
              actionLabel: 'Đăng nhập',
            );
          }
          return profile.when(
            loading: () => const RecipeLoadingView(),
            error: (error, _) => RecipeErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(ownProfileProvider),
            ),
            data: (data) {
              final saved = data.savedRecipes;
              if (saved.isEmpty) {
                return RecipeEmptyView(
                  title: 'Mục đã lưu trống',
                  message: 'Lưu các món bạn thích để nấu lại dễ dàng hơn.',
                  icon: Icons.bookmark_border_rounded,
                  onAction: () => context.go('/explore'),
                  actionLabel: 'Khám phá món ăn',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(ownProfileProvider),
                child: CustomScrollView(
                  key: const Key('saved-scroll'),
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
                        itemCount: saved.length,
                        itemBuilder: (context, index) => _SavedCard(
                          recipe: saved[index],
                          busy: _busyRecipeIds.contains(saved[index].id),
                          onTap: () => context.pushNamed(
                            'recipe-detail',
                            pathParameters: {'id': '${saved[index].id}'},
                          ),
                          onRemove: () => _remove(saved[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _remove(Recipe recipe) async {
    if (_busyRecipeIds.contains(recipe.id)) return;
    setState(() => _busyRecipeIds.add(recipe.id));
    try {
      await ref
          .read(recipeRepositoryProvider)
          .setFavorite(recipe.id, isFav: false);
      ref.invalidate(ownProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Đã bỏ lưu "${recipe.title}".')),
          );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyRecipeIds.remove(recipe.id));
    }
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.recipe,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  final Recipe recipe;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => GridRecipeCard(
    recipe: recipe,
    onTap: onTap,
    isFavourite: true,
    favouriteBusy: busy,
    onToggleFavourite: (_) => onRemove(),
  );
}
