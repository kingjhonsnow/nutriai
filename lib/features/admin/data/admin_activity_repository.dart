import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// -----------------------------------------------------------------------------
// Small parsing helpers (Supabase returns numbers as num or String).
// -----------------------------------------------------------------------------
double _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _int(Object? v) => _num(v).round();

double? _numOrNull(Object? v) => v == null ? null : _num(v);

/// Timestamps (with time zone) converted to the phone's local time.
DateTime? _time(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// Plain dates ("2026-11-27"), kept as that calendar day.
DateTime? _date(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------
class AdminUserStats {
  final String userId;
  final int opensToday;
  final int minutesToday;
  final int opens7Days;
  final int activeDays7;
  final DateTime? lastSeenAt;
  final int mealsToday;
  final double caloriesToday;
  final int scansToday;
  final int waterTodayMl;
  final double? lastWeightKg;
  final DateTime? lastWeightDate;

  const AdminUserStats({
    required this.userId,
    required this.opensToday,
    required this.minutesToday,
    required this.opens7Days,
    required this.activeDays7,
    required this.lastSeenAt,
    required this.mealsToday,
    required this.caloriesToday,
    required this.scansToday,
    required this.waterTodayMl,
    required this.lastWeightKg,
    required this.lastWeightDate,
  });

  factory AdminUserStats.fromRow(Map<String, dynamic> r) => AdminUserStats(
        userId: r['user_id'].toString(),
        opensToday: _int(r['opens_today']),
        minutesToday: _int(r['minutes_today']),
        opens7Days: _int(r['opens_7_days']),
        activeDays7: _int(r['active_days_7']),
        lastSeenAt: _time(r['last_seen_at']),
        mealsToday: _int(r['meals_today']),
        caloriesToday: _num(r['calories_today']),
        scansToday: _int(r['scans_today']),
        waterTodayMl: _int(r['water_today_ml']),
        lastWeightKg: _numOrNull(r['last_weight_kg']),
        lastWeightDate: _date(r['last_weight_date']),
      );
}

class DailyActivity {
  final DateTime day;
  final int opens;
  final int minutes;
  final int meals;
  final double calories;
  final int waterMl;
  final int scans;

  const DailyActivity({
    required this.day,
    required this.opens,
    required this.minutes,
    required this.meals,
    required this.calories,
    required this.waterMl,
    required this.scans,
  });

  bool get isEmpty => opens == 0 && meals == 0 && waterMl == 0 && scans == 0;

  factory DailyActivity.fromRow(Map<String, dynamic> r) => DailyActivity(
        day: _date(r['day']) ?? DateTime.now(),
        opens: _int(r['opens']),
        minutes: _int(r['minutes']),
        meals: _int(r['meals']),
        calories: _num(r['calories']),
        waterMl: _int(r['water_ml']),
        scans: _int(r['scans']),
      );
}

class AppSession {
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final String? platform;

  const AppSession({required this.startedAt, required this.lastSeenAt, this.platform});

  int get minutes {
    final m = (lastSeenAt.difference(startedAt).inSeconds / 60).ceil();
    return m < 1 ? 1 : m;
  }

  /// "web-iOS" -> "iPhone/iPad (web app)"
  String get deviceLabel {
    final p = (platform ?? '').toLowerCase();
    if (p.contains('ios')) return 'iPhone/iPad';
    if (p.contains('android')) return 'Android';
    if (p.contains('windows')) return 'Windows PC';
    if (p.contains('macos')) return 'Mac';
    if (p.contains('linux')) return 'Linux PC';
    return 'Unknown device';
  }

  factory AppSession.fromRow(Map<String, dynamic> r) => AppSession(
        startedAt: _time(r['started_at']) ?? DateTime.now(),
        lastSeenAt: _time(r['last_seen_at']) ?? DateTime.now(),
        platform: r['platform'] as String?,
      );
}

class AdminFoodLog {
  final String mealType;
  final String name;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? source;
  final DateTime? createdAt;

  const AdminFoodLog({
    required this.mealType,
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.source,
    this.createdAt,
  });

  factory AdminFoodLog.fromRow(Map<String, dynamic> r) => AdminFoodLog(
        mealType: (r['meal_type'] ?? 'snack').toString(),
        name: (r['food_name'] ?? '').toString().isEmpty ? 'Food' : r['food_name'].toString(),
        grams: _num(r['serving_amount_g']),
        calories: _num(r['calories']),
        protein: _num(r['protein']),
        carbs: _num(r['carbs']),
        fat: _num(r['fat']),
        source: r['source'] as String?,
        createdAt: _time(r['created_at']),
      );
}

class AdminScan {
  final DateTime scannedAt;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> items;

  const AdminScan({
    required this.scannedAt,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.items,
  });

  factory AdminScan.fromRow(Map<String, dynamic> r) {
    final raw = r['detected_items'];
    final items = <String>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final name = (e['name'] ?? '').toString();
          final grams = _num(e['weight_g']).round();
          items.add(grams > 0 ? '$name ($grams g)' : name);
        } else if (e != null) {
          items.add(e.toString());
        }
      }
    }
    return AdminScan(
      scannedAt: _time(r['scanned_at']) ?? DateTime.now(),
      calories: _num(r['total_calories']),
      protein: _num(r['total_protein']),
      carbs: _num(r['total_carbs']),
      fat: _num(r['total_fat']),
      items: items,
    );
  }
}

class AdminWeight {
  final DateTime date;
  final double kg;
  final double? bodyFat;

