import 'package:nutri_ai/data/models/meal.dart';

class DailyLog {
  final String id;
  final String date; // 'yyyy-MM-dd'
  final List<Meal> meals;
  final int waterIntakeMl;
  final int targetWaterMl;

  const DailyLog({
    required this.id,
    required this.date,
    required this.meals,
    this.waterIntakeMl = 0,
    this.targetWaterMl = 2500,
  });

  double get totalCalories => meals.fold(0.0, (sum, m) => sum + m.totalCalories);
  double get totalProtein => meals.fold(0.0, (sum, m) => sum + m.totalProtein);
  double get totalCarbs => meals.fold(0.0, (sum, m) => sum + m.totalCarbs);
  double get totalFat => meals.fold(0.0, (sum, m) => sum + m.totalFat);
  double get totalFiber => meals.fold(0.0, (sum, m) => sum + m.totalFiber);
  double get totalSugar => meals.fold(0.0, (sum, m) => sum + m.totalSugar);

  int get totalMealsCount => meals.where((m) => m.items.isNotEmpty).length;

  Meal? getMeal(MealType type) {
    try {
      return meals.firstWhere((m) => m.type == type);
    } catch (_) {
      return null;
    }
  }

  DailyLog copyWith({
    String? id,
    String? date,
    List<Meal>? meals,
    int? waterIntakeMl,
    int? targetWaterMl,
  }) {
    return DailyLog(
      id: id ?? this.id,
      date: date ?? this.date,
      meals: meals ?? this.meals,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'meals': meals.map((m) => m.toMap()).toList(),
      'waterIntakeMl': waterIntakeMl,
      'targetWaterMl': targetWaterMl,
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] as String? ?? '',
      date: map['date'] as String? ?? '',
      meals: (map['meals'] as List<dynamic>?)
              ?.map((m) => Meal.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      waterIntakeMl: map['waterIntakeMl'] as int? ?? 0,
      targetWaterMl: map['targetWaterMl'] as int? ?? 2500,
    );
  }

  factory DailyLog.empty(String dateStr) {
    return DailyLog(
      id: 'log_$dateStr',
      date: dateStr,
      meals: [
        Meal(
          id: 'breakfast_$dateStr',
          name: 'Breakfast',
          type: MealType.breakfast,
          items: [],
          loggedAt: DateTime.now(),
        ),
        Meal(
          id: 'lunch_$dateStr',
          name: 'Lunch',
          type: MealType.lunch,
          items: [],
          loggedAt: DateTime.now(),
        ),
        Meal(
          id: 'dinner_$dateStr',
          name: 'Dinner',
          type: MealType.dinner,
          items: [],
          loggedAt: DateTime.now(),
        ),
        Meal(
          id: 'snack_$dateStr',
          name: 'Snacks',
          type: MealType.snack,
          items: [],
          loggedAt: DateTime.now(),
        ),
      ],
      waterIntakeMl: 0,
      targetWaterMl: 2500,
    );
  }
}
