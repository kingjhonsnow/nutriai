import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/utils/validators.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/custom_text_field.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Password reset in two steps: request a code by email, then enter the code
/// and a new password. If email is not set up, the admin can set a temporary
/// password from the Admin screen instead.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeSent = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _show(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _sendCode() async {
    if (Validators.email(_emailController.text) != null) {
      _show('Enter a valid email address.', error: true);
      return;
    }
    final ok = await ref.read(authProvider.notifier).sendPasswordResetCode(_emailController.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _codeSent = true);
      _show('If an account exists for this email, a reset email was sent.');
    } else {
      _show(ref.read(authProvider).errorMessage ?? 'Could not send the email.', error: true);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).resetPasswordWithCode(
          _emailController.text.trim(),
          _codeController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      _show('Password changed. You are signed in.');
    } else {
      _show(ref.read(authProvider).errorMessage ?? 'The password could not be changed.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Reset password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _codeSent ? 'Check your email' : 'Forgot your password?',
                  style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Enter the code from the email and choose a new password. '
                          'If the email contains a link instead, simply tap the link.'
                      : 'Enter your email and we will send you a reset code.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: Validators.email,
                  readOnly: _codeSent,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _codeController,
                    label: 'Code from the email',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.pin_outlined,
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Enter the code from the email' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'New password',
                    obscureText: _obscure,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: Validators.password,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Change password',
                    isLoading: authState.isLoading,
                    onPressed: _resetPassword,
                  ),
                  TextButton(
                    onPressed: authState.isLoading ? null : _sendCode,
                    child: const Text('Send the email again'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  CustomButton(text: 'Send reset email', isLoading: authState.isLoading, onPressed: _sendCode),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    'No email arriving? Ask the admin of the app to set a temporary password for you.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
