import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_sharing_mobile/app/app.dart';
import 'package:recipe_sharing_mobile/app/router.dart';
import 'package:recipe_sharing_mobile/app/theme/app_theme.dart';
import 'package:recipe_sharing_mobile/features/auth/domain/auth_user.dart';
import 'package:recipe_sharing_mobile/features/auth/presentation/auth_providers.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/category.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/home_data.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_detail.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recipe_filter.dart';
import 'package:recipe_sharing_mobile/features/recipes/domain/recommendation_feed.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/home_screen.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/explore_screen.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/recipe_providers.dart';
import 'package:recipe_sharing_mobile/features/recipes/presentation/widgets/recipe_card.dart';

class _NoAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => null;
}

class _AuthenticatedController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 7,
    username: 'tester',
    email: 'tester@example.com',
    fullname: 'Bếp thử nghiệm',
    role: 'user',
  );
}

class _TestExploreController extends ExploreController {
  @override
  Future<ExploreState> build() async => const ExploreState(
    filter: RecipeFilter(),
    recipes: [recipe, recipeTwo],
    total: 2,
    page: 1,
    hasMore: false,
  );
}

const recipe = Recipe(
  id: 1,
  title: 'Pho bo Ha Noi',
  description: 'Nuoc dung trong, thom mui que va hoi.',
  prepTime: 20,
  cookTime: 60,
  servings: 4,
  categoryId: 2,
  categoryName: 'Com, Bun, Pho & Mi',
);

const recipeTwo = Recipe(
  id: 2,
  title: 'Bun cha Ha Noi dam vi truyen thong',
  description: 'Thit nuong thom, bun tuoi va nuoc cham.',
  prepTime: 25,
  cookTime: 30,
  servings: 3,
  categoryId: 2,
  categoryName: 'Com, Bun, Pho & Mi',
);

const homeData = HomeData(
  featured: [recipe],
  latest: [recipe],
  categories: [RecipeCategory(id: 2, name: 'Com, Bun, Pho & Mi')],
);

const personalizedRecipe = Recipe(
  id: 3,
  title: 'Goi cuon tom thit',
  recommendationStrategy: 'hybrid',
  recommendationReason: 'Giống món bạn quan tâm: "Pho bo Ha Noi"',
);

const recommendationFeed = RecommendationFeed(
  recipes: [personalizedRecipe],
  explanation: RecommendationExplanation(
    interactedRecipes: 6,
    strategy: 'hybrid',
    modelRecipeCount: 1145,
    usersWithHistory: 101,
    modelBuiltAt: null,
  ),
);

const detailData = RecipeDetail(
  id: 1,
  recipe: recipe,
  authorUserId: 1,
  ingredients: [RecipeIngredient(name: 'Banh pho', amount: '500', unit: 'g')],
  steps: [RecipeStep(number: 1, instruction: 'Ninh nuoc dung cho trong.')],
);

const longContentDetail = RecipeDetail(
  id: 1,
  recipe: Recipe(
    id: 1,
    title: 'Món ngon cho bữa cơm gia đình cuối tuần',
    prepTime: 120,
    cookTime: 180,
    servings: 12,
    categoryName: 'Cơm, bún, phở và các món truyền thống Việt Nam',
  ),
  authorUserId: 42,
  authorFullname: 'Nguyễn Thị Minh Anh với căn bếp nhỏ cuối phố',
  ingredients: [
    RecipeIngredient(
      name: 'Nước dùng hầm từ xương và nhiều loại rau củ theo mùa',
      amount: '1250.5',
      unit: 'mililit mỗi khẩu phần',
    ),
  ],
  steps: [RecipeStep(number: 1, instruction: 'Ninh nước dùng thật trong.')],
);

