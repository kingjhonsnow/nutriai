import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/data/datasources/local/food_database.dart';
import 'package:nutri_ai/data/models/daily_log.dart';
import 'package:nutri_ai/data/models/food_item.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/data/models/meal_plan.dart';
import 'package:nutri_ai/data/models/progress_entry.dart';

/// One food to log (used for single adds and for whole scanned meals).
class FoodLogInput {
  final FoodItem food;
  final double grams;
  final String? source;

  const FoodLogInput(this.food, this.grams, {this.source});
}

/// Personal data of the signed-in user, stored in Supabase (one instance per
/// user; see `databaseServiceProvider`). The built-in food list stays in the
/// app because it is the same for everyone.
class DatabaseService {
  final SupabaseClient _client;
  final String? _userId;

  DatabaseService(this._client, this._userId);

  final List<FoodItem> _catalog = LocalFoodDatabase.getInitialFoods();
  Set<String> _favoriteKeys = <String>{};
  bool _favoritesLoaded = false;

  String get _uid {
    final id = _userId;
    if (id == null) throw const AppException('Please sign in again.');
    return id;
  }

  static double _d(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static double? _dn(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static double _r1(double v) => double.parse(v.toStringAsFixed(1));
  static double _r2(double v) => double.parse(v.toStringAsFixed(2));

  // ---------------------------------------------------------------------------
  // FOOD CATALOG (built in) + FAVOURITES (per user, in the cloud)
  // ---------------------------------------------------------------------------

  FoodItem _withFavorite(FoodItem f) => f.copyWith(isFavorite: _favoriteKeys.contains(f.id));

  List<FoodItem> getAllFoods() => _catalog.map(_withFavorite).toList();

  List<FoodItem> searchFoods(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return _catalog
        .where((food) {
          final matchesQuery = q.isEmpty ||
              food.name.toLowerCase().contains(q) ||
              food.category.toLowerCase().contains(q);
          final matchesCategory =
              category == null || category.isEmpty || category == 'All' || food.category == category;
          return matchesQuery && matchesCategory;
        })
        .map(_withFavorite)
        .toList();
  }

  FoodItem? getFoodById(String id) {
    for (final f in _catalog) {
      if (f.id == id) return _withFavorite(f);
    }
    return null;
  }

  List<FoodItem> getFavoriteFoods() =>
      _catalog.where((f) => _favoriteKeys.contains(f.id)).map(_withFavorite).toList();

  Future<void> loadFavorites({bool force = false}) async {
    if (_favoritesLoaded && !force) return;
    final rows = await _client.from('user_favorite_foods').select('food_key').eq('user_id', _uid);
    _favoriteKeys = rows.map((r) => r['food_key'] as String).toSet();
    _favoritesLoaded = true;
  }

  Future<void> toggleFavoriteFood(String foodId) async {
    if (_favoriteKeys.contains(foodId)) {
      await _client.from('user_favorite_foods').delete().eq('user_id', _uid).eq('food_key', foodId);
      _favoriteKeys.remove(foodId);
    } else {
      await _client.from('user_favorite_foods').upsert(
        {'user_id': _uid, 'food_key': foodId},
        onConflict: 'user_id,food_key',
      );
      _favoriteKeys.add(foodId);
    }
  }

  // ---------------------------------------------------------------------------
  // FOOD DIARY (table food_logs, one row per food, keyed by local calendar day)
  // ---------------------------------------------------------------------------

  Future<DailyLog> getDailyLog(DateTime date) async {
    final dateStr = date.toDateString();
    final rows = await _client
        .from('food_logs')
        .select('id, meal_type, food_key, food_name, category, serving_amount_g, '
            'calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, '
            'fiber_per_100g, sugar_per_100g, logged_at')
        .eq('user_id', _uid)
        .eq('log_date', dateStr)
        .order('logged_at', ascending: true);
    final water = await _client
        .from('daily_water')
        .select('amount_ml')
        .eq('user_id', _uid)
        .eq('log_date', dateStr)
        .maybeSingle();

    final byType = <MealType, List<MealFoodEntry>>{};
    for (final r in rows) {
      final type = MealType.values.firstWhere(
        (t) => t.name == r['meal_type'],
        orElse: () => MealType.snack,
      );
      final food = FoodItem(
        id: (r['food_key'] as String?) ?? 'log_${r['id']}',
        name: (r['food_name'] as String?)?.isNotEmpty == true ? r['food_name'] as String : 'Food',
        category: (r['category'] as String?) ?? 'Logged',
        caloriesPer100g: _d(r['calories_per_100g']),
        proteinPer100g: _d(r['protein_per_100g']),
        carbsPer100g: _d(r['carbs_per_100g']),
        fatPer100g: _d(r['fat_per_100g']),
        fiberPer100g: _d(r['fiber_per_100g']),
        sugarPer100g: _d(r['sugar_per_100g']),
      );
      byType.putIfAbsent(type, () => []).add(
            MealFoodEntry(id: r['id'] as String, food: food, weightGrams: _d(r['serving_amount_g'])),
          );
    }

    final empty = DailyLog.empty(dateStr);
    return empty.copyWith(
      meals: empty.meals.map((m) => m.copyWith(items: byType[m.type] ?? const [])).toList(),
      waterIntakeMl: (water?['amount_ml'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _logRow(DateTime date, MealType mealType, FoodLogInput input, String loggedAt) {
    final f = input.food;
    final g = input.grams;
    return {
      'user_id': _uid,
      'meal_type': mealType.name,
      'food_key': f.id,
      'food_name': f.name,
      'category': f.category,
      'source': input.source,
      'log_date': date.toDateString(),
      'logged_at': loggedAt,
      'serving_amount_g': _r1(g),
      'calories': _r1(f.getCaloriesFor(g)),
      'protein': _r1(f.getProteinFor(g)),
      'carbs': _r1(f.getCarbsFor(g)),
      'fat': _r1(f.getFatFor(g)),
      'fiber': _r1(f.getFiberFor(g)),
      'sugar': _r1(f.getSugarFor(g)),
      'calories_per_100g': _r2(f.caloriesPer100g),
      'protein_per_100g': _r2(f.proteinPer100g),
      'carbs_per_100g': _r2(f.carbsPer100g),
      'fat_per_100g': _r2(f.fatPer100g),
      'fiber_per_100g': _r2(f.fiberPer100g),
      'sugar_per_100g': _r2(f.sugarPer100g),
    };
  }

  Future<void> addFoodToMeal({
    required DateTime date,
    required MealType mealType,
    required FoodItem food,
    required double weightGrams,
    String? source,
  }) {
    return addFoodsToMeal(
      date: date,
      mealType: mealType,
      items: [FoodLogInput(food, weightGrams, source: source)],
    );
  }

  /// Saves several foods in ONE database request, so a scanned meal is saved
  /// completely or not at all.
  Future<void> addFoodsToMeal({
    required DateTime date,
    required MealType mealType,
    required List<FoodLogInput> items,
  }) async {
    if (items.isEmpty) return;
    for (final i in items) {
      if (i.grams <= 0 || i.grams > 5000) {
        throw AppException('The portion of ${i.food.name} must be between 1 g and 5000 g.');
      }
    }
    final loggedAt = DateTime.now().toUtc().toIso8601String();
    await _client.from('food_logs').insert(items.map((i) => _logRow(date, mealType, i, loggedAt)).toList());
  }

  Future<void> removeFoodFromMeal(String entryId) async {
    await _client.from('food_logs').delete().eq('id', entryId).eq('user_id', _uid);
  }

  // ---------------------------------------------------------------------------
  // WATER (one row per day)
  // ---------------------------------------------------------------------------

  Future<int> updateWaterIntake(DateTime date, int deltaMl) async {
    final dateStr = date.toDateString();
    final row = await _client
        .from('daily_water')
        .select('amount_ml')
        .eq('user_id', _uid)
        .eq('log_date', dateStr)
        .maybeSingle();
    final current = (row?['amount_ml'] as num?)?.toInt() ?? 0;
    final next = (current + deltaMl).clamp(0, 10000);
    await _client.from('daily_water').upsert(
      {
        'user_id': _uid,
        'log_date': dateStr,
        'amount_ml': next,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,log_date',
    );
    return next;
  }

  // ---------------------------------------------------------------------------
  // PROGRESS (weight_history + body_measurements, one entry per day)
  // ---------------------------------------------------------------------------

  Future<List<ProgressEntry>> getProgressEntries() async {
    final weights = await _client
        .from('weight_history')
        .select('id, recorded_date, weight_kg, body_fat_percentage, notes')
        .eq('user_id', _uid)
        .order('recorded_date', ascending: true);
    final measures = await _client
        .from('body_measurements')
        .select('recorded_date, chest_cm, waist_cm, hips_cm, thighs_cm, arms_cm')
        .eq('user_id', _uid);
    final byDate = <String, Map<String, dynamic>>{
      for (final m in measures) m['recorded_date'] as String: m,
    };

    return weights.map((w) {
      final dateStr = w['recorded_date'] as String;
      final m = byDate[dateStr];
      return ProgressEntry(
        id: w['id'] as String,
        date: DateTime.parse(dateStr),
        weightKg: _d(w['weight_kg']),
        bodyFatPercentage: _dn(w['body_fat_percentage']),
        measurements: BodyMeasurements(
          waistCm: _dn(m?['waist_cm']),
          chestCm: _dn(m?['chest_cm']),
          armsCm: _dn(m?['arms_cm']),
          legsCm: _dn(m?['thighs_cm']),
          hipsCm: _dn(m?['hips_cm']),
        ),
        notes: w['notes'] as String?,
      );
    }).toList();
  }

  Future<void> addProgressEntry(ProgressEntry entry) async {
    final dateStr = entry.date.toDateString();
    await _client.from('weight_history').upsert(
      {
        'user_id': _uid,
        'recorded_date': dateStr,
        'weight_kg': _r2(entry.weightKg),
        'body_fat_percentage': entry.bodyFatPercentage == null ? null : _r1(entry.bodyFatPercentage!),
        'notes': entry.notes,
      },
      onConflict: 'user_id,recorded_date',
    );

    final m = entry.measurements;
    final hasMeasurements =
        [m.waistCm, m.chestCm, m.armsCm, m.legsCm, m.hipsCm].any((v) => v != null);
    if (hasMeasurements) {
      await _client.from('body_measurements').upsert(
        {
          'user_id': _uid,
          'recorded_date': dateStr,
          'waist_cm': m.waistCm,
          'chest_cm': m.chestCm,
          'arms_cm': m.armsCm,
          'thighs_cm': m.legsCm,
          'hips_cm': m.hipsCm,
        },
        onConflict: 'user_id,recorded_date',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MEAL PLAN (one saved plan per user)
  // ---------------------------------------------------------------------------

  Future<MealPlan?> getCurrentMealPlan() async {
    final row = await _client.from('user_meal_plans').select('plan').eq('user_id', _uid).maybeSingle();
    final plan = row?['plan'];
    if (plan is Map) {
      try {
        return MealPlan.fromMap(Map<String, dynamic>.from(plan));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> saveMealPlan(MealPlan plan) async {
    await _client.from('user_meal_plans').upsert(
      {
        'user_id': _uid,
        'plan': plan.toMap(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  // ---------------------------------------------------------------------------
  // AI SCAN HISTORY
  // ---------------------------------------------------------------------------

  Future<void> saveScanHistory({
    required List<Map<String, dynamic>> detectedItems,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    double? confidenceScore,
    String? notes,
  }) async {
    await _client.from('ai_scan_history').insert({
      'user_id': _uid,
      'detected_items': detectedItems,
      'total_calories': _r1(totalCalories),
      'total_protein': _r1(totalProtein),
      'total_carbs': _r1(totalCarbs),
      'total_fat': _r1(totalFat),
      'confidence_score': confidenceScore == null ? null : _r2(confidenceScore.clamp(0, 1).toDouble()),
      'notes': notes,
    });
  }
}
