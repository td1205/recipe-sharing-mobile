import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/category.dart' show RecipeCategory;
import '../domain/home_data.dart';
import '../domain/recommendation_feed.dart';
import '../domain/recipe.dart';
import 'favourite_actions.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Home dashboard: greeting, quick search, categories, featured + latest.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  int? _selectedCategoryId;
  final _busyRecipeIds = <int>{};
  final _favouriteByRecipe = <int, bool>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final user = ref.watch(authStateProvider).asData?.value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: state.when(
          loading: () => const RecipeLoadingView(),
          error: (error, stackTrace) => RecipeErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(homeProvider),
          ),
          data: (data) => _buildContent(context, data, user),
        ),
      ),
      extendBody: true,
    );
  }

  Widget _buildContent(BuildContext context, HomeData data, AuthUser? user) {
    final featured = data.featured;
    final latest = data.latest;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(homeProvider.future),
      child: CustomScrollView(
        key: const Key('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 124),
            sliver: SliverList.list(
              children: [
                _HomeHeader(fullname: user?.displayName, avatar: user?.avatar),
                const SizedBox(height: AppSpacing.mdLg),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: AppShadows.soft,
                  ),
                  child: TextField(
                    key: const Key('home-search'),
                    onChanged: (value) => _query = value.trim(),
                    onSubmitted: _searchOnServer,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm món ăn, nguyên liệu...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const Key('open-image-search'),
                            tooltip: 'Tìm món bằng ảnh',
                            onPressed: () => context.push('/image-search'),
                            icon: const Icon(Icons.photo_camera_rounded),
                          ),
                          IconButton(
                            tooltip: 'Tìm kiếm',
                            onPressed: () => _searchOnServer(_query),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _CategoryList(
                  categories: data.categories,
                  selectedId: _selectedCategoryId,
                  onSelected: (id) {
                    setState(() => _selectedCategoryId = id);
                    context.push(
                      '/explore?search=${Uri.encodeComponent(_query)}'
                      '&category=$id',
                    );
                    setState(() => _selectedCategoryId = null);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _CookShortcutCard(onTap: () => context.go('/cook')),
                const SizedBox(height: AppSpacing.xl),
                _SectionTitle(
                  title: 'Công thức nổi bật',
                  onViewAll: () => context.push('/explore?sort=popular'),
                ),
                const SizedBox(height: AppSpacing.md),
                if (featured.isEmpty)
                  const _FilteredEmptyState()
                else
                  SizedBox(
                    height: 310,
                    child: ListView.separated(
                      key: const Key('featured-list'),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) => FeaturedRecipeCard(
                        recipe: featured[index],
                        onTap: () => _openRecipe(featured[index]),
                        isFavourite:
                            _favouriteByRecipe[featured[index].id] ?? false,
                        favouriteBusy: _busyRecipeIds.contains(
                          featured[index].id,
                        ),
                        onToggleFavourite: _toggleFavourite,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                if (user != null) ...[
                  _PersonalizedSection(
                    state: ref.watch(personalizedRecommendationsProvider),
                    onRetry: () =>
                        ref.invalidate(personalizedRecommendationsProvider),
                    onOpenRecipe: _openRecipe,
                    onShowExplanation: _showRecommendationExplanation,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _SectionTitle(
                  title: 'Mới nhất',
                  onViewAll: () => context.push('/explore'),
                ),
                const SizedBox(height: AppSpacing.md),
                if (latest.isEmpty)
                  const _FilteredEmptyState()
                else
                  ...latest.map(
                    (recipe) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LatestRecipeCard(
                        key: ValueKey('latest-${recipe.id}'),
                        recipe: recipe,
                        onTap: () => _openRecipe(recipe),
                        isFavourite: _favouriteByRecipe[recipe.id] ?? false,
                        favouriteBusy: _busyRecipeIds.contains(recipe.id),
                        onToggleFavourite: _toggleFavourite,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _searchOnServer(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (query.isEmpty) {
      context.push('/explore');
      return;
    }
    context.push('/explore?search=${Uri.encodeComponent(query)}');
  }

  Future<void> _toggleFavourite(Recipe recipe) async {
    if (_busyRecipeIds.contains(recipe.id)) return;
    final wasSaved = _favouriteByRecipe[recipe.id] ?? false;
    setState(() => _busyRecipeIds.add(recipe.id));
    final isSaved = await toggleRecipeFavourite(
      context,
      ref,
      recipeId: recipe.id,
      makingFavourite: !wasSaved,
    );
    if (!mounted) return;
    setState(() {
      _busyRecipeIds.remove(recipe.id);
      if (isSaved != wasSaved) _favouriteByRecipe[recipe.id] = isSaved;
    });
  }

  void _openRecipe(Recipe recipe) => context.pushNamed(
    'recipe-detail',
    pathParameters: {'id': '${recipe.id}'},
  );

  void _showRecommendationExplanation(RecommendationExplanation explanation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vì sao bạn thấy những món này?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(explanation.summary),
              const SizedBox(height: AppSpacing.md),
              Text(
                explanation.interactedRecipes == 0
                    ? 'Hãy lưu, xem hoặc đánh giá công thức để gợi ý ngày càng phù hợp.'
                    : 'Hệ thống đang học từ ${explanation.interactedRecipes} công thức bạn đã tương tác.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalizedSection extends StatelessWidget {
  const _PersonalizedSection({
    required this.state,
    required this.onRetry,
    required this.onOpenRecipe,
    required this.onShowExplanation,
  });

  final AsyncValue<RecommendationFeed?> state;
  final VoidCallback onRetry;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<RecommendationExplanation> onShowExplanation;

  @override
  Widget build(BuildContext context) => state.when(
    loading: () => const SizedBox(
      height: 96,
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.limeSurface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          const Expanded(child: Text('Chưa thể tải gợi ý dành riêng cho bạn.')),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
    data: (feed) {
      if (feed == null || feed.recipes.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dành riêng cho bạn',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Giải thích gợi ý',
                onPressed: () => onShowExplanation(feed.explanation),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          Text(
            feed.explanation.summary,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 350,
            child: ListView.separated(
              key: const Key('personalized-recommendations'),
              scrollDirection: Axis.horizontal,
              itemCount: feed.recipes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final recipe = feed.recipes[index];
                return FeaturedRecipeCard(
                  recipe: recipe,
                  onTap: () => onOpenRecipe(recipe),
                  showRecommendationReason: true,
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.fullname, required this.avatar});

  final String? fullname;
  final String? avatar;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullname == null ? 'Xin chào!' : 'Xin chào, $fullname!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hôm nay bạn muốn nấu món gì?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ],
        ),
      ),
      Semantics(
        label: 'Xem tài khoản',
        button: true,
        child: IconButton(
          onPressed: () => context.go('/profile'),
          icon: CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.limeSurface,
            child: ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: AppNetworkImage(
                  url: avatar,
                  fallbackIcon: Icons.person_rounded,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _CookShortcutCard extends StatelessWidget {
  const _CookShortcutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('cook-shortcut'),
    color: AppColors.lime,
    borderRadius: BorderRadius.circular(AppRadii.large),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.soup_kitchen_rounded,
                color: AppColors.olive,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nấu với nguyên liệu sẵn có',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chọn nguyên liệu trong bếp để tìm món phù hợp.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    ),
  );
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<RecipeCategory> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 218,
    child: GridView.builder(
      key: const Key('category-list'),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 104 / 96,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = selectedId == category.id;
        return Semantics(
          key: Key('category-tile-${category.id}'),
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: () => onSelected(category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? AppColors.lime : AppColors.white,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                boxShadow: selected ? const [] : AppShadows.soft,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIcon(index), color: AppColors.oliveSoft),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  IconData _categoryIcon(int index) => const [
    Icons.ramen_dining_rounded,
    Icons.local_cafe_rounded,
    Icons.rice_bowl_rounded,
    Icons.bakery_dining_rounded,
    Icons.soup_kitchen_rounded,
  ][index % 5];
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      if (onViewAll != null)
        TextButton(onPressed: onViewAll, child: const Text('Xem tất cả')),
    ],
  );
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.limeSurface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: const Text(
      'Không tìm thấy công thức phù hợp. Hãy thử từ khóa hoặc danh mục khác.',
      textAlign: TextAlign.center,
    ),
  );
}
