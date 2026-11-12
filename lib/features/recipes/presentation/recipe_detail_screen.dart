import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_detail.dart';
import '../domain/recipe_tag.dart';
import '../application/cooking_sync_controller.dart';
import 'favourite_actions.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/state_views.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final int recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _ShoppingListSheet extends ConsumerStatefulWidget {
  const _ShoppingListSheet({
    required this.detail,
    required this.initialChecked,
  });
  final RecipeDetail detail;
  final Set<int> initialChecked;
  @override
  ConsumerState<_ShoppingListSheet> createState() => _ShoppingListSheetState();
}

class _ShoppingListSheetState extends ConsumerState<_ShoppingListSheet> {
  late Set<int> checked = {...widget.initialChecked};
  int servings = 1;
  @override
  void initState() {
    super.initState();
    servings = widget.detail.recipe.servings ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shoppingListChangesProvider, (_, changes) {
      final recipeChanges = changes[widget.detail.id];
      if (recipeChanges == null) return;
      setState(
        () => recipeChanges.forEach(
          (id, value) => value ? checked.add(id) : checked.remove(id),
        ),
      );
    });
    ref.listen(shoppingServingsProvider, (_, values) {
      final value = values[widget.detail.id];
      if (value != null) setState(() => servings = value);
    });
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Danh sách mua sắm',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Khẩu phần: '),
                IconButton(
                  onPressed: servings > 1
                      ? () => _setServings(servings - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$servings'),
                IconButton(
                  onPressed: () => _setServings(servings + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                children: widget.detail.ingredients.map((ingredient) {
                  final ingredientId = ingredient.id;
                  final isChecked =
                      ingredientId != null && checked.contains(ingredientId);
                  final baseServings = widget.detail.recipe.servings ?? 1;
                  final quantity = _scaledQuantity(
                    ingredient.quantity,
                    servings / baseServings,
                  );
                  return CheckboxListTile(
                    value: isChecked,
                    title: Text(
                      quantity.isEmpty
                          ? ingredient.name
                          : '$quantity ${ingredient.name}',
                      style: TextStyle(
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    onChanged: ingredientId == null
                        ? null
                        : (value) async {
                            final next = value ?? false;
                            setState(
                              () => next
                                  ? checked.add(ingredientId)
                                  : checked.remove(ingredientId),
                            );
                            try {
                              await ref
                                  .read(recipeRepositoryProvider)
                                  .setShoppingListItem(
                                    widget.detail.id,
                                    ingredientId,
                                    next,
                                  );
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => next
                                      ? checked.remove(ingredientId)
                                      : checked.add(ingredientId),
                                );
                              }
                            }
                          },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scaledQuantity(String quantity, double scale) {
    if (scale == 1) return quantity;
    final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)(.*)$').firstMatch(quantity);
    final amount = match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null) return quantity;
    final scaled = amount * scale;
    final shown = scaled == scaled.roundToDouble()
        ? scaled.round().toString()
        : scaled.toStringAsFixed(1);
    return '$shown${match!.group(2)}';
  }

  Future<void> _setServings(int value) async {
    setState(() => servings = value);
    try {
      await ref
          .read(recipeRepositoryProvider)
          .setShoppingListServings(widget.detail.id, value);
    } catch (_) {}
  }
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  final _scrollController = ScrollController();
  final _stepsKey = GlobalKey();
  Timer? _viewTimer;

  @override
  void dispose() {
    _viewTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// View tracking mirrors the web: fire once after ~8s dwell on the page.
  void _ensureViewTimerStarted() {
    _viewTimer ??= Timer(const Duration(seconds: 8), () {
      ref
          .read(recipeRepositoryProvider)
          .markViewed(widget.recipeId)
          .catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(recipeDetailProvider(widget.recipeId));
    final data = detail.asData?.value;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/explore'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Công thức'),
        centerTitle: true,
        actions: data == null
            ? const []
            : [
                IconButton(
                  key: const Key('detail-favourite'),
                  tooltip: data.isFavourite
                      ? 'Bỏ lưu công thức'
                      : 'Lưu công thức',
                  onPressed: () => _toggleSave(data),
                  icon: Icon(
                    data.isFavourite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
                _ReportAction(recipeId: data.id),
                _OwnerMenu(detail: data),
                const SizedBox(width: AppSpacing.xs),
              ],
      ),
      body: detail.when(
        loading: () => const RecipeLoadingView(),
        error: (error, _) => RecipeErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
        ),
        data: (data) {
          _ensureViewTimerStarted();
          return _DetailContent(
            detail: data,
            scrollController: _scrollController,
            stepsKey: _stepsKey,
          );
        },
      ),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton.icon(
                key: const Key('start-cooking'),
                onPressed: () => _scrollToSteps(data),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Bắt đầu nấu'),
              ),
            ),
    );
  }

  Future<void> _toggleSave(RecipeDetail detail) async {
    await toggleRecipeFavourite(
      context,
      ref,
      recipeId: detail.id,
      makingFavourite: !detail.isFavourite,
    );
    ref.invalidate(recipeDetailProvider(detail.id));
  }

  void _scrollToSteps(RecipeDetail detail) {
    ref
        .read(cookingSyncProvider.notifier)
        .startCooking(detail.id, detail.steps.length);
    final target = _stepsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }
}

enum _OwnerChoice { edit, delete }

class _ReportAction extends ConsumerWidget {
  const _ReportAction({required this.recipeId});

  final int recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authStateProvider).value == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('report-recipe'),
      tooltip: 'Báo cáo công thức',
      onPressed: () => _showReportDialog(
        context,
        ref,
        targetType: 'recipe',
        targetId: recipeId,
        label: 'công thức',
      ),
      icon: const Icon(Icons.flag_outlined),
    );
  }
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required int targetId,
  required String label,
}) async {
  final controller = TextEditingController();
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> submit() async {
          final reason = controller.text.trim();
          if (reason.isEmpty || reason.length > 1000 || busy) return;
          setDialogState(() {
            busy = true;
            error = null;
          });
          try {
            await ref
                .read(recipeRepositoryProvider)
                .createReport(
                  targetType: targetType,
                  targetId: targetId,
                  reason: reason,
                );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi báo cáo đến quản trị viên.'),
                  ),
                );
            }
          } on ApiException catch (exception) {
            setDialogState(() {
              busy = false;
              error = exception.message;
            });
          }
        }

        return AlertDialog(
          title: Text('Báo cáo $label'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: Key('report-$targetType-reason'),
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 1000,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Lý do báo cáo',
                    hintText: 'Nêu rõ vi phạm, không gửi thông tin riêng tư.',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: Key('report-$targetType-submit'),
              onPressed: busy ? null : submit,
              child: Text(busy ? 'Đang gửi...' : 'Gửi báo cáo'),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
}

class _OwnerMenu extends ConsumerWidget {
  const _OwnerMenu({required this.detail});

  final RecipeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final canManage =
        user != null &&
        detail.authorUserId != null &&
        (user.isAdmin || user.id == detail.authorUserId);
    if (!canManage) return const SizedBox.shrink();
    return PopupMenuButton<_OwnerChoice>(
      onSelected: (choice) async {
        switch (choice) {
          case _OwnerChoice.edit:
            await context.push('/recipes/${detail.id}/edit');
          case _OwnerChoice.delete:
            await _confirmDelete(context, ref);
        }
      },
      icon: const Icon(Icons.more_vert_rounded),
      itemBuilder: (menuContext) => const [
        PopupMenuItem(
          value: _OwnerChoice.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.edit_rounded),
            title: Text('Chỉnh sửa'),
          ),
        ),
        PopupMenuItem(
          value: _OwnerChoice.delete,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Color(0xffba1a1a),
            ),
            title: Text('Xoá công thức'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá công thức?'),
        content: const Text(
          'Hành động này sẽ xoá vĩnh viễn món ăn khỏi hệ thống.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(recipeRepositoryProvider).deleteRecipe(detail.id);
      ref.invalidate(homeProvider);
      ref.invalidate(ownProfileProvider);
      ref.invalidate(exploreProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Đã xoá công thức.')));
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({
    required this.detail,
    required this.scrollController,
    required this.stepsKey,
  });

  final RecipeDetail detail;
  final ScrollController scrollController;
  final GlobalKey stepsKey;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  double _scale = 1;
  final _checkedIngredients = <int>{};
  late final TextEditingController _commentController;
  bool _sendingComment = false;
  bool _sendingRating = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cookingSyncProvider.notifier).loadProgress(widget.detail.id);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final recipe = detail.recipe;
    ref.listen<String?>(cookingSyncErrorProvider, (previous, next) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next)));
      ref.read(cookingSyncErrorProvider.notifier).set(null);
    });
    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(recipeDetailProvider(widget.detail.id)),
      child: CustomScrollView(
        key: const Key('detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        controller: widget.scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
            sliver: SliverList.list(
              children: [
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                _AuthorRow(detail: detail),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Hero(
                      tag: 'recipe-${recipe.id}',
                      child: AppNetworkImage(
                        url: recipe.imageUrl,
                        semanticLabel: 'Ảnh món ${recipe.title}',
                      ),
                    ),
                  ),
                ),
                if (recipe.description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ExpandableDescription(text: recipe.description!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _RecipeStats(recipe: recipe),
                if (detail.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _TagsRow(recipeId: detail.id, tags: detail.tags),
                ],
                const SizedBox(height: AppSpacing.md),
                _IngredientsSection(
                  ingredients: detail.ingredients,
                  scale: _scale,
                  checked: _checkedIngredients,
                  onScaleChanged: (value) => setState(() => _scale = value),
                  onIngredientToggled: (index) => setState(
                    () => _checkedIngredients.contains(index)
                        ? _checkedIngredients.remove(index)
                        : _checkedIngredients.add(index),
                  ),
                  onShoppingList: _openShoppingList,
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: widget.stepsKey,
                  child: _StepsSection(
                    recipeId: detail.id,
                    steps: detail.steps,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _RatingSection(
                  detail: detail,
                  busy: _sendingRating,
                  onSubmit: _submitRating,
                ),
                const SizedBox(height: AppSpacing.md),
                _CommentsSection(
                  detail: detail,
                  controller: _commentController,
                  sending: _sendingComment,
                  onSubmit: _submitComment,
                ),
                if (detail.relatedRecipes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _RelatedSection(related: detail.relatedRecipes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShoppingList() async {
    final detail = widget.detail;
    final checked = await ref
        .read(recipeRepositoryProvider)
        .getShoppingList(detail.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ShoppingListSheet(detail: detail, initialChecked: checked),
    );
  }

  Future<void> _submitRating(int stars) async {
    final detail = widget.detail;
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      final goLogin = await showLoginRequiredDialog(context, 'đánh giá món ăn');
      if (goLogin && mounted) {
        context.go('/login?from=/recipes/${detail.id}');
      }
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingRating = true);
    try {
      await ref.read(recipeRepositoryProvider).rateRecipe(detail.id, stars);
      ref.invalidate(recipeDetailProvider(detail.id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Đã đánh giá $stars sao. Cảm ơn bạn!')),
        );
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sendingRating = false);
    }
  }

  Future<void> _submitComment() async {
    final detail = widget.detail;
    final content = _commentController.text.trim();
    if (content.isEmpty || _sendingComment) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      final goLogin = await showLoginRequiredDialog(
        context,
        'bình luận về món ăn',
      );
      if (goLogin && mounted) {
        context.go('/login?from=/recipes/${detail.id}');
      }
      return;
    }
    if (content.length > 2000) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Bình luận tối đa 2000 ký tự.')),
        );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingComment = true);
    try {
      await ref.read(recipeRepositoryProvider).addComment(detail.id, content);
      _commentController.clear();
      ref.invalidate(recipeDetailProvider(detail.id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã thêm bình luận.')));
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.detail});
  final RecipeDetail detail;

  @override
  Widget build(BuildContext context) {
    final name = detail.authorFullname?.trim().isNotEmpty ?? false
        ? detail.authorFullname!
        : (detail.authorUsername ?? 'Ẩn danh');
    return Row(
      children: [
        if (detail.authorUserId != null)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => context.pushNamed(
              'public-profile',
              pathParameters: {'userId': '${detail.authorUserId}'},
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.limeSurface,
              child: ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: AppNetworkImage(
                    url: detail.authorAvatarUrl,
                    fallbackIcon: Icons.person_rounded,
                  ),
                ),
              ),
            ),
          )
        else
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.limeSurface,
            child: Icon(Icons.person_rounded, size: 18, color: AppColors.olive),
          ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Của $name',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (detail.recipe.categoryName != null)
                Text(
                  detail.recipe.categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        const Icon(
          Icons.visibility_outlined,
          size: 18,
          color: AppColors.oliveSoft,
        ),
        const SizedBox(width: 4),
        Text(
          '${detail.recipe.viewCount}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.text,
        maxLines: _expanded ? null : 4,
        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      if (widget.text.length > 180)
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? 'Thu gọn' : 'Xem thêm'),
        ),
    ],
  );
}

class _RecipeStats extends StatelessWidget {
  const _RecipeStats({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 3;
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: AppSpacing.md,
          children: [
            _Stat(
              width: itemWidth,
              icon: Icons.people_alt_outlined,
              label: 'Khẩu phần',
              value: recipe.servings == null ? '—' : '${recipe.servings} người',
            ),
            _Stat(
              width: itemWidth,
              icon: Icons.timer_outlined,
              label: 'Chuẩn bị',
              value: _minutes(recipe.prepTime),
            ),
            _Stat(
              width: itemWidth,
              icon: Icons.local_fire_department_outlined,
              label: 'Nấu',
              value: _minutes(recipe.cookTime),
            ),
          ],
        );
      },
    ),
  );

  String _minutes(int? value) => value == null ? '—' : '$value phút';
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      children: [
        Icon(icon, size: 20, color: AppColors.oliveSoft),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(value, maxLines: 2, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.recipeId, required this.tags});

  final int recipeId;
  final List<RecipeTag> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.xs,
    children: [
      ...tags.map(
        (tag) => ActionChip(
          label: Text(
            tag.isCommunity
                ? '${tag.name} · ${tag.voteCount} bình chọn'
                : tag.name,
          ),
          labelStyle: Theme.of(context).textTheme.labelMedium,
          backgroundColor: AppColors.limeSurface,
          side: BorderSide.none,
          tooltip: 'Xem các món có tag "${tag.name}"',
          onPressed: () =>
              context.push('/explore?tag=${Uri.encodeComponent(tag.name)}'),
        ),
      ),
      ActionChip(
        key: const Key('community-tag-action'),
        avatar: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Gắn tag cộng đồng'),
        onPressed: () => _showTagSheet(context, ref, recipeId, tags),
      ),
    ],
  );
}

