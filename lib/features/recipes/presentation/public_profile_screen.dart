import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../domain/profile_data.dart';
import '../domain/recipe.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Someone else's cooking profile: `GET /api/users/:id/profile?page=`.
class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  int _pagesLoaded = 1;
  final _recipes = <Recipe>[];
  PublicProfilePage? _header;
  bool _endReached = false;
  bool _loadingMore = false;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(publicProfileProvider((widget.userId, 1)));
    return page.when(
      loading: () => const Scaffold(body: RecipeLoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackLocation: '/'),
          title: const Text('Hồ sơ'),
        ),
        body: RecipeErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(publicProfileProvider((widget.userId, 1))),
        ),
      ),
      data: (first) {
        if (_header == null || _header!.username != first.username) {
          _header = first;
          _recipes
            ..clear()
            ..addAll(first.recipes);
          _endReached = first.page >= first.totalPages;
          _pagesLoaded = 1;
        }
        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackLocation: '/'),
            title: Text('@${first.username}'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _header = null;
                _pagesLoaded = 1;
              });
              ref.invalidate(publicProfileProvider((widget.userId, 1)));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    AppSpacing.md,
                    20,
                    130,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _HeaderCard(page: first),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _PublicStatChip(
                            icon: Icons.menu_book_rounded,
                            label: 'Đã đăng ${first.recipeCount} món',
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _PublicStatChip(
                            icon: Icons.favorite_border_rounded,
                            label: '${first.favoritesReceived} lượt được lưu',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Công thức (${first.recipeCount})',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
                if (_recipes.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('Người này chưa đăng công thức nào.'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: _recipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _recipes[index];
                        return GridRecipeCard(
                          recipe: recipe,
                          onTap: () => context.pushNamed(
                            'recipe-detail',
                            pathParameters: {'id': '${recipe.id}'},
                          ),
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _PublicProfileFooter(
                    endReached: _endReached,
                    loadingMore: _loadingMore,
                    totalPages: first.totalPages,
                    onLoadMore: _loadMore,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _endReached) return;
    setState(() => _loadingMore = true);
    try {
      final next = await ref.read(
        publicProfileProvider((widget.userId, _pagesLoaded + 1)).future,
      );
      setState(() {
        _recipes.addAll(
          next.recipes.where(
            (recipe) => !_recipes.any((r) => r.id == recipe.id),
          ),
        );
        _pagesLoaded++;
        _endReached = next.page >= next.totalPages || next.recipes.isEmpty;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.page});
  final PublicProfilePage page;

  @override
  Widget build(BuildContext context) {
    final created = page.createdAt;
    final joinedLabel = () {
      if (created == null) return null;
      final parsed = DateTime.tryParse(created);
      if (parsed == null) return null;
      return 'Tham gia ${parsed.day}/${parsed.month}/${parsed.year}';
    }();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.limeSurface,
            child: ClipOval(
              child: SizedBox(
                width: 68,
                height: 68,
                child: AppNetworkImage(
                  url: page.avatarUrl,
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.fullname?.trim().isNotEmpty ?? false
                      ? page.fullname!
                      : page.username,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '@${page.username}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (joinedLabel != null)
                  Text(
                    joinedLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (page.bio?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(page.bio!, maxLines: 3),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicStatChip extends StatelessWidget {
  const _PublicStatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.limeSurface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.oliveSoft),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class _PublicProfileFooter extends StatelessWidget {
  const _PublicProfileFooter({
    required this.endReached,
    required this.loadingMore,
    required this.totalPages,
    required this.onLoadMore,
  });

  final bool endReached;
  final bool loadingMore;
  final int totalPages;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (endReached) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xl),
        child: Center(child: Text('Đã tải hết công thức')),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Center(
        child: TextButton(onPressed: onLoadMore, child: const Text('Xem thêm')),
      ),
    );
  }
}
