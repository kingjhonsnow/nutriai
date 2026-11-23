import 'package:nutri_ai/core/utils/calculations.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final double? bodyFatPercentage;
  final String trainingExperience; // 'Beginner', 'Intermediate', 'Advanced'
  final int weeklyWorkoutFrequency;
  final double bmi;
  final double bmr;
  final double tdee;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    this.bodyFatPercentage,
    this.trainingExperience = 'Intermediate',
    this.weeklyWorkoutFrequency = 4,
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.create({
    required String id,
    required String name,
    required String email,
    required Gender gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    double? bodyFatPercentage,
    String trainingExperience = 'Intermediate',
    int weeklyWorkoutFrequency = 4,
  }) {
    final bmi = NutritionCalculator.calculateBMI(weightKg, heightCm);
    final bmr = NutritionCalculator.calculateBMR(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final tdee = NutritionCalculator.calculateTDEE(
      bmr: bmr,
      activityLevel: activityLevel,
    );
    final now = DateTime.now();

    return UserProfile(
      id: id,
      name: name,
      email: email,
      gender: gender,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
      bodyFatPercentage: bodyFatPercentage,
      trainingExperience: trainingExperience,
      weeklyWorkoutFrequency: weeklyWorkoutFrequency,
      bmi: bmi,
      bmr: bmr,
      tdee: tdee,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    double? bodyFatPercentage,
    String? trainingExperience,
    int? weeklyWorkoutFrequency,
    DateTime? updatedAt,
  }) {
    final newWeight = weightKg ?? this.weightKg;
    final newHeight = heightCm ?? this.heightCm;
    final newAge = age ?? this.age;
    final newGender = gender ?? this.gender;
    final newActivity = activityLevel ?? this.activityLevel;

    final newBmi = NutritionCalculator.calculateBMI(newWeight, newHeight);
    final newBmr = NutritionCalculator.calculateBMR(
      weightKg: newWeight,
      heightCm: newHeight,
      age: newAge,
      gender: newGender,
    );
    final newTdee = NutritionCalculator.calculateTDEE(
      bmr: newBmr,
      activityLevel: newActivity,
    );

    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: newGender,
      age: newAge,
      heightCm: newHeight,
      weightKg: newWeight,
      activityLevel: newActivity,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      trainingExperience: trainingExperience ?? this.trainingExperience,
      weeklyWorkoutFrequency: weeklyWorkoutFrequency ?? this.weeklyWorkoutFrequency,
      bmi: newBmi,
      bmr: newBmr,
      tdee: newTdee,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'gender': gender.name,
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel.name,
      'bodyFatPercentage': bodyFatPercentage,
      'trainingExperience': trainingExperience,
      'weeklyWorkoutFrequency': weeklyWorkoutFrequency,
      'bmi': bmi,
      'bmr': bmr,
      'tdee': tdee,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'user_1',
      name: map['name'] as String? ?? 'User',
      email: map['email'] as String? ?? '',
      gender: Gender.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => Gender.male,
      ),
      age: map['age'] as int? ?? 25,
      heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 75.0,
      activityLevel: ActivityLevel.values.firstWhere(
        (a) => a.name == map['activityLevel'],
        orElse: () => ActivityLevel.moderatelyActive,
      ),
      bodyFatPercentage: (map['bodyFatPercentage'] as num?)?.toDouble(),
      trainingExperience: map['trainingExperience'] as String? ?? 'Intermediate',
      weeklyWorkoutFrequency: map['weeklyWorkoutFrequency'] as int? ?? 4,
      bmi: (map['bmi'] as num?)?.toDouble() ?? 24.5,
      bmr: (map['bmr'] as num?)?.toDouble() ?? 1750.0,
      tdee: (map['tdee'] as num?)?.toDouble() ?? 2500.0,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
