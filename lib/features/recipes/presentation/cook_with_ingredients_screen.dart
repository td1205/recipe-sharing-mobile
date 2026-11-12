import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/recipe.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';

/// Cook with what you have: pantry items → `/api/recommendations/by-ingredients`.
class CookWithIngredientsScreen extends ConsumerStatefulWidget {
  const CookWithIngredientsScreen({super.key});

  @override
  ConsumerState<CookWithIngredientsScreen> createState() =>
      _CookWithIngredientsScreenState();
}

class _CookWithIngredientsScreenState
    extends ConsumerState<CookWithIngredientsScreen> {
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) {
    ref.read(cookProvider.notifier).addItem(value);
    _itemController.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cook = ref.watch(cookProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Nấu với nguyên liệu sẵn có'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
              sliver: SliverList.list(
                children: [
                  Text(
                    'Bạn có gì trong bếp?',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Nhập nguyên liệu bạn đang có (tối đa 15), mình sẽ gợi ý những món bạn có thể nấu ngay.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('cook-input'),
                          controller: _itemController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _onSubmitted,
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: trứng, cà chua, gạo...',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        key: const Key('cook-add'),
                        tooltip: 'Thêm nguyên liệu',
                        onPressed: () => _onSubmitted(_itemController.text),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  if (cook.pantryItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      key: const Key('cook-chips'),
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: cook.pantryItems
                          .map(
                            (item) => InputChip(
                              label: Text(item),
                              onDeleted: () {
                                ref
                                    .read(cookProvider.notifier)
                                    .removeItem(item);
                                setState(() {});
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const Key('cook-submit'),
                      onPressed: cook.isLoading
                          ? null
                          : () async {
                              await ref.read(cookProvider.notifier).submit();
                              if (mounted) setState(() {});
                            },
                      icon: const Icon(Icons.soup_kitchen_rounded),
                      label: Text(
                        cook.isLoading
                            ? 'Đang tìm món...'
                            : 'Tìm món có thể nấu',
                      ),
                    ),
                  ],
                  if (cook.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      cook.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ...cook.results.map(
                    (recipe) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _CookResultTile(
                        recipe: recipe,
                        onTap: () => context.pushNamed(
                          'recipe-detail',
                          pathParameters: {'id': '${recipe.id}'},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookResultTile extends StatelessWidget {
  const _CookResultTile({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: AppNetworkImage(
              url: recipe.imageUrl,
              semanticLabel: 'Ảnh món ${recipe.title}',
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.oliveSoft,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        (recipe.totalMinutes != null
                            ? '${recipe.totalMinutes} phút'
                            : '—'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xffe2b348),
                      ),
                      Text(
                        recipe.averageRating > 0
                            ? recipe.averageRating.toStringAsFixed(1)
                            : '—',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
