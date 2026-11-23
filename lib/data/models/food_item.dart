class FoodItem {
  final String id;
  final String name;
  final String category; // 'Fruits', 'Vegetables', 'Meat & Poultry', 'Fish & Seafood', 'Dairy', 'Grains & Pasta', 'Traditional', etc.
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double sugarPer100g;
  final double defaultServingGrams;
  final String? imageUrl;
  final bool isFavorite;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0.0,
    this.sugarPer100g = 0.0,
    this.defaultServingGrams = 100.0,
    this.imageUrl,
    this.isFavorite = false,
  });

  // Calculate nutrients for specific gram amount
  double getCaloriesFor(double grams) => (caloriesPer100g * grams) / 100.0;
  double getProteinFor(double grams) => (proteinPer100g * grams) / 100.0;
  double getCarbsFor(double grams) => (carbsPer100g * grams) / 100.0;
  double getFatFor(double grams) => (fatPer100g * grams) / 100.0;
  double getFiberFor(double grams) => (fiberPer100g * grams) / 100.0;
  double getSugarFor(double grams) => (sugarPer100g * grams) / 100.0;

  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    double? sugarPer100g,
    double? defaultServingGrams,
    String? imageUrl,
    bool? isFavorite,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fiberPer100g: fiberPer100g ?? this.fiberPer100g,
      sugarPer100g: sugarPer100g ?? this.sugarPer100g,
      defaultServingGrams: defaultServingGrams ?? this.defaultServingGrams,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'fiberPer100g': fiberPer100g,
      'sugarPer100g': sugarPer100g,
      'defaultServingGrams': defaultServingGrams,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Food Item',
      category: map['category'] as String? ?? 'General',
      caloriesPer100g: (map['caloriesPer100g'] as num?)?.toDouble() ?? 0.0,
      proteinPer100g: (map['proteinPer100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (map['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (map['fatPer100g'] as num?)?.toDouble() ?? 0.0,
      fiberPer100g: (map['fiberPer100g'] as num?)?.toDouble() ?? 0.0,
      sugarPer100g: (map['sugarPer100g'] as num?)?.toDouble() ?? 0.0,
      defaultServingGrams: (map['defaultServingGrams'] as num?)?.toDouble() ?? 100.0,
      imageUrl: map['imageUrl'] as String?,
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
    );
  }
}
