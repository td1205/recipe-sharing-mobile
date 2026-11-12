import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_error_banner.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/upload/cloudinary_uploader.dart';
import '../domain/category.dart';
import 'recipe_providers.dart';
import 'widgets/app_network_image.dart';
import 'widgets/state_views.dart';

/// Create and edit recipe form, mirroring the web
/// `POST /api/recipes/create` / `POST /api/recipes/edit/:id` payloads.
class RecipeFormScreen extends ConsumerStatefulWidget {
  const RecipeFormScreen({super.key, this.recipeId});

  final int? recipeId;

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _IngredientDraft {
  _IngredientDraft();
  final name = TextEditingController();
  final amount = TextEditingController();
  final unit = TextEditingController();
  final key = UniqueKey();

  void dispose() {
    name.dispose();
    amount.dispose();
    unit.dispose();
  }
}

class _StepDraft {
  _StepDraft();
  final instruction = TextEditingController();
  final key = UniqueKey();

  void dispose() => instruction.dispose();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _videoUrl;
  late final TextEditingController _tagInput;
  final _ingredients = <_IngredientDraft>[];
  final _steps = <_StepDraft>[];
  final _tags = <String>[];

  RecipeCategory? _category;
  RecipeCategory? _mealTime;
  RecipeCategory? _courseType;
  final _prepController = TextEditingController();
  final _cookController = TextEditingController();
  final _servingsController = TextEditingController();
  bool _submitting = false;
  bool _uploading = false;
  String? _errors;
  List<String> _serverErrors = const [];
  List<RecipeCategory> _categories = const [];
  List<RecipeCategory> _mealTimes = const [];
  List<RecipeCategory> _courseTypes = const [];
  bool _loaded = false;
  String? _localImagePath;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _description = TextEditingController();
    _imageUrl = TextEditingController();
    _videoUrl = TextEditingController();
    _tagInput = TextEditingController();
    if (widget.recipeId == null) {
      _ingredients.add(_IngredientDraft());
      _steps.add(_StepDraft());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _imageUrl,
      _videoUrl,
      _tagInput,
      _prepController,
      _cookController,
      _servingsController,
    ]) {
      controller.dispose();
    }
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(recipeRepositoryProvider);
    try {
      if (widget.recipeId == null) {
        final navData = await repository.getFormData();
        // Filter sheets and the form use the same option source.
        final shared = navData.categories;
        setState(() {
          _categories = shared.isNotEmpty ? shared : _categories;
          _mealTimes = navData.mealTimes;
          _courseTypes = navData.courseTypes;
          _loaded = true;
        });
        return;
      }
      final (detail, formData) = await repository.getEditData(widget.recipeId!);
      final recipe = detail.recipe;
      _title.text = recipe.title;
      _description.text = recipe.description ?? '';
      _imageUrl.text = recipe.imageUrl ?? '';
      _prepController.text = recipe.prepTime?.toString() ?? '';
      _cookController.text = recipe.cookTime?.toString() ?? '';
      _servingsController.text = recipe.servings?.toString() ?? '';
      _ingredients.clear();
      for (final ingredient in detail.ingredients) {
        final row = _IngredientDraft();
        row.name.text = ingredient.name;
        row.amount.text = ingredient.amount ?? '';
        row.unit.text = ingredient.unit ?? '';
        _ingredients.add(row);
      }
      _steps.clear();
      for (final step in detail.steps) {
        final row = _StepDraft();
        row.instruction.text = step.instruction;
        _steps.add(row);
      }
      _tags
        ..clear()
        ..addAll(detail.tags.map((tag) => tag.name));
      setState(() {
        _categories = formData.categories;
        _mealTimes = formData.mealTimes;
        _courseTypes = formData.courseTypes;
        _category = _find(_categories, recipe.categoryId);
        _mealTime = _find(_mealTimes, recipe.mealTimeId);
        _courseType = _find(_courseTypes, recipe.courseTypeId);
        _loaded = true;
      });
    } on ApiException catch (error) {
      setState(() => _errors = error.message);
    }
  }

  RecipeCategory? _find(List<RecipeCategory> options, int? id) {
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;
      _localImagePath = picked.path;
      final uploader = const CloudinaryUploader();
      if (uploader.isConfigured) {
        setState(() => _uploading = true);
        try {
          final result = await uploader.upload(
            fileBytes: await File(picked.path).readAsBytes(),
            filename: picked.name,
            mimeType: picked.mimeType ?? 'image/jpeg',
          );
          _imageUrl.text = result.url;
        } on CloudinaryException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error.message)));
          }
        } finally {
          if (mounted) setState(() => _uploading = false);
        }
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa cấu hình Cloudinary — hãy dán đường dẫn ảnh (URL) vào ô bên dưới.',
              ),
            ),
          );
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Không chọn được ảnh.')));
      }
    }
  }

  Map<String, Object?> _buildPayload() => {
    'title': _title.text.trim(),
    'description': _description.text.trim(),
    'category_id': _category?.id,
    'meal_time_id': _mealTime?.id,
    'course_type_id': _courseType?.id,
    'prep_time': _prepController.text.trim().isEmpty
        ? 0
        : int.tryParse(_prepController.text.trim()) ?? 0,
    'cook_time': _cookController.text.trim().isEmpty
        ? 0
        : int.tryParse(_cookController.text.trim()) ?? 0,
    'servings': _servingsController.text.trim().isEmpty
        ? 1
        : int.tryParse(_servingsController.text.trim()) ?? 1,
    'image_url': _imageUrl.text.trim(),
    'video_url': _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
    'ing_name': [
      for (final row in _ingredients)
        if (row.name.text.trim().isNotEmpty) row.name.text.trim(),
    ],
    'ing_amount': [
      for (final row in _ingredients)
        if (row.name.text.trim().isNotEmpty) row.amount.text.trim(),
    ],
    'ing_unit': [
      for (final row in _ingredients)
        if (row.name.text.trim().isNotEmpty) row.unit.text.trim(),
    ],
    'step_instruction': [
      for (final row in _steps)
        if (row.instruction.text.trim().isNotEmpty) row.instruction.text.trim(),
    ],
    'tags': _tags,
  };

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;
    setState(() {
      _errors = null;
      _serverErrors = const [];
      _submitting = true;
    });
    final repository = ref.read(recipeRepositoryProvider);
    try {
      final payload = _buildPayload();
      if (widget.recipeId == null) {
        final recipeId = await repository.createRecipe(payload);
        ref.invalidate(homeProvider);
        ref.invalidate(ownProfileProvider);
        ref.invalidate(exploreProvider);
        ref.invalidate(recipeDetailProvider(recipeId));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Đã đăng công thức mới!')),
          );
        context.go('/recipes/$recipeId');
      } else {
        await repository.updateRecipe(widget.recipeId!, payload);
        ref.invalidate(homeProvider);
        ref.invalidate(ownProfileProvider);
        ref.invalidate(exploreProvider);
        ref.invalidate(recipeDetailProvider(widget.recipeId!));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Đã lưu thay đổi công thức.')),
          );
        context.go('/recipes/${widget.recipeId}');
      }
    } on ApiException catch (error) {
      setState(() => _errors = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateInt(String? value, {required String label, int? min}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final number = int.tryParse(raw);
    if (number == null || number < 0) {
      return '$label phải là số nguyên không âm.';
    }
    if (min != null && number < min) return '$label tối thiểu $min.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackLocation: '/my-recipes'),
          title: Text(
            widget.recipeId == null ? 'Thêm công thức' : 'Chỉnh sửa công thức',
          ),
        ),
        body: _RecipeFormInitialize(onReady: _load, errors: _errors),
      );
    }
    final isEdit = widget.recipeId != null;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/my-recipes'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(isEdit ? 'Chỉnh sửa công thức' : 'Thêm công thức mới'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const Key('form-title'),
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên món *',
                prefixIcon: Icon(Icons.restaurant_menu_rounded),
              ),
              validator: (value) {
                final title = value?.trim() ?? '';
                if (title.isEmpty) return 'Tên món là bắt buộc.';
                if (title.length < 3 || title.length > 255) {
                  return 'Tên món phải dài từ 3 đến 255 ký tự.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('form-description'),
              controller: _description,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Mô tả ngắn *',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              validator: (value) {
                final description = value?.trim() ?? '';
                if (description.isEmpty) return 'Mô tả là bắt buộc.';
                if (description.length > 5000) {
                  return 'Mô tả tối đa 5000 ký tự.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<RecipeCategory>(
              key: const Key('form-category'),
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Danh mục *',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: [
                for (final category in _categories)
                  DropdownMenuItem(value: category, child: Text(category.name)),
              ],
              onChanged: (value) => setState(() => _category = value),
              validator: (value) =>
                  value == null ? 'Vui lòng chọn danh mục.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecipeCategory>(
                    initialValue: _mealTime,
                    decoration: const InputDecoration(labelText: 'Bữa ăn'),
                    items: [
                      for (final option in _mealTimes)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _mealTime = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<RecipeCategory>(
                    initialValue: _courseType,
                    decoration: const InputDecoration(labelText: 'Loại món'),
                    items: [
                      for (final option in _courseTypes)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _courseType = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chuẩn bị (phút)',
                    ),
                    validator: (value) =>
                        _validateInt(value, label: 'Thời gian chuẩn bị'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _cookController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nấu (phút)'),
                    validator: (value) =>
                        _validateInt(value, label: 'Thời gian chế biến'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Khẩu phần'),
                    validator: (value) =>
                        _validateInt(value, label: 'Khẩu phần', min: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _ImagePickerSection(
              imageUrl: _imageUrl,
              localPath: _localImagePath,
              uploading: _uploading,
              onPick: _pickImage,
            ),
            const SizedBox(height: AppSpacing.lg),
            _IngredientsEditor(
              rows: _ingredients,
              onAdd: () => setState(() => _ingredients.add(_IngredientDraft())),
              onRemove: (row) => setState(() => _ingredients.remove(row)),
            ),
            const SizedBox(height: AppSpacing.lg),
            _StepsEditor(
              rows: _steps,
              onAdd: () => setState(() => _steps.add(_StepDraft())),
              onRemove: (row) => setState(() => _steps.remove(row)),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TagsEditor(
              tags: _tags,
              controller: _tagInput,
              onAdd: (value) {
                for (final raw in value.split(',')) {
                  final tag = raw.trim().toLowerCase();
                  if (tag.isNotEmpty &&
                      !_tags.contains(tag) &&
                      _tags.length < 10) {
                    setState(() => _tags.add(tag));
                  }
                }
              },
              onRemove: (tag) => setState(() => _tags.remove(tag)),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errors != null) ...[AppErrorBanner(message: _errors!)],
            if (_serverErrors.isNotEmpty) ...[
              if (_errors != null) const SizedBox(height: AppSpacing.sm),
              AppErrorBanner(message: _serverErrors.join('\n')),
            ],
            if (_errors != null) const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('form-submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(isEdit ? 'Lưu thay đổi' : 'Đăng công thức'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Bootstraps form data + edit payload before rendering the form fields.
class _RecipeFormInitialize extends ConsumerStatefulWidget {
  const _RecipeFormInitialize({required this.onReady, required this.errors});

  final void Function() onReady;
  final String? errors;

  @override
  ConsumerState<_RecipeFormInitialize> createState() =>
      _RecipeFormInitializeState();
}

class _RecipeFormInitializeState extends ConsumerState<_RecipeFormInitialize> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      scheduleMicrotaskState(() => widget.onReady());
    }
  }

  void scheduleMicrotaskState(void Function() action) {
    Future<void>.microtask(action);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errors != null) {
      return RecipeErrorView(
        message: widget.errors!,
        onRetry: () => setState(() => _started = false),
      );
    }
    return const RecipeLoadingView();
  }
}

class _ImagePickerSection extends StatelessWidget {
  const _ImagePickerSection({
    required this.imageUrl,
    required this.localPath,
    required this.uploading,
    required this.onPick,
  });

  final TextEditingController imageUrl;
  final String? localPath;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final previewUrl = imageUrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ảnh món ăn *',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(uploading ? 'Đang tải lên...' : 'Chọn ảnh'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (previewUrl.isNotEmpty || localPath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: previewUrl.isNotEmpty
                  ? AppNetworkImage(url: previewUrl)
                  : Image.file(File(localPath!), fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const Key('form-image-url'),
          controller: imageUrl,
          decoration: const InputDecoration(
            labelText: 'Hoặc dán đường dẫn ảnh (URL)',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          validator: (value) {
            final url = value?.trim() ?? '';
            if (url.isEmpty) return 'Cần ít nhất một ảnh cho món ăn.';
            if (!RegExp(r'^https?://').hasMatch(url)) {
              return 'URL phải bắt đầu bằng http:// hoặc https://.';
            }
            return null;
          },
          onChanged: null,
        ),
      ],
    );
  }
}

// (no helpers needed)

class _IngredientsEditor extends StatelessWidget {
  const _IngredientsEditor({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_IngredientDraft> rows;
  final VoidCallback onAdd;
  final ValueChanged<_IngredientDraft> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Nguyên liệu *',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm dòng'),
          ),
        ],
      ),
      ...rows.map(
        (row) => Padding(
          key: ValueKey(row.key),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: row.name,
                  decoration: const InputDecoration(
                    labelText: 'Nguyên liệu',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.amount,
                  decoration: const InputDecoration(
                    labelText: 'Lượng',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: row.unit,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xoá dòng',
                onPressed: () => onRemove(row),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _StepsEditor extends StatelessWidget {
  const _StepsEditor({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_StepDraft> rows;
  final VoidCallback onAdd;
  final ValueChanged<_StepDraft> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Các bước thực hiện *',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm bước'),
          ),
        ],
      ),
      ...List.generate(
        rows.length,
        (index) => Padding(
          key: ValueKey(rows[index].key),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.olive,
                foregroundColor: AppColors.white,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: Key('form-step-${index + 1}'),
                  controller: rows[index].instruction,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Bước ${index + 1}',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xoá bước',
                onPressed: () => onRemove(rows[index]),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _TagsEditor extends StatelessWidget {
  const _TagsEditor({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Thẻ gợi ý (${tags.length}/10)',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: AppSpacing.sm),
      if (tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: tags
                .map(
                  (tag) => InputChip(
                    label: Text(tag.toLowerCase()),
                    onDeleted: () => onRemove(tag),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      TextField(
        controller: controller,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          onAdd(value);
          controller.clear();
        },
        decoration: const InputDecoration(
          labelText: 'Nhập tag (cách nhau bởi dấu phẩy)',
          helperText: 'Ví dụ: dễ làm, chay, ít calo',
          helperMaxLines: 2,
          prefixIcon: Icon(Icons.tag_rounded),
        ),
      ),
    ],
  );
}
