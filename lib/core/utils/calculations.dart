import 'package:nutri_ai/core/constants/app_constants.dart';

enum Gender { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extremelyActive,
}

enum FitnessGoalType {
  muscleGain,
  fatLoss,
  maintenance,
}

class MacroBreakdown {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  const MacroBreakdown({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'proteinPercent': proteinPercent,
      'carbsPercent': carbsPercent,
      'fatPercent': fatPercent,
    };
  }

  factory MacroBreakdown.fromMap(Map<String, dynamic> map) {
    return MacroBreakdown(
      calories: map['calories'] as int? ?? 2000,
      proteinGrams: map['proteinGrams'] as int? ?? 150,
      carbsGrams: map['carbsGrams'] as int? ?? 200,
      fatGrams: map['fatGrams'] as int? ?? 65,
      proteinPercent: (map['proteinPercent'] as num?)?.toDouble() ?? 0.3,
      carbsPercent: (map['carbsPercent'] as num?)?.toDouble() ?? 0.45,
      fatPercent: (map['fatPercent'] as num?)?.toDouble() ?? 0.25,
    );
  }
}

class NutritionCalculator {
  NutritionCalculator._();

  /// Calculate BMI (Body Mass Index)
  /// BMI = weight (kg) / (height (m) ^ 2)
  static double calculateBMI(double weightKg, double heightCm) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Get BMI Category and Description
  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal Weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  /// Calculate BMR using the Mifflin-St Jeor Formula
  /// Men: 10 * weight (kg) + 6.25 * height (cm) - 5 * age (y) + 5
  /// Women: 10 * weight (kg) + 6.25 * height (cm) - 5 * age (y) - 161
  static double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) return 0.0;
    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age);
    return gender == Gender.male ? base + 5 : base - 161;
  }

  /// Get activity multiplier based on activity level
  static double getActivityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return AppConstants.sedentaryMultiplier;
      case ActivityLevel.lightlyActive:
        return AppConstants.lightlyActiveMultiplier;
      case ActivityLevel.moderatelyActive:
        return AppConstants.moderatelyActiveMultiplier;
      case ActivityLevel.veryActive:
        return AppConstants.veryActiveMultiplier;
      case ActivityLevel.extremelyActive:
        return AppConstants.extraActiveMultiplier;
    }
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  static double calculateTDEE({
    required double bmr,
    required ActivityLevel activityLevel,
  }) {
    return bmr * getActivityMultiplier(activityLevel);
  }

  /// Calculate daily target calories based on goal
  static int calculateTargetCalories({
    required double tdee,
    required FitnessGoalType goal,
  }) {
    switch (goal) {
      case FitnessGoalType.muscleGain:
        return (tdee + AppConstants.bulkingSurplusCalories).round();
      case FitnessGoalType.fatLoss:
        final deficit = (tdee - AppConstants.cuttingDeficitCalories).round();
        // Never recommend less than 1200 kcal for safety
        return deficit < 1200 ? 1200 : deficit;
      case FitnessGoalType.maintenance:
        return tdee.round();
    }
  }

  /// Calculate recommended macronutrient distribution
  static MacroBreakdown calculateMacros({
    required int targetCalories,
    required double weightKg,
    required FitnessGoalType goal,
  }) {
    double proteinGrams;
    double fatGrams;
    double carbsGrams;

    switch (goal) {
      case FitnessGoalType.muscleGain:
        // High protein for muscle synthesis (2.0g per kg), 25% fats, remainder carbs
        proteinGrams = (weightKg * 2.0).clamp(100.0, 250.0);
        final proteinCals = proteinGrams * AppConstants.caloriesPerGramProtein;
        final fatCals = targetCalories * 0.25;
        fatGrams = fatCals / AppConstants.caloriesPerGramFat;
        final remainingCals = targetCalories - proteinCals - fatCals;
        carbsGrams = (remainingCals / AppConstants.caloriesPerGramCarbs).clamp(50.0, 600.0);
        break;

      case FitnessGoalType.fatLoss:
        // Higher protein to spare muscle tissue in deficit (2.2g per kg), 25% fats, rest carbs
        proteinGrams = (weightKg * 2.2).clamp(110.0, 260.0);
        final proteinCals = proteinGrams * AppConstants.caloriesPerGramProtein;
        final fatCals = targetCalories * 0.25;
        fatGrams = fatCals / AppConstants.caloriesPerGramFat;
        final remainingCals = targetCalories - proteinCals - fatCals;
        carbsGrams = (remainingCals / AppConstants.caloriesPerGramCarbs).clamp(30.0, 500.0);
        break;

      case FitnessGoalType.maintenance:
        // Balanced approach: 1.8g protein per kg, 30% fats, remainder carbs
        proteinGrams = (weightKg * 1.8).clamp(90.0, 220.0);
        final proteinCals = proteinGrams * AppConstants.caloriesPerGramProtein;
        final fatCals = targetCalories * 0.30;
        fatGrams = fatCals / AppConstants.caloriesPerGramFat;
        final remainingCals = targetCalories - proteinCals - fatCals;
        carbsGrams = (remainingCals / AppConstants.caloriesPerGramCarbs).clamp(50.0, 500.0);
        break;
    }

    final totalComputedCalories = (proteinGrams * AppConstants.caloriesPerGramProtein) +
        (carbsGrams * AppConstants.caloriesPerGramCarbs) +
        (fatGrams * AppConstants.caloriesPerGramFat);

    return MacroBreakdown(
      calories: targetCalories,
      proteinGrams: proteinGrams.round(),
      carbsGrams: carbsGrams.round(),
      fatGrams: fatGrams.round(),
      proteinPercent: (proteinGrams * AppConstants.caloriesPerGramProtein) / totalComputedCalories,
      carbsPercent: (carbsGrams * AppConstants.caloriesPerGramCarbs) / totalComputedCalories,
      fatPercent: (fatGrams * AppConstants.caloriesPerGramFat) / totalComputedCalories,
    );
  }

  /// Calculate recommended daily water intake (ml)
  static int calculateWaterIntakeMl(double weightKg) {
    if (weightKg <= 0) return 2500;
    return (weightKg * AppConstants.waterPerKgBodyWeight).round();
  }

  /// Recommended weekly weight change (kg/week)
  static double getRecommendedWeeklyRate(FitnessGoalType goal) {
    switch (goal) {
      case FitnessGoalType.muscleGain:
        return AppConstants.safeBulkingRate;
      case FitnessGoalType.fatLoss:
        return -AppConstants.safeCuttingRate;
      case FitnessGoalType.maintenance:
        return 0.0;
    }
  }
}