  const AdminWeight({required this.date, required this.kg, this.bodyFat});

  factory AdminWeight.fromRow(Map<String, dynamic> r) => AdminWeight(
        date: _date(r['recorded_date']) ?? DateTime.now(),
        kg: _num(r['weight_kg']),
        bodyFat: _numOrNull(r['body_fat_percentage']),
      );
}

class AdminMeasurement {
  final DateTime date;
  final Map<String, double?> values; // label -> cm

  const AdminMeasurement({required this.date, required this.values});

  factory AdminMeasurement.fromRow(Map<String, dynamic> r) => AdminMeasurement(
        date: _date(r['recorded_date']) ?? DateTime.now(),
        values: {
          'Chest': _numOrNull(r['chest_cm']),
          'Waist': _numOrNull(r['waist_cm']),
          'Hips': _numOrNull(r['hips_cm']),
          'Thighs': _numOrNull(r['thighs_cm']),
          'Arms': _numOrNull(r['arms_cm']),
        },
      );
}

class AdminUserProgress {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? targets;
  final String? goalType;
  final List<AdminWeight> weights;
  final List<AdminMeasurement> measurements;

  const AdminUserProgress({
    required this.profile,
    required this.targets,
    required this.goalType,
    required this.weights,
    required this.measurements,
  });
}

// -----------------------------------------------------------------------------
// Repository: everything here only works for the admin account (checked by
// the database, not only by the app).
// -----------------------------------------------------------------------------
class AdminActivityRepository {
  final SupabaseClient _client;

  AdminActivityRepository(this._client);

  int get _offsetMinutes => DateTime.now().timeZoneOffset.inMinutes;

  Future<Map<String, AdminUserStats>> usersOverview() async {
    final rows = await _client.rpc('admin_users_overview', params: {
      'p_today': dateParam(DateTime.now()),
      'p_utc_offset_minutes': _offsetMinutes,
    });
    final result = <String, AdminUserStats>{};
    for (final r in (rows as List)) {
      final stats = AdminUserStats.fromRow(Map<String, dynamic>.from(r as Map));
      result[stats.userId] = stats;
    }
    return result;
  }

  Future<List<DailyActivity>> dailyActivity(String userId, {int days = 14}) async {
    final rows = await _client.rpc('admin_user_daily_activity', params: {
      'p_user': userId,
      'p_today': dateParam(DateTime.now()),
      'p_utc_offset_minutes': _offsetMinutes,
      'p_days': days,
    });
    return (rows as List).map((r) => DailyActivity.fromRow(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<List<AppSession>> recentSessions(String userId, {int limit = 30}) async {
    final rows = await _client
        .from('app_sessions')
        .select('started_at, last_seen_at, platform')
        .eq('user_id', userId)
        .order('started_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AppSession.fromRow(r)).toList();
  }

  Future<List<AdminFoodLog>> foodLogs(String userId, DateTime day) async {
    final rows = await _client
        .from('food_logs')
        .select('meal_type, food_name, serving_amount_g, calories, protein, carbs, fat, source, created_at')
        .eq('user_id', userId)
        .eq('log_date', dateParam(day))
        .order('created_at', ascending: true);
    return rows.map((r) => AdminFoodLog.fromRow(r)).toList();
  }

  Future<int> waterMl(String userId, DateTime day) async {
    final row = await _client
        .from('daily_water')
        .select('amount_ml')
        .eq('user_id', userId)
        .eq('log_date', dateParam(day))
        .maybeSingle();
    return row == null ? 0 : _int(row['amount_ml']);
  }

  Future<Map<String, dynamic>?> activeTargets(String userId) async {
    final row = await _client
        .from('nutrition_targets')
        .select('daily_calories, protein_grams, carbs_grams, fat_grams, water_ml')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row;
  }

  Future<List<AdminScan>> scans(String userId, {int limit = 50}) async {
    final rows = await _client
        .from('ai_scan_history')
        .select('scanned_at, total_calories, total_protein, total_carbs, total_fat, detected_items')
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(limit);
    return rows.map((r) => AdminScan.fromRow(r)).toList();
  }

  Future<AdminUserProgress> progress(String userId) async {
    final profile = await _client
        .from('profiles')
        .select('age, gender, height_cm, current_weight_kg, target_weight_kg, activity_level, '
            'training_frequency, created_at')
        .eq('id', userId)
        .maybeSingle();

    final targets = await _client
        .from('nutrition_targets')
        .select('daily_calories, protein_grams, carbs_grams, fat_grams, water_ml')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final goal = await _client
        .from('fitness_goals')
        .select('goal_type')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final weights = await _client
        .from('weight_history')
        .select('recorded_date, weight_kg, body_fat_percentage')
        .eq('user_id', userId)
        .order('recorded_date', ascending: false)
        .limit(60);

    final measurements = await _client
        .from('body_measurements')
        .select('recorded_date, chest_cm, waist_cm, hips_cm, thighs_cm, arms_cm')
        .eq('user_id', userId)
        .order('recorded_date', ascending: false)
        .limit(20);

    return AdminUserProgress(
      profile: profile,
      targets: targets,
      goalType: goal?['goal_type'] as String?,
      weights: weights.map((r) => AdminWeight.fromRow(r)).toList(),
      measurements: measurements.map((r) => AdminMeasurement.fromRow(r)).toList(),
    );
  }
}

final adminActivityRepositoryProvider = Provider<AdminActivityRepository>((ref) {
  return AdminActivityRepository(ref.watch(supabaseClientProvider));
});
