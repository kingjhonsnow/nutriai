import 'package:nutri_ai/core/utils/calculations.dart';

class FitnessGoal {
  final String id;
  final String userId;
  final FitnessGoalType type;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;
  final double weeklyWeightChangeKg;
  final DateTime updatedAt;

  const FitnessGoal({
    required this.id,
    required this.userId,
    required this.type,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.weeklyWeightChangeKg,
    required this.updatedAt,
  });

  factory FitnessGoal.fromProfile({
    required String id,
    required String userId,
    required FitnessGoalType type,
    required double tdee,
    required double weightKg,
  }) {
    final calories = NutritionCalculator.calculateTargetCalories(tdee: tdee, goal: type);
    final macros = NutritionCalculator.calculateMacros(
      targetCalories: calories,
      weightKg: weightKg,
      goal: type,
    );
    final weeklyRate = NutritionCalculator.getRecommendedWeeklyRate(type);

    return FitnessGoal(
      id: id,
      userId: userId,
      type: type,
      targetCalories: calories,
      targetProtein: macros.proteinGrams,
      targetCarbs: macros.carbsGrams,
      targetFat: macros.fatGrams,
      weeklyWeightChangeKg: weeklyRate,
      updatedAt: DateTime.now(),
    );
  }

  String get displayName {
    switch (type) {
      case FitnessGoalType.muscleGain:
        return 'Muscle Gain / Bulking';
      case FitnessGoalType.fatLoss:
        return 'Fat Loss / Cutting';
      case FitnessGoalType.maintenance:
        return 'Maintenance';
    }
  }

  String get description {
    switch (type) {
      case FitnessGoalType.muscleGain:
        return 'Calorie surplus designed to maximize hypertrophy and lean muscle mass.';
      case FitnessGoalType.fatLoss:
        return 'Calorie deficit prioritized for fat reduction while preserving lean muscle.';
      case FitnessGoalType.maintenance:
        return 'Balanced intake to stabilize weight and improve physical composition.';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'weeklyWeightChangeKg': weeklyWeightChangeKg,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FitnessGoal.fromMap(Map<String, dynamic> map) {
    return FitnessGoal(
      id: map['id'] as String? ?? 'goal_1',
      userId: map['userId'] as String? ?? 'user_1',
      type: FitnessGoalType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => FitnessGoalType.maintenance,
      ),
      targetCalories: map['targetCalories'] as int? ?? 2200,
      targetProtein: map['targetProtein'] as int? ?? 150,
      targetCarbs: map['targetCarbs'] as int? ?? 220,
      targetFat: map['targetFat'] as int? ?? 65,
      weeklyWeightChangeKg: (map['weeklyWeightChangeKg'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
