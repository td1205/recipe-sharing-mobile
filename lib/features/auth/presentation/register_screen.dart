import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../app/widgets/app_error_banner.dart';
import '../../../core/network/api_exception.dart';
import 'auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _fullname;
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController();
    _email = TextEditingController();
    _fullname = TextEditingController();
    _password = TextEditingController();
    _confirm = TextEditingController();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _email,
      _fullname,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static bool _hasUpper(String value) => value.contains(RegExp(r'[A-Z]'));
  static bool _hasLower(String value) => value.contains(RegExp(r'[a-z]'));
  static bool _hasDigit(String value) => value.contains(RegExp(r'\d'));
  static bool _hasSpecial(String value) =>
      value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/]'));

  int get _policyScore {
    final password = _password.text;
    var score = 0;
    if (password.length >= 8) score++;
    if (_hasUpper(password)) score++;
    if (_hasLower(password)) score++;
    if (_hasDigit(password)) score++;
    if (_hasSpecial(password)) score++;
    return score;
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
          .register(
            username: _username.text.trim(),
            email: _email.text.trim(),
            fullname: _fullname.text.trim(),
            password: _password.text,
            confirmPassword: _confirm.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Hãy đăng nhập để tiếp tục.'),
          ),
        );
      context.go('/login');
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/login'),
        title: const Text('Tạo tài khoản'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _fullname,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập họ tên.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tài khoản',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.isEmpty) return 'Vui lòng nhập tài khoản.';
                  if (!RegExp(
                    r'^[\p{L}\p{N}_.-]+$',
                    unicode: true,
                  ).hasMatch(username)) {
                    return 'Tài khoản chỉ gồm chữ, số, dấu gạch và dấu chấm.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Vui lòng nhập email.';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Email không hợp lệ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return 'Vui lòng nhập mật khẩu.';
                  if (password.length < 8) {
                    return 'Mật khẩu tối thiểu 8 ký tự.';
                  }
                  if (!(_hasUpper(password) &&
                      _hasLower(password) &&
                      _hasDigit(password) &&
                      _hasSpecial(password))) {
                    return 'Mật khẩu cần chữ hoa, chữ thường, số và ký tự đặc biệt.';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: _PasswordStrengthMeter(score: _policyScore),
              ),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (value) => value != _password.text
                    ? 'Mật khẩu xác nhận không khớp.'
                    : null,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('register-submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Đăng ký'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    const labels = ['Yếu', 'Yếu', 'Trung bình', 'Khá', 'Mạnh', 'Rất mạnh'];
    const colors = [
      AppColors.background,
      Color(0xffd97470),
      Color(0xffe0a95f),
      Color(0xffdfc46b),
      Color(0xffa8c46b),
      AppColors.oliveSoft,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            5,
            (index) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                decoration: BoxDecoration(
                  color: index < score ? colors[score] : AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Độ mạnh: ${labels[score]}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
