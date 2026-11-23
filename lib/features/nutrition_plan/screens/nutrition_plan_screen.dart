import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/macro_progress_bar.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';

class NutritionPlanScreen extends ConsumerWidget {
  const NutritionPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final goal = ref.watch(goalProvider);

    final targetCalories = goal?.targetCalories ?? 2500;
    final protein = (goal?.targetProtein ?? 160).toDouble();
    final carbs = (goal?.targetCarbs ?? 240).toDouble();
    final fat = (goal?.targetFat ?? 70).toDouble();
    final weight = profile?.weightKg ?? 75.0;
    final waterMl = NutritionCalculator.calculateWaterIntakeMl(weight);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Your Nutrition Program'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goal Title Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal?.displayName ?? 'Muscle Gain / Bulking',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$targetCalories kcal daily target',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Daily Macronutrient Target',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          MacroLinearProgressBar(
                            label: 'Protein (4 kcal/g)',
                            consumed: protein,
                            target: protein,
                            color: AppColors.protein,
                          ),
                          const SizedBox(height: 14),
                          MacroLinearProgressBar(
                            label: 'Carbohydrates (4 kcal/g)',
                            consumed: carbs,
                            target: carbs,
                            color: AppColors.carbs,
                          ),
                          const SizedBox(height: 14),
                          MacroLinearProgressBar(
                            label: 'Healthy Fats (9 kcal/g)',
                            consumed: fat,
                            target: fat,
                            color: AppColors.fat,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Recommended Meal Distribution',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMealSplitCard(
                      name: 'Breakfast',
                      percent: '25%',
                      cals: (targetCalories * 0.25).round(),
                      icon: Icons.wb_twilight_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildMealSplitCard(
                      name: 'Lunch',
                      percent: '35%',
                      cals: (targetCalories * 0.35).round(),
                      icon: Icons.wb_sunny_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildMealSplitCard(
                      name: 'Dinner',
                      percent: '25%',
                      cals: (targetCalories * 0.25).round(),
                      icon: Icons.nightlight_round,
                    ),
                    const SizedBox(height: 10),
                    _buildMealSplitCard(
                      name: 'Snacks / Post-Workout',
                      percent: '15%',
                      cals: (targetCalories * 0.15).round(),
                      icon: Icons.apple_rounded,
                    ),
                    const SizedBox(height: 24),
                    // Water Intake Recommendation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.water.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.water_drop_rounded,
                              color: AppColors.water,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Hydration Target',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$waterMl ml (${(waterMl / 250).round()} glasses) recommended for your body mass',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: CustomButton(
                text: 'Go to Main Dashboard',
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSplitCard({
    required String name,
    required String percent,
    required int cals,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                name,
                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '$cals kcal',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  percent,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
