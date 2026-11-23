import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/nutri_ai_logo.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Shown to signed-in users who do not (or no longer) have access.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final account = auth.account;

    late final IconData icon;
    late final Color color;
    late final String title;
    late final String message;

    if (account == null) {
      icon = Icons.cloud_off_rounded;
      color = AppColors.warning;
      title = 'Could not load your account';
      message = auth.errorMessage ?? 'Check your internet connection and try again.';
    } else if (account.status == AccountStatus.approved && account.isExpired) {
      icon = Icons.event_busy_rounded;
      color = AppColors.warning;
      title = 'Your access has ended';
      message = 'Your access ended on ${DateFormat('d MMM yyyy').format(account.accessUntil!)}. '
          'Contact the person who gave you the app to renew it.';
    } else if (account.status == AccountStatus.rejected || account.status == AccountStatus.revoked) {
      icon = Icons.block_rounded;
      color = AppColors.error;
      title = 'No access';
      message = 'This account does not have access to the app. Contact the person who gave you the app.';
    } else {
      icon = Icons.hourglass_top_rounded;
      color = Colors.amber;
      title = 'Waiting for approval';
      message = 'Your account (${account.email}) was created. The admin has to approve it before you can '
          'use the app. Check again later.';
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: NutriAILogo(size: 72, showText: true, fontSize: 22)),
                const SizedBox(height: 36),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                      border: Border.all(color: color.withOpacity(0.4), width: 2),
                    ),
                    child: Icon(icon, size: 44, color: color),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Check again',
                  icon: Icons.refresh_rounded,
                  isLoading: auth.isLoading,
                  onPressed: () => ref.read(authProvider.notifier).refreshAccount(),
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Sign out',
                  icon: Icons.logout_rounded,
                  isOutlined: true,
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
