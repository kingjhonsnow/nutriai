import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_ai/core/utils/calculations.dart';

void main() {
  group('NutriAI Scientific Nutrition Calculations', () {
    test('Calculates BMI accurately', () {
      final bmi = NutritionCalculator.calculateBMI(75, 175);
      expect(bmi, closeTo(24.49, 0.05));
      expect(NutritionCalculator.getBMICategory(bmi), 'Normal Weight');
    });

    test('Calculates BMR with Mifflin-St Jeor formula for Men', () {
      // Men: 10 * 80 + 6.25 * 180 - 5 * 25 + 5 = 800 + 1125 - 125 + 5 = 1805
      final bmr = NutritionCalculator.calculateBMR(
        weightKg: 80,
        heightCm: 180,
        age: 25,
        gender: Gender.male,
      );
      expect(bmr, 1805.0);
    });

    test('Calculates BMR with Mifflin-St Jeor formula for Women', () {
      // Women: 10 * 60 + 6.25 * 165 - 5 * 28 - 161 = 600 + 1031.25 - 140 - 161 = 1330.25
      final bmr = NutritionCalculator.calculateBMR(
        weightKg: 60,
        heightCm: 165,
        age: 28,
        gender: Gender.female,
      );
      expect(bmr, 1330.25);
    });

    test('Calculates TDEE with Moderate Activity multiplier', () {
      final tdee = NutritionCalculator.calculateTDEE(
        bmr: 1800,
        activityLevel: ActivityLevel.moderatelyActive,
      );
      expect(tdee, 1800 * 1.55);
    });

    test('Calculates Bulking surplus target calories', () {
      final target = NutritionCalculator.calculateTargetCalories(
        tdee: 2500,
        goal: FitnessGoalType.muscleGain,
      );
      expect(target, 3000); // 2500 + 500
    });

    test('Calculates Cutting deficit target calories', () {
      final target = NutritionCalculator.calculateTargetCalories(
        tdee: 2500,
        goal: FitnessGoalType.fatLoss,
      );
      expect(target, 2000); // 2500 - 500
    });

    test('Calculates Macronutrient distribution', () {
      final macros = NutritionCalculator.calculateMacros(
        targetCalories: 2500,
        weightKg: 75,
        goal: FitnessGoalType.muscleGain,
      );
      expect(macros.proteinGrams, greaterThanOrEqualTo(150));
      expect(macros.carbsGrams, greaterThan(100));
      expect(macros.fatGrams, greaterThan(40));
    });
  });
}
