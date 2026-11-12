import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/profile_edit_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/recipes/presentation/cook_with_ingredients_screen.dart';
import '../features/recipes/presentation/explore_screen.dart';
import '../features/recipes/presentation/home_screen.dart';
import '../features/recipes/presentation/image_search_screen.dart';
import '../features/recipes/presentation/my_recipes_screen.dart';
import '../features/recipes/presentation/profile_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipe_form_screen.dart';

import 'package:recipe_sharing_mobile/features/recipes/presentation/public_profile_screen.dart';

import '../features/recipes/presentation/saved_screen.dart';
import '../features/recipes/presentation/widgets/floating_bottom_nav.dart';
import 'theme/app_theme.dart';
import 'about_screen.dart';
import 'not_found_screen.dart';

const _protectedPrefixes = ['/saved', '/profile', '/my-recipes'];
final appNavigatorKey = GlobalKey<NavigatorState>();

String? _authRedirect(GoRouterState state, AsyncValue<Object?> auth) {
  final location = state.matchedLocation;
  final user = auth.asData?.value;
  final loading = auth.isLoading && !auth.hasValue && !auth.hasError;
  if (loading) return '/boot';
  if (location == '/boot') return '/';
  final needsAuth =
      _protectedPrefixes.any(
        (prefix) => location == prefix || location.startsWith('$prefix/'),
      ) ||
      location == '/recipes/create' ||
      (location.startsWith('/recipes/') && location.endsWith('/edit'));
  if (needsAuth && user == null) return '/login?from=$location';
  if (user != null && (location == '/login' || location == '/register')) {
    return '/profile';
  }
  return null;
}

GoRouter buildAppRouter(ProviderContainer container) {
  final refresh = ValueNotifier(0);
  container.listen<AsyncValue<Object?>>(authStateProvider, (_, _) {
    refresh.value++;
  });

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    errorBuilder: (_, state) => NotFoundScreen(message: state.error?.message),
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = container.read(authStateProvider);
      return _authRedirect(state, auth);
    },
    routes: [
      GoRoute(
        path: '/boot',
        name: 'boot',
        builder: (_, _) => const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Đang kiểm tra phiên đăng nhập',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/image-search',
        name: 'image-search',
        builder: (_, _) => const ImageSearchScreen(),
      ),
      GoRoute(
        path: '/recipes/create',
        name: 'recipe-create',
        builder: (_, _) => const RecipeFormScreen(),
      ),
      GoRoute(
        path: '/recipes/:id/edit',
        name: 'recipe-edit',
        builder: (_, state) => RecipeFormScreen(
          recipeId: int.tryParse(state.pathParameters['id']!),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Scaffold(
          body: navigationShell,
          bottomNavigationBar: FloatingBottomNav(
            items: const [
              FloatingNavItem(
                label: 'Trang chủ',
                icon: Icons.home_outlined,
                filledIcon: Icons.home_rounded,
              ),
              FloatingNavItem(
                label: 'Khám phá',
                icon: Icons.search_rounded,
                filledIcon: Icons.travel_explore_rounded,
              ),
              FloatingNavItem(
                label: 'Nấu gọn',
                icon: Icons.soup_kitchen_rounded,
              ),
              FloatingNavItem(
                label: 'Đã lưu',
                icon: Icons.bookmark_border_rounded,
                filledIcon: Icons.bookmark_rounded,
              ),
              FloatingNavItem(
                label: 'Tài khoản',
                icon: Icons.person_outline_rounded,
                filledIcon: Icons.person_rounded,
              ),
            ],
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
          extendBody: true,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                name: 'explore',
                builder: (context, state) => ExploreScreen(
                  initialQuery: state.uri.queryParameters['search'] ?? '',
                  initialTag: state.uri.queryParameters['tag'],
                  initialCategoryId: () {
                    final raw = state.uri.queryParameters['category'];
                    return raw == null ? null : int.tryParse(raw);
                  }(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cook',
                name: 'cook',
                builder: (_, _) => const CookWithIngredientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                name: 'saved',
                builder: (_, _) => const SavedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: '/edit',
                    name: 'profile-edit',
                    builder: (_, _) => const ProfileEditScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (_, _) => const AboutScreen(),
      ),
      GoRoute(
        path: '/my-recipes',
        name: 'my-recipes',
        builder: (_, _) => const MyRecipesScreen(),
      ),
      GoRoute(
        path: '/recipes/:id',
        name: 'recipe-detail',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null || id <= 0
              ? const NotFoundScreen(message: 'Mã công thức không hợp lệ.')
              : RecipeDetailScreen(recipeId: id);
        },
      ),
      GoRoute(
        path: '/users/:userId',
        name: 'public-profile',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['userId'] ?? '');
          return id == null || id <= 0
              ? const NotFoundScreen(message: 'Mã người dùng không hợp lệ.')
              : PublicProfileScreen(userId: id);
        },
      ),
    ],
  );
}

/// Router bound to the auth state so redirects re-evaluate on login/logout.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(ref.container);
  ref.onDispose(router.dispose);
  return router;
});
