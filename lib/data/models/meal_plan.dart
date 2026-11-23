import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/data/models/meal.dart';

class PlannedMealItem {
  final String foodName;
  final double weightGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? instructions;

  const PlannedMealItem({
    required this.foodName,
    required this.weightGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.instructions,
  });

  Map<String, dynamic> toMap() {
    return {
      'foodName': foodName,
      'weightGrams': weightGrams,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'instructions': instructions,
    };
  }

  factory PlannedMealItem.fromMap(Map<String, dynamic> map) {
    return PlannedMealItem(
      foodName: map['foodName'] as String? ?? '',
      weightGrams: (map['weightGrams'] as num?)?.toDouble() ?? 100.0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      instructions: map['instructions'] as String?,
    );
  }
}

class PlannedMeal {
  final String id;
  final String title;
  final MealType type;
  final List<PlannedMealItem> items;
  final String preparationNotes;

  const PlannedMeal({
    required this.id,
    required this.title,
    required this.type,
    required this.items,
    this.preparationNotes = '',
  });

  double get totalCalories => items.fold(0.0, (sum, i) => sum + i.calories);
  double get totalProtein => items.fold(0.0, (sum, i) => sum + i.protein);
  double get totalCarbs => items.fold(0.0, (sum, i) => sum + i.carbs);
  double get totalFat => items.fold(0.0, (sum, i) => sum + i.fat);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'items': items.map((i) => i.toMap()).toList(),
      'preparationNotes': preparationNotes,
    };
  }

  factory PlannedMeal.fromMap(Map<String, dynamic> map) {
    return PlannedMeal(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      type: MealType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MealType.lunch,
      ),
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => PlannedMealItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      preparationNotes: map['preparationNotes'] as String? ?? '',
    );
  }
}

class MealPlan {
  final String id;
  final String name;
  final FitnessGoalType goal;
  final int targetCalories;
  final List<PlannedMeal> meals;
  final String dayOfWeek;

  const MealPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.targetCalories,
    required this.meals,
    this.dayOfWeek = 'Monday',
  });

  double get totalCalories => meals.fold(0.0, (sum, m) => sum + m.totalCalories);
  double get totalProtein => meals.fold(0.0, (sum, m) => sum + m.totalProtein);
  double get totalCarbs => meals.fold(0.0, (sum, m) => sum + m.totalCarbs);
  double get totalFat => meals.fold(0.0, (sum, m) => sum + m.totalFat);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'goal': goal.name,
      'targetCalories': targetCalories,
      'meals': meals.map((m) => m.toMap()).toList(),
      'dayOfWeek': dayOfWeek,
    };
  }

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    return MealPlan(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Personalized Plan',
      goal: FitnessGoalType.values.firstWhere(
        (g) => g.name == map['goal'],
        orElse: () => FitnessGoalType.maintenance,
      ),
      targetCalories: map['targetCalories'] as int? ?? 2200,
      meals: (map['meals'] as List<dynamic>?)
              ?.map((m) => PlannedMeal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      dayOfWeek: map['dayOfWeek'] as String? ?? 'Monday',
    );
  }
}
