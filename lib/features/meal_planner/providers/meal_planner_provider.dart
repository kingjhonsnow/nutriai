import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/data/models/meal_plan.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';

class MealPlannerState {
  final MealPlan? currentPlan;
  final bool isGenerating;
  final String? errorMessage;

  const MealPlannerState({
    this.currentPlan,
    this.isGenerating = false,
    this.errorMessage,
  });

  MealPlannerState copyWith({
    MealPlan? currentPlan,
    bool? isGenerating,
    String? errorMessage,
  }) {
    return MealPlannerState(
      currentPlan: currentPlan ?? this.currentPlan,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
    );
  }
}

class MealPlannerNotifier extends StateNotifier<MealPlannerState> {
  final Ref _ref;

  MealPlannerNotifier(this._ref) : super(const MealPlannerState()) {
    if (_ref.read(authProvider).isApproved) _loadInitialPlan();
  }

  Future<void> _loadInitialPlan() async {
    state = state.copyWith(isGenerating: true);
    try {
      final saved = await _ref.read(databaseServiceProvider).getCurrentMealPlan();
      if (!mounted) return;
      if (saved != null) {
        state = state.copyWith(currentPlan: saved, isGenerating: false);
        return;
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isGenerating: false, errorMessage: friendlyError(e));
      return;
    }
    await generatePlanForGoal();
  }

  Future<void> _save(MealPlan plan) async {
    try {
      await _ref.read(databaseServiceProvider).saveMealPlan(plan);
      if (mounted) state = state.copyWith(currentPlan: plan, isGenerating: false);
    } catch (e) {
      // Still show the plan; it just was not saved to the cloud.
      if (mounted) {
        state = state.copyWith(currentPlan: plan, isGenerating: false, errorMessage: friendlyError(e));
      }
    }
  }

  /// Builds a plan from curated meal templates scaled to the calorie target.
  Future<void> generatePlanForGoal() async {
    state = state.copyWith(isGenerating: true);

    final goal = _ref.read(goalProvider);
    final targetCalories = goal?.targetCalories ?? 2000;
    final goalType = goal?.type ?? FitnessGoalType.maintenance;

    final plan = _createCuratedPlan(targetCalories, goalType);
    await _save(plan);
  }

  Future<void> swapMeal(MealType type) async {
    if (state.currentPlan == null) return;
    state = state.copyWith(isGenerating: true);

    final currentPlan = state.currentPlan!;
    final alternativeMeal = _getAlternativeMeal(type, currentPlan.goal);

    final updatedMeals = currentPlan.meals.map((m) {
      if (m.type == type) {
        return alternativeMeal;
      }
      return m;
    }).toList();

    final newPlan = MealPlan(
      id: currentPlan.id,
      name: currentPlan.name,
      goal: currentPlan.goal,
      targetCalories: currentPlan.targetCalories,
      meals: updatedMeals,
      dayOfWeek: currentPlan.dayOfWeek,
    );

    await _save(newPlan);
  }

  MealPlan _createCuratedPlan(int targetCalories, FitnessGoalType goal) {
    return MealPlan(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Custom ${goal.name.toUpperCase()} Plan',
      goal: goal,
      targetCalories: targetCalories,
      meals: [
        // Breakfast
        PlannedMeal(
          id: 'meal_breakfast',
          title: 'Power Oatmeal & Eggs',
          type: MealType.breakfast,
          items: const [
            PlannedMealItem(
              foodName: 'Rolled Oats with Berries',
              weightGrams: 80,
              calories: 310,
              protein: 13.5,
              carbs: 53.0,
              fat: 5.5,
              instructions: 'Cook oats with hot water or milk, top with berries.',
            ),
            PlannedMealItem(
              foodName: 'Boiled Whole Eggs',
              weightGrams: 100, // 2 eggs
              calories: 143,
              protein: 12.6,
              carbs: 0.7,
              fat: 9.5,
              instructions: 'Boil for 7 minutes for a medium-soft yolk.',
            ),
          ],
          preparationNotes: 'High-fiber, sustained energy breakfast to kickstart metabolic rate.',
        ),
        // Lunch
        PlannedMeal(
          id: 'meal_lunch',
          title: 'Tunisian Grilled Chicken Couscous',
          type: MealType.lunch,
          items: const [
            PlannedMealItem(
              foodName: 'Tunisian Couscous with Veggies',
              weightGrams: 250,
              calories: 437,
              protein: 21.2,
              carbs: 55.0,
              fat: 15.5,
              instructions: 'Steamed semolina served with pumpkin, carrots and zucchini.',
            ),
            PlannedMealItem(
              foodName: 'Chicken Breast Fillet',
              weightGrams: 150,
              calories: 247,
              protein: 46.5,
              carbs: 0.0,
              fat: 5.4,
              instructions: 'Seasoned with tabil, paprika and grilled in olive oil.',
            ),
          ],
          preparationNotes: 'Rich complex carbohydrates and lean protein for muscular recovery.',
        ),
        // Dinner
        PlannedMeal(
          id: 'meal_dinner',
          title: 'Pan-Seared Salmon & Sweet Potatoes',
          type: MealType.dinner,
          items: const [
            PlannedMealItem(
              foodName: 'Salmon Fillet',
              weightGrams: 180,
              calories: 374,
              protein: 36.7,
              carbs: 0.0,
              fat: 24.1,
              instructions: 'Sear skin-down for 5 minutes, flip for 3 minutes.',
            ),
            PlannedMealItem(
              foodName: 'Baked Sweet Potato',
              weightGrams: 200,
              calories: 180,
              protein: 4.0,
              carbs: 41.4,
              fat: 0.2,
              instructions: 'Pierce with fork and roast at 200°C for 35 minutes.',
            ),
            PlannedMealItem(
              foodName: 'Steamed Broccoli',
              weightGrams: 150,
              calories: 51,
              protein: 4.2,
              carbs: 9.9,
              fat: 0.6,
              instructions: 'Steam until vibrant green (4-5 mins).',
            ),
          ],
          preparationNotes: 'High in Omega-3 fatty acids and micronutrients to aid nighttime recovery.',
        ),
        // Snacks
        PlannedMeal(
          id: 'meal_snack',
          title: 'Greek Yogurt & Almond Snack',
          type: MealType.snack,
          items: const [
            PlannedMealItem(
              foodName: 'Greek Yogurt 0%',
              weightGrams: 200,
              calories: 118,
              protein: 20.6,
              carbs: 7.2,
              fat: 0.8,
              instructions: 'Mix with honey or cinnamon if desired.',
            ),
            PlannedMealItem(
              foodName: 'Raw Almonds',
              weightGrams: 30,
              calories: 174,
              protein: 6.4,
              carbs: 6.5,
              fat: 15.0,
              instructions: 'Healthy fats and magnesium.',
            ),
          ],
          preparationNotes: 'Slow-digesting casein protein to support amino acid availability.',
        ),
      ],
    );
  }

