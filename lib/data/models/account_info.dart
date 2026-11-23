import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/data/models/user_profile.dart';

/// Access status of an account, decided by the admin.
enum AccountStatus { pending, approved, rejected, revoked }

/// Account data from the `profiles` table (who the user is and whether they
/// are allowed in). Body data lives in [UserProfile].
class AccountInfo {
  final String id;
  final String email;
  final String fullName;
  final AccountStatus status;
  final bool isAdmin;
  final DateTime? accessUntil;
  final DateTime? createdAt;
  final String? avatarPath;
  final String? avatarUrl;

  const AccountInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    required this.isAdmin,
    this.accessUntil,
    this.createdAt,
    this.avatarPath,
    this.avatarUrl,
  });

  bool get isExpired => accessUntil != null && accessUntil!.isBefore(DateTime.now());

  /// Same rule as `public.is_approved()` in the database.
  bool get hasAccess => isAdmin || (status == AccountStatus.approved && !isExpired);

  AccountInfo copyWith({
    String? fullName,
    String? avatarPath,
    String? avatarUrl,
    bool clearAvatar = false,
  }) {
    return AccountInfo(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      status: status,
      isAdmin: isAdmin,
      accessUntil: accessUntil,
      createdAt: createdAt,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  static AccountStatus parseStatus(Object? value) {
    return AccountStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AccountStatus.pending,
    );
  }

  factory AccountInfo.fromRow(Map<String, dynamic> row, {String? avatarUrl}) {
    return AccountInfo(
      id: row['id'] as String,
      email: (row['email'] as String?) ?? '',
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? (row['full_name'] as String).trim()
          : ((row['email'] as String?) ?? 'User').split('@').first,
      status: parseStatus(row['status']),
      isAdmin: row['is_admin'] == true,
      accessUntil: DateTime.tryParse((row['access_until'] as String?) ?? '')?.toLocal(),
      createdAt: DateTime.tryParse((row['created_at'] as String?) ?? '')?.toLocal(),
      avatarPath: row['avatar_path'] as String?,
      avatarUrl: avatarUrl,
    );
  }
}

/// Converts between the app's enums and the values allowed by the database
/// CHECK constraints (they use different spellings).
class DbMapping {
  DbMapping._();

  static String activityToDb(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'sedentary';
      case ActivityLevel.lightlyActive:
        return 'lightly_active';
      case ActivityLevel.moderatelyActive:
        return 'moderately_active';
      case ActivityLevel.veryActive:
        return 'very_active';
      case ActivityLevel.extremelyActive:
        return 'extra_active';
    }
  }

  static ActivityLevel? activityFromDb(Object? value) {
    switch (value) {
      case 'sedentary':
        return ActivityLevel.sedentary;
      case 'lightly_active':
        return ActivityLevel.lightlyActive;
      case 'moderately_active':
        return ActivityLevel.moderatelyActive;
      case 'very_active':
        return ActivityLevel.veryActive;
      case 'extra_active':
        return ActivityLevel.extremelyActive;
    }
    return null;
  }

  static Gender? genderFromDb(Object? value) {
    switch (value) {
      case 'male':
        return Gender.male;
      case 'female':
        return Gender.female;
    }
    return null;
  }

  static String goalToDb(FitnessGoalType type) {
    switch (type) {
      case FitnessGoalType.muscleGain:
        return 'bulk';
      case FitnessGoalType.fatLoss:
        return 'cut';
      case FitnessGoalType.maintenance:
        return 'maintain';
    }
  }

  static FitnessGoalType goalFromDb(Object? value) {
    switch (value) {
      case 'bulk':
        return FitnessGoalType.muscleGain;
      case 'cut':
        return FitnessGoalType.fatLoss;
    }
    return FitnessGoalType.maintenance;
  }

  /// Builds the body profile from a `profiles` row, or null if the user has
  /// not completed the profile setup yet.
  static UserProfile? bodyProfileFromRow(Map<String, dynamic> row) {
    final age = (row['age'] as num?)?.toInt();
    final height = (row['height_cm'] as num?)?.toDouble();
    final weight = (row['current_weight_kg'] as num?)?.toDouble();
    final gender = genderFromDb(row['gender']);
    final activity = activityFromDb(row['activity_level']);
    if (age == null || height == null || weight == null || gender == null || activity == null) {
      return null;
    }
    final email = (row['email'] as String?) ?? '';
    final name = (row['full_name'] as String?)?.trim();
    return UserProfile.create(
      id: row['id'] as String,
      name: (name == null || name.isEmpty) ? email.split('@').first : name,
      email: email,
      gender: gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      activityLevel: activity,
      bodyFatPercentage: (row['body_fat_percentage'] as num?)?.toDouble(),
      trainingExperience: (row['training_experience'] as String?) ?? 'Intermediate',
      weeklyWorkoutFrequency: (row['training_frequency'] as num?)?.toInt() ?? 3,
    );
  }

  /// Columns written when the user saves their body profile.
  static Map<String, dynamic> bodyProfileToRow(UserProfile p) {
    return {
      'full_name': p.name.trim(),
      'age': p.age,
      'gender': p.gender.name,
      'height_cm': double.parse(p.heightCm.toStringAsFixed(2)),
      'current_weight_kg': double.parse(p.weightKg.toStringAsFixed(2)),
      'activity_level': activityToDb(p.activityLevel),
      'training_frequency': p.weeklyWorkoutFrequency,
      'training_experience': p.trainingExperience,
      'body_fat_percentage':
          p.bodyFatPercentage == null ? null : double.parse(p.bodyFatPercentage!.toStringAsFixed(1)),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
