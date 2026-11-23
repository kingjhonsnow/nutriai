import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/core/services/app_exception.dart';

class GoalSelectionScreen extends ConsumerStatefulWidget {
  const GoalSelectionScreen({super.key});

  @override
  ConsumerState<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends ConsumerState<GoalSelectionScreen> {
  FitnessGoalType _selectedGoal = FitnessGoalType.muscleGain;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(goalProvider);
    if (current != null) {
      _selectedGoal = current.type;
    }
  }

  Future<void> _confirmGoal() async {
    setState(() => _saving = true);
    try {
      await ref.read(goalProvider.notifier).selectGoal(_selectedGoal);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      context.go('/nutrition-plan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final tdee = profile?.tdee ?? 2500.0;
    final weight = profile?.weightKg ?? 75.0;

    final targetCalories = NutritionCalculator.calculateTargetCalories(
      tdee: tdee,
      goal: _selectedGoal,
    );
    final macros = NutritionCalculator.calculateMacros(
      targetCalories: targetCalories,
      weightKg: weight,
      goal: _selectedGoal,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Fitness Objective'),
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
                    Text(
                      'Choose Your Fitness Goal',
                      style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your daily calorie and macronutrient targets will adapt to this goal.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    _buildGoalOptionCard(
                      type: FitnessGoalType.muscleGain,
                      title: 'Muscle Gain / Bulking',
                      badge: '+500 kcal Surplus',
                      rate: '+0.25 to 0.5 kg / week',
                      description:
                          'Calorie surplus designed to optimize hypertrophy while keeping fat accumulation controlled.',
                      icon: Icons.fitness_center_rounded,
                      accentColor: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    _buildGoalOptionCard(
                      type: FitnessGoalType.fatLoss,
                      title: 'Fat Loss / Cutting',
                      badge: '-500 kcal Deficit',
                      rate: '-0.5 to 1.0 kg / week',
                      description:
                          'Caloric deficit prioritizing high protein to spare and protect lean muscle tissue.',
                      icon: Icons.local_fire_department_rounded,
                      accentColor: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    _buildGoalOptionCard(
                      type: FitnessGoalType.maintenance,
                      title: 'Maintenance',
                      badge: 'Balanced Intake',
                      rate: 'Stable Weight',
                      description:
                          'Maintain current bodyweight while improving strength, performance, and nutrient quality.',
                      icon: Icons.balance_rounded,
                      accentColor: AppColors.accent,
                    ),
                    const SizedBox(height: 28),
                    // Live Computed Preview
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recommended Daily Target',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '$targetCalories kcal',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMacroCol('Protein', '${macros.proteinGrams}g', AppColors.protein),
                              _buildMacroCol('Carbs', '${macros.carbsGrams}g', AppColors.carbs),
                              _buildMacroCol('Fats', '${macros.fatGrams}g', AppColors.fat),
                            ],
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
                text: 'View Personalized Nutrition Plan',
                isLoading: _saving,
                onPressed: _confirmGoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalOptionCard({
    required FitnessGoalType type,
    required String title,
    required String badge,
    required String rate,
    required String description,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _selectedGoal == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = type),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? accentColor : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rate,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                  color: isSelected ? accentColor : AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
