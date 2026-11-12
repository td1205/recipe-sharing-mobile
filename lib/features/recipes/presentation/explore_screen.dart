import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/network/api_exception.dart';
import '../domain/recipe.dart';
import '../domain/recipe_filter.dart';
import '../domain/recipe_form_data.dart';
import 'favourite_actions.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Explore/library screen: server-side search, facets, sort and pagination.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialQuery = '',
    this.initialTag,
    this.initialCategoryId,
  });

  final String initialQuery;
  final String? initialTag;
  final int? initialCategoryId;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;
  final _busyRecipeIds = <int>{};
  final _favouriteByRecipe = <int, bool>{};
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    final initial = _searchController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(exploreProvider.notifier)
          .setFilter(
            const RecipeFilter()
                .copyWith(search: initial, sort: RecipeSort.newest)
                .copyWith(tag: widget.initialTag)
                .copyWith(categoryId: widget.initialCategoryId),
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery == widget.initialQuery &&
        oldWidget.initialTag == widget.initialTag &&
        oldWidget.initialCategoryId == widget.initialCategoryId) {
      return;
    }
    _searchController.text = widget.initialQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(exploreProvider.notifier)
          .setFilter(
            const RecipeFilter()
                .copyWith(
                  search: widget.initialQuery.trim(),
                  sort: RecipeSort.newest,
                )
                .copyWith(tag: widget.initialTag)
                .copyWith(categoryId: widget.initialCategoryId),
          );
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _showSuggestions = value.trim().isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      // Suggestions provider is driven by the controller text.
      if (mounted) setState(() {});
    });
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    setState(() => _showSuggestions = false);
    FocusManager.instance.primaryFocus?.unfocus();
    final current = ref.read(exploreProvider).value;
    ref
        .read(exploreProvider.notifier)
        .setFilter(
          (current?.filter ?? const RecipeFilter()).copyWith(
            search: value.trim(),
          ),
        );
  }

  Future<void> _openFilterSheet() async {
    // Reuse cached nav data when available; otherwise fetch once.
    final cached = ref.read(navDataProvider).value;
    final current =
        ref.read(exploreProvider).value?.filter ?? const RecipeFilter();
    var navData = cached ?? const RecipeFormData();
    if (cached == null) {
      try {
        navData = await ref.read(recipeRepositoryProvider).getNavData();
      } on ApiException {
        navData = const RecipeFormData();
      }
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<RecipeFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) =>
          _FilterSheet(filter: current, navData: navData),
    );
    if (result != null) {
      ref.read(exploreProvider.notifier).setFilter(result);
    }
  }

  Future<void> _toggleFavourite(Recipe recipe) async {
    if (_busyRecipeIds.contains(recipe.id)) return;
    final wasFavourite = _favouriteByRecipe[recipe.id] ?? false;
    setState(() => _busyRecipeIds.add(recipe.id));
    final isFav = await toggleRecipeFavourite(
      context,
      ref,
      recipeId: recipe.id,
      makingFavourite: !wasFavourite,
    );
    if (!mounted) return;
    setState(() {
      _busyRecipeIds.remove(recipe.id);
      if (isFav != wasFavourite) _favouriteByRecipe[recipe.id] = isFav;
    });
  }

  @override
  Widget build(BuildContext context) {
    final explore = ref.watch(exploreProvider);
    final suggestionsQuery = _debounce == null || !_debounce!.isActive
        ? _searchController.text.trim()
        : '';
    final suggestions = suggestionsQuery.length >= 2 && _showSuggestions
        ? ref.watch(suggestionsProvider(suggestionsQuery))
        : const AsyncValue<List<Recipe>>.data(<Recipe>[]);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Khám phá món ngon',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tìm theo món, nguyên liệu hoặc phong cách bữa ăn.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('explore-search'),
                          controller: _searchController,
                          onChanged: _onQueryChanged,
                          onSubmitted: _submitSearch,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Tìm công thức...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Xoá từ khóa',
                                    onPressed: () {
                                      _searchController.clear();
                                      _submitSearch('');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        key: const Key('explore-filter'),
                        tooltip: 'Mở bộ lọc',
                        onPressed: _openFilterSheet,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: explore.when(
                loading: () => const RecipeLoadingView(),
                error: (error, _) => RecipeErrorView(
                  message: error.toString(),
                  onRetry: () => ref.read(exploreProvider.notifier).refresh(),
                ),
                data: (state) => _buildResults(context, suggestions, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AsyncValue<List<Recipe>> suggestions,
    ExploreState state,
  ) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.read(exploreProvider.notifier).refresh(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 500) {
                ref.read(exploreProvider.notifier).loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              key: const Key('explore-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.hasActiveFilters)
                  SliverToBoxAdapter(
                    child: _ActiveFilters(
                      state: state,
                      onRemove: (filter, clear) => ref
                          .read(exploreProvider.notifier)
                          .setFilter(clear(filter)),
                    ),
                  ),
                if (state.recipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: RecipeEmptyView(
                      title: 'Không có món nào',
                      message: state.filter.search.isNotEmpty
                          ? 'Không tìm thấy món khớp với từ khóa "${state.filter.search}". Hãy thử từ khóa khác.'
                          : 'Chưa có món nào khớp với bộ lọc hiện tại. Hãy thử điều chỉnh bộ lọc.',
                      onAction: state.hasActiveFilters
                          ? () => ref
                                .read(exploreProvider.notifier)
                                .setFilter(const RecipeFilter())
                          : null,
                      actionLabel: 'Đặt lại bộ lọc',
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      AppSpacing.xs,
                      20,
                      4,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${state.total} món',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.textScalerOf(context)
                            .scale(1);
                        final cardAspect = textScale > 1.2 ? 0.58 : 0.68;
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 210,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: cardAspect,
                              ),
                          itemCount: state.recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = state.recipes[index];
                            return GridRecipeCard(
                              recipe: recipe,
                              onTap: () => context.pushNamed(
                                'recipe-detail',
                                pathParameters: {'id': '${recipe.id}'},
                              ),
                              isFavourite:
                                  _favouriteByRecipe[recipe.id] ?? false,
                              favouriteBusy: _busyRecipeIds.contains(recipe.id),
                              onToggleFavourite: _toggleFavourite,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: state.hasMore
                        ? Padding(
                            key: const Key('explore-load-more'),
                            padding: const EdgeInsets.only(bottom: 140),
                            child: Center(
                              child: state.loadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : state.loadMoreError == null
                                  ? TextButton.icon(
                                      onPressed: () => ref
                                          .read(exploreProvider.notifier)
                                          .loadMore(),
                                      icon: const Icon(
                                        Icons.expand_more_rounded,
                                      ),
                                      label: const Text('Xem thêm'),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          state.loadMoreError!,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        OutlinedButton.icon(
                                          onPressed: () => ref
                                              .read(exploreProvider.notifier)
                                              .loadMore(),
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          label: const Text('Tải lại'),
                                        ),
                                      ],
                                    ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 120),
                            child: Center(
                              child: Text(
                                'Bạn đã xem hết ${state.total} món',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (suggestions is AsyncData<List<Recipe>> &&
            suggestions.value.isNotEmpty &&
            _showSuggestions)
          Positioned.directional(
            textDirection: Directionality.of(context),
            start: 16,
            top: 8,
            end: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: suggestions.value.length,
                itemBuilder: (context, index) {
                  final recipe = suggestions.value[index];
                  return ListTile(
                    dense: true,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: SizedBox.square(
                        dimension: 40,
                        child: AppNetworkImage(url: recipe.imageUrl),
                      ),
                    ),
                    title: Text(recipe.title, maxLines: 1),
                    onTap: () {
                      setState(() => _showSuggestions = false);
                      context.pushNamed(
                        'recipe-detail',
                        pathParameters: {'id': '${recipe.id}'},
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.state, required this.onRemove});

  final ExploreState state;
  final void Function(RecipeFilter current, RecipeFilter Function(RecipeFilter))
  onRemove;

  @override
  Widget build(BuildContext context) {
    final filter = state.filter;
    final chips = <_FilterChipData>[
      if (filter.search.isNotEmpty)
        _FilterChipData(
          label: '"${filter.search}"',
          onRemoved: (current) => current.copyWith(clearSearch: true),
        ),
      if (filter.categoryId != null)
        _FilterChipData(
          label: 'Danh mục #${filter.categoryId}',
          onRemoved: (current) => current.copyWith(clearCategory: true),
        ),
      if (filter.mealTimeId != null)
        _FilterChipData(
          label: 'Bữa #${filter.mealTimeId}',
          onRemoved: (current) => current.copyWith(clearMealTime: true),
        ),
      if (filter.duration != null)
        _FilterChipData(
          label: filter.duration!.label,
          onRemoved: (current) => current.copyWith(clearDuration: true),
        ),
      if (filter.minRating != null)
        _FilterChipData(
          label: '⭐ ≥ ${filter.minRating}',
          onRemoved: (current) => current.copyWith(clearMinRating: true),
        ),
      if (filter.tag != null && filter.tag!.isNotEmpty)
        _FilterChipData(
          label: '#${filter.tag}',
          onRemoved: (current) => current.copyWith(clearTag: true),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.sm, 20, AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: [
          ...chips.map(
            (chip) => Chip(
              label: Text(chip.label),
              onDeleted: () => onRemove(state.filter, chip.onRemoved),
            ),
          ),
          ActionChip(
            label: const Text('Đặt lại tất cả'),
            avatar: const Icon(Icons.restart_alt_rounded, size: 18),
            onPressed: () =>
                onRemove(state.filter, (_) => const RecipeFilter()),
          ),
        ],
      ),
    );
  }
}

class _FilterChipData {
  const _FilterChipData({required this.label, required this.onRemoved});
  final String label;
  final RecipeFilter Function(RecipeFilter current) onRemoved;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.navData});

  final RecipeFilter filter;
  final RecipeFormData navData;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RecipeFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    final navData = widget.navData;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bộ lọc món ăn',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (navData.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text('Chưa tải được danh mục từ máy chủ.'),
                      )
                    else
                      _Section(
                        label: 'Danh mục',
                        child: _ChoiceChips(
                          options: {
                            for (final category in navData.categories)
                              category.id: category.name,
                          },
                          selectedValue: _draft.categoryId,
                          onSelect: (id) => setState(
                            () => _draft = _draft.copyWith(
                              categoryId: id,
                              clearCategory: id == null,
                            ),
                          ),
                        ),
                      ),
                    if (navData.mealTimes.isNotEmpty)
                      _Section(
                        label: 'Bữa ăn',
                        child: _ChoiceChips(
                          options: {
                            for (final mealTime in navData.mealTimes)
                              mealTime.id: mealTime.name,
                          },
                          selectedValue: _draft.mealTimeId,
                          onSelect: (id) => setState(
                            () => _draft = _draft.copyWith(
                              mealTimeId: id,
                              clearMealTime: id == null,
                            ),
                          ),
                        ),
                      ),
                    _Section(
                      label: 'Thời gian nấu',
                      child: _ChoiceChips<RecipeDuration>(
                        options: {
                          for (final duration in RecipeDuration.values)
                            duration: duration.label,
                        },
                        selectedValue: _draft.duration,
                        onSelect: (value) => setState(
                          () => _draft = _draft.copyWith(
                            duration: value,
                            clearDuration: value == null,
                          ),
                        ),
                      ),
                    ),
                    _Section(
                      label: 'Đánh giá tối thiểu',
                      child: _ChoiceChips<int>(
                        options: const {3: '⭐ 3+', 4: '⭐ 4+', 5: '⭐ 5'},
                        selectedValue: _draft.minRating,
                        onSelect: (value) => setState(
                          () => _draft = _draft.copyWith(
                            minRating: value,
                            clearMinRating: value == null,
                          ),
                        ),
                      ),
                    ),
                    _Section(
                      label: 'Sắp xếp theo',
                      child: _ChoiceChips<RecipeSort>(
                        options: {
                          for (final sort in RecipeSort.values)
                            sort: sort.label,
                        },
                        selectedValue: _draft.sort,
                        onSelect: (value) => setState(
                          () => _draft = _draft.copyWith(sort: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _draft = const RecipeFilter()),
                    child: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    key: const Key('filter-apply'),
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}

class _ChoiceChips<T extends Object> extends StatelessWidget {
  const _ChoiceChips({
    required this.options,
    required this.selectedValue,
    required this.onSelect,
  });

  final Map<T, String> options;
  final T? selectedValue;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: options.entries
        .map(
          (entry) => FilterChip(
            label: Text(entry.value),
            selected: selectedValue == entry.key,
            onSelected: (selected) => onSelect(selected ? entry.key : null),
          ),
        )
        .toList(growable: false),
  );
}
