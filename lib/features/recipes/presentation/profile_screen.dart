import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/recipe.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/recipe_card.dart';
import 'widgets/state_views.dart';

/// Own profile: account header + saved & authored recipe shortcuts.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(ownProfileProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Tài khoản'),
        actions: [
          IconButton(
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => context.go('/profile/edit'),
            icon: const Icon(Icons.edit_rounded),
          ),
          _LogoutButton(),
        ],
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
              message: 'Đăng nhập để quản lý công thức và món đã lưu của bạn.',
              icon: Icons.person_outline_rounded,
              onAction: () => context.go('/login?from=/profile'),
              actionLabel: 'Đăng nhập',
            );
          }
          return profile.when(
            loading: () => const RecipeLoadingView(),
            error: (error, _) => RecipeErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(ownProfileProvider),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(ownProfileProvider),
              child: CustomScrollView(
                key: const Key('profile-scroll'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                    sliver: SliverList.list(
                      children: [
                        _ProfileHeader(
                          fullname: data.user.fullname ?? user.fullname,
                          username: data.user.username,
                          email: data.user.email,
                          avatar: data.user.avatar,
                          bio: data.user.bio,
                          isAdmin: data.user.isAdmin,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.bookmark_rounded,
                                label: 'Đã lưu',
                                value: '${data.savedRecipes.length}',
                                onTap: () => context.go('/saved'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.menu_book_rounded,
                                label: 'Công thức của tôi',
                                value: '${data.myRecipes.length}',
                                onTap: () async {
                                  await context.push('/my-recipes');
                                  ref.invalidate(ownProfileProvider);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Công thức mới của bạn',
                          actionVisible: data.myRecipes.isNotEmpty,
                          onAction: () async {
                            await context.push('/my-recipes');
                            ref.invalidate(ownProfileProvider);
                          },
                          onActionCreate: () => _openCreate(context),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (data.myRecipes.isEmpty)
                          _InlineHint(
                            message: 'Bạn chưa đăng công thức nào. Chia sẻ món đầu tiên ngay!',
                            actionLabel: 'Thêm công thức mới',
                            onAction: () => _openCreate(context),
                          )
                        else
                          SizedBox(
                            height: 290,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: data.myRecipes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final recipe = data.myRecipes[index];
                                return FeaturedRecipeCard(
                                  recipe: recipe,
                                  onTap: () => context.pushNamed(
                                    'recipe-detail',
                                    pathParameters: {'id': '${recipe.id}'},
                                  ),
                                  onToggleFavourite: null,
                                  isFavourite: false,
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _SectionHeader(
                          title: 'Món ăn đã lưu',
                          actionVisible: data.savedRecipes.isNotEmpty,
                          onAction: () => context.go('/saved'),
                          onActionCreate: () => context.go('/explore'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (data.savedRecipes.isEmpty)
                          const _InlineHint(
                            message: 'Lưu món yêu thích bằng nút đánh dấu trên mỗi món.',
                            actionLabel: null,
                            onAction: null,
                          )
                        else
                          ...data.savedRecipes
                              .take(3)
                              .map((recipe) => _SavedRow(recipe: recipe)),
                        const SizedBox(height: AppSpacing.lg),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.info_outline_rounded),
                            title: const Text('Về Recipe Sharing'),
                            subtitle: const Text(
                              'Tính năng, quy tắc cộng đồng và quyền riêng tư',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/about'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCreate(BuildContext context) => context.push('/recipes/create');
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullname,
    required this.username,
    required this.email,
    required this.avatar,
    required this.bio,
    required this.isAdmin,
  });

  final String? fullname;
  final String username;
  final String? email;
  final String? avatar;
  final String? bio;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Container(
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
                url: avatar,
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      fullname?.trim() != null && fullname!.trim().isNotEmpty
                          ? fullname!
                          : username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Chip(
                      label: const Text('Quản trị'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: AppColors.lime,
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text('@$username', style: Theme.of(context).textTheme.bodySmall),
              if (email != null && email!.trim().isNotEmpty)
                Text(email!, style: Theme.of(context).textTheme.bodySmall),
              if (bio != null && bio!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  bio!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      key: const Key('profile-stat-tap'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.oliveSoft),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionVisible,
    required this.onAction,
    required this.onActionCreate,
  });

  final String title;
  final bool actionVisible;
  final VoidCallback onAction;
  final VoidCallback onActionCreate;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      TextButton(onPressed: onActionCreate, child: const Text('Thêm mới')),
      if (actionVisible)
        TextButton(onPressed: onAction, child: const Text('Xem tất cả')),
    ],
  );
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.limeSurface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: LatestRecipeCard(
      recipe: recipe,
      onTap: () => context.pushNamed(
        'recipe-detail',
        pathParameters: {'id': '${recipe.id}'},
      ),
    ),
  );
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Đăng xuất',
    icon: const Icon(Icons.logout_rounded),
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text('Bạn có thể đăng nhập lại bất cứ lúc nào.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        final revoked = await ref.read(authStateProvider.notifier).logout();
        ref.invalidate(ownProfileProvider);
        if (context.mounted) {
          context.go('/');
          if (!revoked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã đăng xuất trên thiết bị. Không thể xác nhận thu hồi phiên trên máy chủ.',
                ),
              ),
            );
          }
        }
      }
    },
  );
}
