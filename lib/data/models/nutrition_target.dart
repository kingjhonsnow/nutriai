class NutritionTarget {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int waterMl;

  const NutritionTarget({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.waterMl = 2500,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'waterMl': waterMl,
    };
  }

  factory NutritionTarget.fromMap(Map<String, dynamic> map) {
    return NutritionTarget(
      calories: map['calories'] as int? ?? 2200,
      proteinGrams: map['proteinGrams'] as int? ?? 150,
      carbsGrams: map['carbsGrams'] as int? ?? 220,
      fatGrams: map['fatGrams'] as int? ?? 65,
      waterMl: map['waterMl'] as int? ?? 2500,
    );
  }
}
