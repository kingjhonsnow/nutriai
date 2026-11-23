import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account, your diary, your progress and your profile photo. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref.read(authProvider.notifier).deleteAccount();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final goal = ref.watch(goalProvider);
    final auth = ref.watch(authProvider);

    final userName = profile?.name ?? auth.userName ?? '';
    final userEmail = auth.userEmail ?? profile?.email ?? '';
    final avatarUrl = auth.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                            Text(userEmail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (profile != null) ...[
                Text('Body Stats', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Body Mass Index (BMI)',
                          '${profile.bmi.toStringAsFixed(1)} (${NutritionCalculator.getBMICategory(profile.bmi)})'),
                      const Divider(height: 1),
                      _buildStatRow('Basal Metabolic Rate (BMR)', '${profile.bmr.round()} kcal'),
                      const Divider(height: 1),
                      _buildStatRow('Total Energy Expenditure (TDEE)', '${profile.tdee.round()} kcal'),
                      const Divider(height: 1),
                      _buildStatRow('Weight / Height',
                          '${profile.weightKg.toStringAsFixed(1)} kg / ${profile.heightCm.round()} cm'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text('Fitness Objective', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal?.displayName ?? 'No goal yet',
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          if (goal != null)
                            Text('${goal.targetCalories} kcal daily budget',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/goal-selection'),
                      child: const Text('Change Goal'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Account', style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    if (auth.isAdmin) ...[
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accent),
                        title: const Text('Admin: manage access'),
                        subtitle: const Text('Approve, block, reset passwords'),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                        onTap: () => context.push('/admin'),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: AppColors.warning),
                      title: const Text('Sign Out'),
                      onTap: () => ref.read(authProvider.notifier).logout(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                      title: const Text('Delete my account', style: TextStyle(color: AppColors.error)),
                      subtitle: const Text('Removes all your data permanently'),
                      onTap: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'NutriAI 1.1.0 · Units: metric (kg, cm, ml)',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
