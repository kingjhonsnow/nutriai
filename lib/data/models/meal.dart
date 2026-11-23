import 'package:nutri_ai/data/models/food_item.dart';

enum MealType { breakfast, lunch, dinner, snack }

class MealFoodEntry {
  final String id;
  final FoodItem food;
  final double weightGrams;

  const MealFoodEntry({
    required this.id,
    required this.food,
    required this.weightGrams,
  });

  double get calories => food.getCaloriesFor(weightGrams);
  double get protein => food.getProteinFor(weightGrams);
  double get carbs => food.getCarbsFor(weightGrams);
  double get fat => food.getFatFor(weightGrams);
  double get fiber => food.getFiberFor(weightGrams);
  double get sugar => food.getSugarFor(weightGrams);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'food': food.toMap(),
      'weightGrams': weightGrams,
    };
  }

  factory MealFoodEntry.fromMap(Map<String, dynamic> map) {
    return MealFoodEntry(
      id: map['id'] as String? ?? '',
      food: FoodItem.fromMap(map['food'] as Map<String, dynamic>),
      weightGrams: (map['weightGrams'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

class Meal {
  final String id;
  final String name;
  final MealType type;
  final List<MealFoodEntry> items;
  final DateTime loggedAt;

  const Meal({
    required this.id,
    required this.name,
    required this.type,
    required this.items,
    required this.loggedAt,
  });

  double get totalCalories => items.fold(0.0, (sum, item) => sum + item.calories);
  double get totalProtein => items.fold(0.0, (sum, item) => sum + item.protein);
  double get totalCarbs => items.fold(0.0, (sum, item) => sum + item.carbs);
  double get totalFat => items.fold(0.0, (sum, item) => sum + item.fat);
  double get totalFiber => items.fold(0.0, (sum, item) => sum + item.fiber);
  double get totalSugar => items.fold(0.0, (sum, item) => sum + item.sugar);

  String get typeDisplayName {
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  Meal copyWith({
    String? id,
    String? name,
    MealType? type,
    List<MealFoodEntry>? items,
    DateTime? loggedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      items: items ?? this.items,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'items': items.map((i) => i.toMap()).toList(),
      'loggedAt': loggedAt.toIso8601String(),
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Meal',
      type: MealType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MealType.lunch,
      ),
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => MealFoodEntry.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      loggedAt: DateTime.tryParse(map['loggedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
