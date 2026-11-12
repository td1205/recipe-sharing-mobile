import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 72,
                color: AppColors.oliveSoft,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Không tìm thấy nội dung',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message ?? 'Liên kết có thể đã hết hạn hoặc không còn tồn tại.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