Future<void> _showTagSheet(
  BuildContext context,
  WidgetRef ref,
  int recipeId,
  List<RecipeTag> tags,
) async {
  if (ref.read(authStateProvider).value == null) {
    await context.push('/login?from=/recipes/$recipeId');
    return;
  }
  final controller = TextEditingController();
  var busy = false;
  String? error;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        Future<void> submit(String raw) async {
          final tag = raw.trim().toLowerCase();
          if (tag.isEmpty || tag.length > 50 || busy) return;
          setSheetState(() {
            busy = true;
            error = null;
          });
          try {
            final added = await ref
                .read(recipeRepositoryProvider)
                .voteTag(recipeId, tag);
            ref.invalidate(recipeDetailProvider(recipeId));
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      added
                          ? 'Đã gắn tag “$tag”.'
                          : 'Đã bỏ bình chọn tag “$tag”.',
                    ),
                  ),
                );
            }
          } on ApiException catch (exception) {
            setSheetState(() {
              error = exception.message;
              busy = false;
            });
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tag cộng đồng',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Chọn tag có sẵn để bình chọn hoặc nhập tag mới. Chọn lại sẽ bỏ bình chọn.',
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: tags
                        .map(
                          (tag) => ActionChip(
                            label: Text('#${tag.name}'),
                            onPressed: busy ? null : () => submit(tag.name),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('community-tag-input'),
                  controller: controller,
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                  onSubmitted: submit,
                  decoration: const InputDecoration(
                    labelText: 'Tag mới, ví dụ: dễ làm',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const Key('community-tag-submit'),
                  onPressed: busy ? null : () => submit(controller.text),
                  child: Text(busy ? 'Đang gửi...' : 'Gắn hoặc bỏ tag'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  controller.dispose();
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({
    required this.ingredients,
    required this.scale,
    required this.checked,
    required this.onScaleChanged,
    required this.onIngredientToggled,
    required this.onShoppingList,
  });

  final List<RecipeIngredient> ingredients;
  final double scale;
  final Set<int> checked;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<int> onIngredientToggled;
  final VoidCallback onShoppingList;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.limeSurface,
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: ExpansionTile(
      key: const Key('ingredients-section'),
      initiallyExpanded: true,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      title: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Nguyên liệu', style: Theme.of(context).textTheme.titleLarge),
          TextButton.icon(
            onPressed: onShoppingList,
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text('Danh sách mua sắm'),
          ),
        ],
      ),
      children: [
        if (ingredients.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Chưa có dữ liệu nguyên liệu.'),
          )
        else
          ...List.generate(
            ingredients.length,
            (index) => _IngredientLine(
              name: ingredients[index].name,
              scaled: ingredients[index].quantity.isEmpty
                  ? null
                  : _scaleQuantity(ingredients[index].quantity, scale),
              checked: checked.contains(index),
              onToggle: () => onIngredientToggled(index),
            ),
          ),
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.scale_rounded,
                  size: 18,
                  color: AppColors.oliveSoft,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Điều chỉnh khẩu phần',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final step in const [1, 2, 3, 4, 6, 8])
                  SizedBox(
                    height: 48,
                    child: ChoiceChip(
                      label: Text('$step×'),
                      selected: scale == step.toDouble(),
                      onSelected: (_) => onScaleChanged(step.toDouble()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  String _scaleQuantity(String quantity, double scale) {
    if (scale == 1) return quantity;
    final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)(.*)$').firstMatch(quantity);
    if (match == null) return quantity;
    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null) return quantity;
    final scaled = amount * scale;
    final formatted = scaled == scaled.roundToDouble()
        ? scaled.round().toString()
        : scaled.toStringAsFixed(1);
    return '$formatted${match.group(2)}';
  }
}

class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    required this.name,
    required this.scaled,
    required this.checked,
    required this.onToggle,
  });

  final String name;
  final String? scaled;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final quantity = scaled ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onToggle,
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                name,
                style: checked
                    ? const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.inkMuted,
                      )
                    : null,
              ),
            ),
            if (quantity.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Text(
                  quantity,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepsSection extends ConsumerWidget {
  const _StepsSection({required this.recipeId, required this.steps});
  final int recipeId;
  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(cookingProgressProvider)[recipeId];
    final isComplete =
        progress != null &&
        progress.totalSteps > 0 &&
        progress.completedSteps == progress.totalSteps;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Các bước chế biến',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (progress != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isComplete) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xff166534),
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      isComplete
                          ? 'Hoàn thành'
                          : '${progress.completedSteps}/${progress.totalSteps}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isComplete ? const Color(0xff166534) : null,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (isComplete) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffdcfce7),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration_rounded, color: Color(0xff166534)),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Đã hoàn thành món ăn!',
                        style: TextStyle(
                          color: Color(0xff166534),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (steps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Chưa có dữ liệu bước chế biến.'),
            )
          else
            ...steps.map((step) {
              final isDone =
                  progress != null && step.number <= progress.completedSteps;
              final isCurrent =
                  progress != null && step.number == progress.currentStep;
              final surface = isDone
                  ? const Color(0xffdcfce7)
                  : isCurrent
                  ? const Color(0xfffff1b8)
                  : Colors.transparent;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDone
                          ? const Color(0xff166534)
                          : AppColors.olive,
                      foregroundColor: AppColors.white,
                      child: Text('${step.number}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.instruction,
                            style: isDone
                                ? const TextStyle(
                                    color: Color(0xff166534),
                                    fontWeight: FontWeight.w600,
                                  )
                                : null,
                          ),
                          if (isCurrent) ...[
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                ref
                                    .read(cookingSyncProvider.notifier)
                                    .completeCurrentStep(
                                      recipeId,
                                      steps.length,
                                    );
                                if (step.number == steps.length) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Text(
                                                'Đã hoàn thành món ăn!',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                }
                              },
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                step.number == steps.length
                                    ? 'Hoàn tất món ăn'
                                    : 'Hoàn thành bước này',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.detail,
    required this.busy,
    required this.onSubmit,
  });

  final RecipeDetail detail;
  final bool busy;
  final Future<void> Function(int stars) onSubmit;

  @override
  Widget build(BuildContext context) {
    final recipe = detail.recipe;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đánh giá', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 28,
                color: recipe.averageRating > 0
                    ? const Color(0xffe2b348)
                    : AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                recipe.averageRating > 0
                    ? recipe.averageRating.toStringAsFixed(1)
                    : '—',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(${recipe.totalRatings} lượt)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Chấm điểm món này:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          IgnorePointer(
            ignoring: busy,
            child: Row(
              children: List.generate(
                5,
                (index) => IconButton(
                  key: Key('rating-star-${index + 1}'),
                  tooltip: '${index + 1} sao',
                  onPressed: () => onSubmit(index + 1),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.star_rounded,
                    size: 32,
                    color: index < (detail.userRating ?? 0)
                        ? const Color(0xffe2b348)
                        : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({
    required this.detail,
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });

  final RecipeDetail detail;
  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = detail.comments;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bình luận (${comments.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (comments.isEmpty)
            const Text(
              'Chưa có bình luận nào. Hãy là người đầu tiên chia sẻ nhé!',
              style: TextStyle(color: AppColors.inkMuted),
            )
          else
            ...comments.map(
              (comment) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.limeSurface,
                      child: ClipOval(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: AppNetworkImage(
                            url: comment.avatarUrl,
                            fallbackIcon: Icons.person_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.authorDisplayName,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            comment.content,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (ref.watch(authStateProvider).value != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                key: Key('report-comment-${comment.id}'),
                                onPressed: () => _showReportDialog(
                                  context,
                                  ref,
                                  targetType: 'comment',
                                  targetId: comment.id,
                                  label: 'bình luận',
                                ),
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: const Text('Báo cáo'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          TextField(
            key: const Key('comment-input'),
            controller: controller,
            maxLines: 2,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: 'Chia sẻ suy nghĩ của bạn về món này...',
              counterText: '',
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const Key('comment-submit'),
              onPressed: sending ? null : () => onSubmit(),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Gửi bình luận'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({required this.related});
  final List<Recipe> related;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Các món gợi ý', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: related.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final recipe = related[index];
            return SizedBox(
              width: 150,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.pushNamed(
                    'recipe-detail',
                    pathParameters: {'id': '${recipe.id}'},
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppNetworkImage(
                          url: recipe.imageUrl,
                          semanticLabel: 'Ảnh món ${recipe.title}',
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