  PlannedMeal _getAlternativeMeal(MealType type, FitnessGoalType goal) {
    switch (type) {
      case MealType.breakfast:
        return const PlannedMeal(
          id: 'alt_breakfast',
          title: 'High-Protein Omelet & Whole Wheat Toast',
          type: MealType.breakfast,
          items: [
            PlannedMealItem(
              foodName: 'Egg White & Whole Egg Omelet',
              weightGrams: 180,
              calories: 220,
              protein: 24.0,
              carbs: 2.0,
              fat: 12.0,
              instructions: 'Whisk with spinach and diced tomatoes.',
            ),
            PlannedMealItem(
              foodName: 'Whole Wheat Toast with Avocado',
              weightGrams: 80,
              calories: 230,
              protein: 7.0,
              carbs: 32.0,
              fat: 8.0,
              instructions: 'Toasted and spread with smashed avocado.',
            ),
          ],
          preparationNotes: 'Low GI carbohydrates with wholesome fats.',
        );
      case MealType.lunch:
        return const PlannedMeal(
          id: 'alt_lunch',
          title: 'Tunisian Ojja with Merguez & Salad',
          type: MealType.lunch,
          items: [
            PlannedMealItem(
              foodName: 'Ojja with Eggs & Peppers',
              weightGrams: 300,
              calories: 495,
              protein: 24.6,
              carbs: 16.5,
              fat: 37.5,
              instructions: 'Simmered in spicy tomato harissa sauce.',
            ),
            PlannedMealItem(
              foodName: 'Salade Mechouia',
              weightGrams: 150,
              calories: 128,
              protein: 3.8,
              carbs: 9.0,
              fat: 8.7,
              instructions: 'Charcoal grilled peppers seasoned with caraway.',
            ),
          ],
          preparationNotes: 'Traditional high-flavor satisfying lunch.',
        );
      case MealType.dinner:
        return const PlannedMeal(
          id: 'alt_dinner',
          title: 'Lean Beef Sirloin with Brown Rice',
          type: MealType.dinner,
          items: [
            PlannedMealItem(
              foodName: 'Grilled Beef Sirloin',
              weightGrams: 180,
              calories: 387,
              protein: 47.0,
              carbs: 0.0,
              fat: 20.7,
              instructions: 'Medium rare, seasoned with coarse sea salt.',
            ),
            PlannedMealItem(
              foodName: 'Steamed Brown Rice',
              weightGrams: 150,
              calories: 168,
              protein: 3.9,
              carbs: 35.3,
              fat: 1.4,
              instructions: 'Nutty complex carbs.',
            ),
          ],
          preparationNotes: 'Rich in dietary creatine, iron and zinc.',
        );
      case MealType.snack:
        return const PlannedMeal(
          id: 'alt_snack',
          title: 'Whey Protein Shake & Banana',
          type: MealType.snack,
          items: [
            PlannedMealItem(
              foodName: 'Whey Protein Shake',
              weightGrams: 35,
              calories: 133,
              protein: 27.3,
              carbs: 2.1,
              fat: 1.6,
              instructions: 'Shake with chilled water.',
            ),
            PlannedMealItem(
              foodName: 'Fresh Banana',
              weightGrams: 120,
              calories: 107,
              protein: 1.3,
              carbs: 27.4,
              fat: 0.4,
              instructions: 'Quick glycogen restoration.',
            ),
          ],
          preparationNotes: 'Rapid post-workout glycogen and protein absorption.',
        );
    }
  }
}

final mealPlannerProvider =
    StateNotifierProvider<MealPlannerNotifier, MealPlannerState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  return MealPlannerNotifier(ref);
});
