import 'dart:io';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../core/network/api_exception.dart';
import '../../recipes/presentation/recipe_providers.dart'
    show ownProfileProvider;
import '../../recipes/presentation/widgets/app_network_image.dart';
import 'auth_providers.dart';

/// Edit own profile: `POST /api/profile/edit` (multipart with `avatar`).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _fullname;
  late final TextEditingController _email;
  late final TextEditingController _bio;
  File? _pickedAvatar;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _fullname = TextEditingController(text: user?.fullname ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _fullname.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _pickedAvatar = File(picked.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Không chọn được ảnh.')));
      }
    }
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || _submitting) return;
    final fullname = _fullname.text.trim();
    final email = _email.text.trim();
    if (fullname.isEmpty) {
      setState(() => _error = 'Vui lòng nhập họ tên.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Email không hợp lệ.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final file = _pickedAvatar;
      await ref
          .read(authStateProvider.notifier)
          .updateProfile(
            fullname: fullname,
            email: email,
            bio: _bio.text.trim(),
            avatarFile: file == null
                ? null
                : MultipartFile.fromBytes(
                    await file.readAsBytes(),
                    filename: file.uri.pathSegments.last,
                  ),
          );
      ref.invalidate(ownProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      context.go('/profile');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final avatarUrl = user?.avatarUrl;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/profile'),
        title: const Text('Chỉnh sửa hồ sơ'),
      ),
      body: user == null
          ? const Center(child: Text('Bạn chưa đăng nhập.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _pickedAvatar != null
                              ? CircleAvatar(
                                  radius: 52,
                                  backgroundImage: FileImage(_pickedAvatar!),
                                )
                              : CircleAvatar(
                                  radius: 52,
                                  backgroundColor: AppColors.limeSurface,
                                  child: ClipOval(
                                    child: SizedBox(
                                      width: 104,
                                      height: 104,
                                      child: AppNetworkImage(
                                        url: avatarUrl,
                                        fallbackIcon: Icons.person_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                          Positioned(
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.lime,
                              child: IconButton(
                                tooltip: 'Chọn ảnh đại diện',
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                onPressed: _pickAvatar,
                                icon: const Icon(Icons.photo_camera_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ảnh đại diện tối đa 2MB (JPEG, PNG, WEBP, GIF)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('profile-edit-fullname'),
                  controller: _fullname,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('profile-edit-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('profile-edit-bio'),
                  controller: _bio,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Giới thiệu bản thân',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                    counterText: '',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  key: const Key('profile-edit-submit'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu hồ sơ'),
                ),
              ],
            ),
    );
  }
}
