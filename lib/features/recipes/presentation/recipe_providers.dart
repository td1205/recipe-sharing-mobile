import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/recipe_repository.dart';
import '../domain/profile_data.dart';
import '../domain/recipe.dart';
import '../domain/recipe_detail.dart';
import '../domain/recipe_filter.dart';
import '../domain/recipe_form_data.dart';
import '../domain/home_data.dart';
import '../domain/recommendation_feed.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => RecipeRepository(ref.watch(apiClientProvider)),
);

final homeProvider = FutureProvider.autoDispose<HomeData>(
  (ref) => ref.watch(recipeRepositoryProvider).getHomeData(),
);

/// Recommendations are intentionally isolated from [homeProvider], so a model
/// outage cannot prevent the rest of Home from loading.
final personalizedRecommendationsProvider =
    FutureProvider.autoDispose<RecommendationFeed?>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return null;
      return ref
          .watch(recipeRepositoryProvider)
          .getPersonalizedRecommendations();
    });

final recipeDetailProvider = FutureProvider.autoDispose
    .family<RecipeDetail, int>(
      (ref, id) => ref.watch(recipeRepositoryProvider).getRecipeDetail(id),
    );

/// Public option lists for filter sheets and the recipe form.
final navDataProvider = FutureProvider.autoDispose<RecipeFormData>(
  (ref) => ref.watch(recipeRepositoryProvider).getNavData(),
);

/// Search suggestions (typeahead) for the current query.
final suggestionsProvider = FutureProvider.autoDispose
    .family<List<Recipe>, String>((ref, query) {
      return ref.watch(recipeRepositoryProvider).getSuggestions(query);
    });

/// Own profile: user info + saved + authored recipes. Requires a session.
final ownProfileProvider = FutureProvider.autoDispose<OwnProfileData>(
  (ref) => ref.watch(recipeRepositoryProvider).getOwnProfile(),
);

class ShoppingListChangesController extends Notifier<Map<int, Map<int, bool>>> {
  @override
  Map<int, Map<int, bool>> build() => const {};
  void setItem(int recipeId, int ingredientId, bool checked) {
    state = {
      ...state,
      recipeId: {...?state[recipeId], ingredientId: checked},
    };
  }
}

final shoppingListChangesProvider =
    NotifierProvider<ShoppingListChangesController, Map<int, Map<int, bool>>>(
      ShoppingListChangesController.new,
    );

class ShoppingServingsController extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};
  void set(int recipeId, int servings) =>
      state = {...state, recipeId: servings};
}

final shoppingServingsProvider =
    NotifierProvider<ShoppingServingsController, Map<int, int>>(
      ShoppingServingsController.new,
    );

/// Someone else's profile, one page per fetch (16 items per page server-side).
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfilePage, (int userId, int page)>((ref, key) {
      final (userId, page) = key;
      return ref
          .watch(recipeRepositoryProvider)
          .getPublicProfile(userId, page: page);
    });

// ---------------------------------------------------------------------------
// Explore (search facet + sort + paginated listing)
// ---------------------------------------------------------------------------

class ExploreState {
  const ExploreState({
    required this.filter,
    required this.recipes,
    required this.total,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final RecipeFilter filter;
  final List<Recipe> recipes;
  final int total;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasActiveFilters => !filter.isDefault;
}

class ExploreController extends AsyncNotifier<ExploreState> {
  static const _pageSize = 12;

  @override
  Future<ExploreState> build() => _load(const RecipeFilter(), 1);

  Future<void> setFilter(RecipeFilter filter) async {
    state = const AsyncLoading<ExploreState>();
    state = await AsyncValue.guard(() => _load(filter, 1));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(
      ExploreState(
        filter: current.filter,
        recipes: current.recipes,
        total: current.total,
        page: current.page,
        hasMore: current.hasMore,
        loadingMore: true,
      ),
    );
    final repository = ref.read(recipeRepositoryProvider);
    try {
      final next = await repository.getRecipes(
        filter: current.filter,
        page: current.page + 1,
        limit: _pageSize,
      );
      final merged = [
        ...current.recipes,
        ...next.recipes.where(
          (recipe) => !current.recipes.any((other) => other.id == recipe.id),
        ),
      ];
      state = AsyncData(
        ExploreState(
          filter: current.filter,
          recipes: merged,
          total: next.total,
          page: next.page,
          hasMore: merged.length < next.total,
        ),
      );
    } on ApiException catch (error) {
      final value = state.value;
      if (value != null) {
        state = AsyncData(
          ExploreState(
            filter: value.filter,
            recipes: value.recipes,
            total: value.total,
            page: value.page,
            hasMore: value.hasMore,
            loadMoreError: error.message,
          ),
        );
      }
    }
  }

  Future<void> refresh() async {
    final current = state.value;
    final filter = current?.filter ?? const RecipeFilter();
    state = const AsyncLoading<ExploreState>();
    state = await AsyncValue.guard(() => _load(filter, 1));
  }

  Future<ExploreState> _load(RecipeFilter filter, int page) async {
    final result = await ref
        .read(recipeRepositoryProvider)
        .getRecipes(filter: filter, page: page, limit: _pageSize);
    return ExploreState(
      filter: filter,
      recipes: result.recipes,
      total: result.total,
      page: result.page,
      hasMore: result.recipes.length < result.total,
    );
  }
}

final exploreProvider = AsyncNotifierProvider<ExploreController, ExploreState>(
  ExploreController.new,
);

// ---------------------------------------------------------------------------
// Cook with what you have (pantry recommendations)
// ---------------------------------------------------------------------------

class CookState {
  const CookState({
    required this.pantryItems,
    required this.results,
    required this.isLoading,
    this.error,
  });

  final List<String> pantryItems;
  final List<Recipe> results;
  final bool isLoading;
  final String? error;

  CookState copyWith({
    List<String>? pantryItems,
    List<Recipe>? results,
    bool? isLoading,
    String? error,
  }) => CookState(
    pantryItems: pantryItems ?? this.pantryItems,
    results: results ?? this.results,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class CookController extends Notifier<CookState> {
  @override
  CookState build() =>
      const CookState(pantryItems: [], results: [], isLoading: false);

  void addItem(String raw) {
    final item = raw.trim();
    if (item.isEmpty ||
        state.pantryItems.any((existing) => existing == item) ||
        state.pantryItems.length >= 15) {
      return;
    }
    state = state.copyWith(pantryItems: [...state.pantryItems, item]);
  }

  void removeItem(String item) {
    state = state.copyWith(
      pantryItems: state.pantryItems
          .where((existing) => existing != item)
          .toList(),
    );
  }

  void clearResults() =>
      state = state.copyWith(results: [], error: null, isLoading: false);

  Future<void> submit() async {
    if (state.pantryItems.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ref
          .read(recipeRepositoryProvider)
          .getByIngredients(ingredients: state.pantryItems);
      state = state.copyWith(
        results: result.recipes,
        isLoading: false,
        error: result.recipes.isEmpty
            ? 'Không có món nào khớp với nguyên liệu bạn có. Thử thêm nguyên liệu khác nhé!'
            : null,
      );
    } on ApiException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    }
  }
}

final cookProvider = NotifierProvider.autoDispose<CookController, CookState>(
  CookController.new,
);

/// Whether the current user is the author (or an admin) of a recipe —
/// used to show edit/delete affordances.
final canManageRecipeProvider = Provider.autoDispose.family<bool, int?>((
  ref,
  authorUserId,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || authorUserId == null) return false;
  return user.isAdmin || user.id == authorUserId;
});
