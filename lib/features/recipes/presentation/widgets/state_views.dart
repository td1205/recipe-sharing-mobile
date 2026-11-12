import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class RecipeLoadingView extends StatelessWidget {
  const RecipeLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(semanticsLabel: 'Đang tải công thức'),
  );
}

class RecipeErrorView extends StatelessWidget {
  const RecipeErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: AppColors.oliveSoft,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Không tải được dữ liệu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

class RecipeEmptyView extends StatelessWidget {
  const RecipeEmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.emoji_food_beverage_rounded,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.limeSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.oliveSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Small caption shown under a section title, e.g. result counts.
class RecipeCountCaption extends StatelessWidget {
  const RecipeCountCaption({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    count == 0 ? '—' : '$count món',
    style: Theme.of(context).textTheme.bodySmall,
  );
}
