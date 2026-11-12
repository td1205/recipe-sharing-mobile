import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/app_back_button.dart';
import '../../../app/widgets/app_error_banner.dart';
import '../../../core/network/api_exception.dart';
import 'auth_providers.dart';

enum PasswordResetStep { email, otp, password, complete }

class PasswordResetState {
  const PasswordResetState({
    this.step = PasswordResetStep.email,
    this.busy = false,
    this.error,
  });

  final PasswordResetStep step;
  final bool busy;
  final String? error;
}

class PasswordResetController extends Notifier<PasswordResetState> {
  String? _sessionCookie;

  @override
  PasswordResetState build() => const PasswordResetState();

  Future<void> requestOtp(String email) async {
    await _guard(() async {
      _sessionCookie = await ref
          .read(authRepositoryProvider)
          .requestPasswordResetOtp(email: email.trim());
      state = const PasswordResetState(step: PasswordResetStep.otp);
    });
  }

  Future<void> verifyOtp(String otp) async {
    final cookie = _sessionCookie;
    if (cookie == null || cookie.isEmpty) {
      state = const PasswordResetState(
        error: 'Phiên khôi phục đã hết hạn. Vui lòng yêu cầu mã mới.',
      );
      return;
    }
    await _guard(() async {
      _sessionCookie = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetOtp(otp: otp.trim(), sessionCookie: cookie);
      state = const PasswordResetState(step: PasswordResetStep.password);
    });
  }

  Future<void> changePassword(String password, String confirmation) async {
    final cookie = _sessionCookie;
    if (cookie == null || cookie.isEmpty) {
      state = const PasswordResetState(
        error: 'Phiên khôi phục đã hết hạn. Vui lòng yêu cầu mã mới.',
      );
      return;
    }
    await _guard(() async {
      await ref
          .read(authRepositoryProvider)
          .changeForgottenPassword(
            password: password,
            confirmPassword: confirmation,
            sessionCookie: cookie,
          );
      _sessionCookie = null;
      state = const PasswordResetState(step: PasswordResetStep.complete);
    });
  }

  void restart() {
    _sessionCookie = null;
    state = const PasswordResetState();
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (state.busy) return;
    final currentStep = state.step;
    state = PasswordResetState(step: currentStep, busy: true);
    try {
      await action();
    } on ApiException catch (error) {
      state = PasswordResetState(step: currentStep, error: error.message);
    } catch (_) {
      state = PasswordResetState(
        step: currentStep,
        error: 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
      );
    }
  }
}

final passwordResetProvider =
    NotifierProvider.autoDispose<PasswordResetController, PasswordResetState>(
      PasswordResetController.new,
    );

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/login'),
        title: const Text('Khôi phục mật khẩu'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_reset_rounded,
                    size: 64,
                    color: AppColors.oliveSoft,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _title(state.step),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _description(state.step),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ..._fields(state.step),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppErrorBanner(message: state.error!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (state.step != PasswordResetStep.complete)
                    FilledButton(
                      key: const Key('password-reset-submit'),
                      onPressed: state.busy ? null : () => _submit(state.step),
                      child: state.busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_action(state.step)),
                    )
                  else
                    FilledButton(
                      key: const Key('password-reset-login'),
                      onPressed: () => context.go('/login'),
                      child: const Text('Đăng nhập lại'),
                    ),
                  if (state.step == PasswordResetStep.otp)
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : () => ref
                                .read(passwordResetProvider.notifier)
                                .restart(),
                      child: const Text('Dùng email khác'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(PasswordResetStep step) => switch (step) {
    PasswordResetStep.email => [
      TextFormField(
        key: const Key('reset-email'),
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email đã đăng ký',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: (value) {
          final email = value?.trim() ?? '';
          return email.contains('@') ? null : 'Email không hợp lệ.';
        },
      ),
    ],
    PasswordResetStep.otp => [
      TextFormField(
        key: const Key('reset-otp'),
        controller: _otp,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(labelText: 'Mã OTP gồm 6 số'),
        validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
            ? null
            : 'Vui lòng nhập đúng 6 chữ số.',
      ),
    ],
    PasswordResetStep.password => [
      TextFormField(
        key: const Key('reset-password'),
        controller: _password,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Mật khẩu mới',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        validator: (value) =>
            (value?.length ?? 0) < 8 ? 'Mật khẩu cần ít nhất 8 ký tự.' : null,
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        key: const Key('reset-confirmation'),
        controller: _confirmation,
        obscureText: _obscure,
        decoration: const InputDecoration(
          labelText: 'Xác nhận mật khẩu',
          prefixIcon: Icon(Icons.verified_user_outlined),
        ),
        validator: (value) =>
            value != _password.text ? 'Mật khẩu xác nhận không khớp.' : null,
      ),
    ],
    PasswordResetStep.complete => [
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.limeSurface,
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_rounded, size: 48),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Mật khẩu đã được đổi. Các phiên cũ đã hết hiệu lực.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ],
  };

  Future<void> _submit(PasswordResetStep step) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(passwordResetProvider.notifier);
    switch (step) {
      case PasswordResetStep.email:
        await controller.requestOtp(_email.text);
        return;
      case PasswordResetStep.otp:
        await controller.verifyOtp(_otp.text);
        return;
      case PasswordResetStep.password:
        await controller.changePassword(_password.text, _confirmation.text);
        return;
      case PasswordResetStep.complete:
        break;
    }
  }

  String _title(PasswordResetStep step) => switch (step) {
    PasswordResetStep.email => 'Quên mật khẩu?',
    PasswordResetStep.otp => 'Nhập mã xác thực',
    PasswordResetStep.password => 'Tạo mật khẩu mới',
    PasswordResetStep.complete => 'Đổi mật khẩu thành công',
  };

  String _description(PasswordResetStep step) => switch (step) {
    PasswordResetStep.email =>
      'Nếu email tồn tại, hệ thống sẽ gửi mã OTP để xác thực.',
    PasswordResetStep.otp => 'Kiểm tra hộp thư và nhập mã OTP còn hiệu lực.',
    PasswordResetStep.password => 'Chọn mật khẩu mạnh và không dùng lại mã cũ.',
    PasswordResetStep.complete => 'Bạn có thể đăng nhập bằng mật khẩu mới.',
  };

  String _action(PasswordResetStep step) => switch (step) {
    PasswordResetStep.email => 'Gửi mã OTP',
    PasswordResetStep.otp => 'Xác thực OTP',
    PasswordResetStep.password => 'Đổi mật khẩu',
    PasswordResetStep.complete => 'Hoàn tất',
  };
}
