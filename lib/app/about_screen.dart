import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'widgets/app_back_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(fallbackLocation: '/profile'),
      title: const Text('Về Recipe Sharing'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.restaurant_menu_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Chia sẻ công thức.\nKết nối căn bếp.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Khám phá món mới, lưu lại hương vị yêu thích và chia sẻ cách nấu với cộng đồng.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _AboutSection(
            icon: Icons.travel_explore_rounded,
            title: 'Khám phá theo cách của bạn',
            body: 'Tìm kiếm, lọc theo danh mục, nhận gợi ý cá nhân hóa hoặc dùng ảnh món ăn để bắt đầu.',
          ),
          const _AboutSection(
            icon: Icons.soup_kitchen_rounded,
            title: 'Đồng hành khi nấu',
            body: 'Cooking Mode theo dõi từng bước và đồng bộ tiến độ giữa Website với điện thoại.',
          ),
          const _AboutSection(
            icon: Icons.groups_rounded,
            title: 'Cộng đồng tích cực',
            body: 'Đánh giá có trách nhiệm, gắn tag hữu ích và báo cáo nội dung vi phạm. Không chia sẻ thông tin riêng tư trong bình luận.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Khám phá công thức'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Recipe Sharing Mobile · Bản demo đồ án',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    ),
  );
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.oliveSoft),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
