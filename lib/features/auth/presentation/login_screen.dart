import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../app/widgets/app_error_banner.dart';
import '../../../core/network/api_exception.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _remember = true;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            remember: _remember,
          );
      if (!mounted) return;
      context.go(widget.from ?? '/');
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(fallbackLocation: '/')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 64,
                    color: AppColors.oliveSoft,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Chào mừng trở lại!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Đăng nhập để lưu công thức và đánh giá món ăn.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    key: const Key('login-username'),
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Tài khoản',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập tài khoản.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('login-password'),
                    controller: _passwordController,
                    obscureText: !_obscurePassword,
                    onFieldSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Vui lòng nhập mật khẩu.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  CheckboxListTile(
                    value: _remember,
                    onChanged: (value) =>
                        setState(() => _remember = value ?? true),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Ghi nhớ đăng nhập 30 ngày'),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const Key('forgot-password'),
                      onPressed: _submitting
                          ? null
                          : () => context.push('/forgot-password'),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppErrorBanner(message: _errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    key: const Key('login-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => context.push('/register'),
                    child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
