import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_ai/core/config/app_config.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/core/utils/image_utils.dart';
import 'package:nutri_ai/data/models/account_info.dart';
import 'package:nutri_ai/data/models/fitness_goal.dart';
import 'package:nutri_ai/data/models/user_profile.dart';

/// Everything loaded for a signed-in user at start-up.
class SessionData {
  final AccountInfo account;
  final UserProfile? bodyProfile;
  final FitnessGoal? goal;

  const SessionData(this.account, this.bodyProfile, this.goal);
}

/// Account, profile, goal, profile photo and admin operations (Supabase).
class AccountRepository {
  final SupabaseClient _client;

  AccountRepository(this._client);

  String? avatarUrlFor(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(AppConfig.avatarsBucket).getPublicUrl(path);
  }

  Future<Map<String, dynamic>?> _profileRow(String userId) {
    return _client.from('profiles').select().eq('id', userId).maybeSingle();
  }

  Future<SessionData> loadSession(User user) async {
    var row = await _profileRow(user.id);
    if (row == null) {
      await _client.rpc('ensure_my_profile');
      row = await _profileRow(user.id);
    }
    if (row == null) {
      throw const AppException('Your account profile could not be created. Please contact the admin.');
    }
    final account = AccountInfo.fromRow(row, avatarUrl: avatarUrlFor(row['avatar_path'] as String?));
    final body = DbMapping.bodyProfileFromRow(row);
    final goal = account.hasAccess ? await fetchActiveGoal(user.id) : null;
    return SessionData(account, body, goal);
  }

  // ---------------------------------------------------------------------------
  // Body profile and goal
  // ---------------------------------------------------------------------------

  Future<void> saveBodyProfile(String userId, UserProfile profile) async {
    await _client.from('profiles').update(DbMapping.bodyProfileToRow(profile)).eq('id', userId);
  }

  Future<FitnessGoal?> fetchActiveGoal(String userId) async {
    final row = await _client
        .from('fitness_goals')
        .select('details, created_at')
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final details = row?['details'];
    if (details is Map) {
      return FitnessGoal.fromMap(Map<String, dynamic>.from(details));
    }
    return null;
  }

  Future<void> saveGoal(String userId, FitnessGoal goal, UserProfile profile) async {
    double r1(double v) => double.parse(v.toStringAsFixed(1));

    await _client
        .from('fitness_goals')
        .update({'is_active': false, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .eq('is_active', true);
    await _client.from('fitness_goals').insert({
      'user_id': userId,
      'goal_type': DbMapping.goalToDb(goal.type),
      'target_weight_rate_kg_week': double.parse(goal.weeklyWeightChangeKg.toStringAsFixed(2)),
      'surplus_deficit_calories': (goal.targetCalories - profile.tdee).round(),
      'details': goal.toMap(),
      'is_active': true,
    });

    await _client
        .from('nutrition_targets')
        .update({'is_active': false, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .eq('is_active', true);
    await _client.from('nutrition_targets').insert({
      'user_id': userId,
      'daily_calories': goal.targetCalories,
      'protein_grams': goal.targetProtein,
      'carbs_grams': goal.targetCarbs,
      'fat_grams': goal.targetFat,
      'fiber_grams': 30,
      'water_ml': NutritionCalculator.calculateWaterIntakeMl(profile.weightKg),
      'bmr': r1(profile.bmr),
      'tdee': r1(profile.tdee),
      'bmi': r1(profile.bmi),
      'is_active': true,
    });
  }

  // ---------------------------------------------------------------------------
  // Profile photo: stored at avatars/<user id>/avatar_<time>.<ext>
  // ---------------------------------------------------------------------------

  /// Uploads a new photo, points the profile at it and deletes the old file.
  /// Returns the new storage path.
  Future<String> uploadAvatar(String userId, Uint8List bytes, {String? oldPath}) async {
    final mime = detectImageMime(bytes);
    if (!isSupportedUploadMime(mime)) {
      throw const AppException(unsupportedPhotoMessage);
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AppException('This photo is too large (max 5 MB).');
    }
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.${extensionForMime(mime!)}';
    final bucket = _client.storage.from(AppConfig.avatarsBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false, cacheControl: '31536000'),
    );
    try {
      await _client
          .from('profiles')
          .update({'avatar_path': path, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      // Keep storage clean if the profile could not be updated.
      try {
        await bucket.remove([path]);
      } catch (_) {}
      rethrow;
    }
    if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
      try {
        await bucket.remove([oldPath]);
      } catch (_) {
        // An orphaned old file is harmless; the profile already points to the new one.
      }
    }
    return path;
  }

  Future<void> removeAvatar(String userId, String? path) async {
    await _client
        .from('profiles')
        .update({'avatar_path': null, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
    if (path != null && path.isNotEmpty) {
      try {
        await _client.storage.from(AppConfig.avatarsBucket).remove([path]);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Account deletion
  // ---------------------------------------------------------------------------

  Future<void> deleteMyAccount({String? avatarPath}) async {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        await _client.storage.from(AppConfig.avatarsBucket).remove([avatarPath]);
      } catch (_) {}
    }
    await _client.rpc('delete_my_account');
  }

  // ---------------------------------------------------------------------------
  // Admin (the database rejects these calls for anyone who is not the admin)
  // ---------------------------------------------------------------------------

  Future<List<AccountInfo>> adminListAccounts() async {
    final rows = await _client
        .from('profiles')
        .select('id, email, full_name, status, is_admin, access_until, created_at, avatar_path')
        .order('created_at', ascending: false);
    return rows
        .map((r) => AccountInfo.fromRow(r, avatarUrl: avatarUrlFor(r['avatar_path'] as String?)))
        .toList();
  }

  Future<void> adminSetAccess(String userId, AccountStatus status, {DateTime? accessUntil}) async {
    await _client.rpc('admin_set_user_access', params: {
      'target_user': userId,
      'new_status': status.name,
      'new_access_until': accessUntil?.toUtc().toIso8601String(),
    });
  }

  Future<void> adminSetPassword(String userId, String newPassword) async {
    await _client.rpc('admin_set_password', params: {
      'target_user': userId,
      'new_password': newPassword,
    });
  }

  Future<void> adminDeleteUser(String userId) async {
    await _client.rpc('admin_delete_user', params: {'target_user': userId});
  }
}
