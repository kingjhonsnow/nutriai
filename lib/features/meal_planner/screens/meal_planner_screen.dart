import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/loading_indicator.dart';
import 'package:nutri_ai/data/models/meal_plan.dart';
import 'package:nutri_ai/features/meal_planner/providers/meal_planner_provider.dart';

class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(mealPlannerProvider);
    final plan = plannerState.currentPlan;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Smart Meal Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew_rounded),
            tooltip: 'Regenerate Plan',
            onPressed: () {
              ref.read(mealPlannerProvider.notifier).generatePlanForGoal();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: plannerState.isGenerating
            ? const Center(
                child: LoadingIndicator(
                  message: 'Optimizing meal combinations for your goal...',
                ),
              )
            : plan == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant_menu_rounded,
                            size: 56, color: AppColors.textDisabled),
                        const SizedBox(height: 16),
                        const Text('No meal plan generated yet'),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Generate Meal Plan',
                          width: 200,
                          onPressed: () {
                            ref.read(mealPlannerProvider.notifier).generatePlanForGoal();
                          },
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan Summary Card
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    plan.name,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Target: ${plan.targetCalories} kcal',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryItem('Total Cals', '${plan.totalCalories.round()} kcal'),
                                  _buildSummaryItem('Protein', '${plan.totalProtein.round()}g'),
                                  _buildSummaryItem('Carbs', '${plan.totalCarbs.round()}g'),
                                  _buildSummaryItem('Fat', '${plan.totalFat.round()}g'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Personalized Daily Meals',
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Planned Meals List
                        ...plan.meals.map((meal) {
                          return _buildPlannedMealCard(context, ref, meal);
                        }),
                        const SizedBox(height: 20),

                        // Regenerate Button
                        CustomButton(
                          text: 'Generate New Meal Variations',
                          icon: Icons.shuffle_rounded,
                          isOutlined: true,
                          onPressed: () {
                            ref.read(mealPlannerProvider.notifier).generatePlanForGoal();
                          },
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPlannedMealCard(
    BuildContext context,
    WidgetRef ref,
    PlannedMeal meal,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    meal.type.name.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(mealPlannerProvider.notifier).swapMeal(meal.type);
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.accent),
                label: Text(
                  'Swap Meal',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            meal.title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          // Food items list in meal
          ...meal.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.foodName} (${item.weightGrams.round()}g)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.instructions != null)
                          Text(
                            item.instructions!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.calories.round()} kcal',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meal Totals',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
              ),
              Text(
                '${meal.totalCalories.round()} kcal  •  P: ${meal.totalProtein.round()}g  C: ${meal.totalCarbs.round()}g  F: ${meal.totalFat.round()}g',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