void main() {
  testWidgets('Home renders backend data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeProvider.overrideWith((ref) async => homeData)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-search')), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Pho bo Ha Noi'),
      find.byKey(const Key('home-scroll')),
      const Offset(0, -300),
    );
    expect(find.text('Pho bo Ha Noi'), findsWidgets);
  });

  testWidgets('Home categories use two rows before scrolling horizontally', (
    tester,
  ) async {
    const categories = [
      RecipeCategory(id: 1, name: 'Sốt & Nước chấm'),
      RecipeCategory(id: 2, name: 'Món Luộc'),
      RecipeCategory(id: 3, name: 'Đồ uống'),
      RecipeCategory(id: 4, name: 'Món Kho'),
      RecipeCategory(id: 5, name: 'Món Nướng'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(
            (ref) async => const HomeData(
              featured: [recipe],
              latest: [recipe],
              categories: categories,
            ),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.byKey(const Key('category-tile-1')));
    final second = tester.getTopLeft(find.byKey(const Key('category-tile-2')));
    final third = tester.getTopLeft(find.byKey(const Key('category-tile-3')));

    expect(second.dx, closeTo(first.dx, 0.1));
    expect(second.dy, greaterThan(first.dy));
    expect(third.dx, greaterThan(first.dx));
    expect(third.dy, closeTo(first.dy, 0.1));
    expect(
      tester
          .widget<GridView>(find.byKey(const Key('category-list')))
          .scrollDirection,
      Axis.horizontal,
    );
  });

  testWidgets('Home shows personalized recipes and their explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_AuthenticatedController.new),
          homeProvider.overrideWith((ref) async => homeData),
          personalizedRecommendationsProvider.overrideWith(
            (ref) async => recommendationFeed,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Dành riêng cho bạn'),
      find.byKey(const Key('home-scroll')),
      const Offset(0, -300),
    );
    expect(find.text('Goi cuon tom thit'), findsOneWidget);
    expect(find.textContaining('Giống món bạn quan tâm'), findsOneWidget);

    await tester.tap(find.byTooltip('Giải thích gợi ý'));
    await tester.pumpAndSettle();
    expect(find.text('Vì sao bạn thấy những món này?'), findsOneWidget);
    expect(find.textContaining('6 công thức'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('parses recommendation metadata and explanation contract', () {
    final parsedRecipe = Recipe.fromJson(const {
      'id': 3,
      'title': 'Goi cuon',
      'recommendation_score': 0.82,
      'recommendation_strategy': 'hybrid',
      'recommendation_reason': 'Phù hợp với sở thích của bạn',
    });
    final explanation = RecommendationExplanation.fromJson(const {
      'interactedRecipes': 4,
      'strategy': 'content',
      'model': {
        'recipes': 1145,
        'usersWithHistory': 101,
        'builtAt': '2026-11-10T00:00:00.000Z',
      },
    });

    expect(parsedRecipe.recommendationScore, 0.82);
    expect(parsedRecipe.recommendationStrategy, 'hybrid');
    expect(parsedRecipe.recommendationReason, isNotEmpty);
    expect(explanation.interactedRecipes, 4);
    expect(explanation.strategy, 'content');
    expect(explanation.modelBuiltAt, isNotNull);
  });

  testWidgets(
    'Recipe Detail renders recipe, ingredients, steps and start button',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeDetailProvider(1).overrideWith((ref) async => detailData),
          ],
          child: const MaterialApp(home: RecipeDetailScreen(recipeId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pho bo Ha Noi'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('detail-scroll')),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 nguoi'), findsNothing);
      expect(find.text('Banh pho'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('detail-scroll')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ninh nuoc dung cho trong.'), findsOneWidget);
      final startButton = tester.widget<FilledButton>(
        find.byKey(const Key('start-cooking')),
      );
      expect(startButton.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('start-cooking')));
      await tester.pumpAndSettle();
      expect(find.text('Các bước chế biến'), findsOneWidget);
    },
  );

  testWidgets('Explore remains usable at 360dp with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [exploreProvider.overrideWith(_TestExploreController.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: ExploreScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore-search')), findsOneWidget);
    expect(find.byType(GridRecipeCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recipe Detail portion controls wrap at compact width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeDetailProvider(1).overrideWith((ref) async => detailData),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: RecipeDetailScreen(recipeId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Điều chỉnh khẩu phần'),
      find.byKey(const Key('detail-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('8×'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home header adapts at 360dp with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeProvider.overrideWith((ref) async => homeData)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hôm nay bạn muốn nấu món gì?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Detail handles long Vietnamese content at compact width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipeDetailProvider(1)
              .overrideWith((ref) async => longContentDetail),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: RecipeDetailScreen(recipeId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Điều chỉnh khẩu phần'),
      find.byKey(const Key('detail-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('mililit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping a Home recipe navigates to Recipe Detail', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(() => _NoAuthController()),
        homeProvider.overrideWith((ref) async => homeData),
        recipeDetailProvider(1).overrideWith((ref) async => detailData),
      ],
    );
    addTearDown(container.dispose);
    final router = buildAppRouter(container);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RecipeSharingApp(router: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.dragUntilVisible(
      find.text('Pho bo Ha Noi'),
      find.byKey(const Key('home-scroll')),
      const Offset(0, -300),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pho bo Ha Noi').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RecipeDetailScreen), findsOneWidget);
  });

  testWidgets('Home to Explore to Recipe Detail works at 400dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(() => _NoAuthController()),
        homeProvider.overrideWith((ref) async => homeData),
        exploreProvider.overrideWith(_TestExploreController.new),
        recipeDetailProvider(1).overrideWith((ref) async => detailData),
      ],
    );
    addTearDown(container.dispose);
    final router = buildAppRouter(container);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 900),
            textScaler: TextScaler.linear(1.2),
          ),
          child: RecipeSharingApp(router: router),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('nav-Khám phá')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ExploreScreen), findsOneWidget);

    await tester.tap(find.text('Pho bo Ha Noi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(RecipeDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
