import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/custom_text_field.dart';
import 'package:nutri_ai/core/widgets/nutri_ai_logo.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Shown only when email confirmation is switched on in Supabase. The user
/// types the code from the email (a confirmation link also works).
class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, this.email = ''});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  late final TextEditingController _emailController = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _show(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  Future<void> _verify() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.length < 6) {
      _show('Enter your email and the code from the email.', error: true);
      return;
    }
    final ok = await ref.read(authProvider.notifier).verifySignupCode(email, code);
    if (!mounted || ok) return; // the router continues on success
    _show(ref.read(authProvider).errorMessage ?? 'The code could not be verified.', error: true);
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _show('Enter your email first.', error: true);
      return;
    }
    final ok = await ref.read(authProvider.notifier).resendSignupCode(email);
    if (!mounted) return;
    _show(ok ? 'A new code was sent to $email' : (ref.read(authProvider).errorMessage ?? 'Could not send a new code.'),
        error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: NutriAILogo(size: 72, showText: true, fontSize: 22)),
                const SizedBox(height: 32),
                Text(
                  'Confirm your email',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a code to your email. Type it below, or tap the link in the email.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _codeController,
                  label: 'Code from the email',
                  hint: '123456',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.pin_outlined,
                ),
                const SizedBox(height: 24),
                CustomButton(text: 'Confirm', isLoading: authState.isLoading, onPressed: _verify),
                const SizedBox(height: 12),
                TextButton(onPressed: authState.isLoading ? null : _resend, child: const Text('Send a new code')),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
