import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_ai/core/services/ai_food_service.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/core/utils/image_utils.dart';
import 'package:nutri_ai/data/models/account_info.dart';

void main() {
  group('Database value mapping', () {
    test('activity levels match the database CHECK values', () {
      expect(DbMapping.activityToDb(ActivityLevel.lightlyActive), 'lightly_active');
      expect(DbMapping.activityToDb(ActivityLevel.extremelyActive), 'extra_active');
      for (final level in ActivityLevel.values) {
        expect(DbMapping.activityFromDb(DbMapping.activityToDb(level)), level);
      }
    });

    test('goal types match the database CHECK values', () {
      expect(DbMapping.goalToDb(FitnessGoalType.muscleGain), 'bulk');
      expect(DbMapping.goalToDb(FitnessGoalType.fatLoss), 'cut');
      expect(DbMapping.goalToDb(FitnessGoalType.maintenance), 'maintain');
      for (final type in FitnessGoalType.values) {
        expect(DbMapping.goalFromDb(DbMapping.goalToDb(type)), type);
      }
    });

    test('body profile is null until setup is complete, then round-trips', () {
      final partial = {'id': 'u1', 'email': 'a@b.co', 'full_name': 'Amina', 'age': 30};
      expect(DbMapping.bodyProfileFromRow(partial), isNull);

      final row = {
        'id': 'u1',
        'email': 'a@b.co',
        'full_name': 'Amina',
        'age': 30,
        'gender': 'female',
        'height_cm': 168.0,
        'current_weight_kg': 61.5,
        'activity_level': 'moderately_active',
        'training_frequency': 3,
        'training_experience': 'Beginner',
        'body_fat_percentage': 24.0,
      };
      final profile = DbMapping.bodyProfileFromRow(row)!;
      expect(profile.gender, Gender.female);
      expect(profile.activityLevel, ActivityLevel.moderatelyActive);
      final back = DbMapping.bodyProfileToRow(profile);
      expect(back['activity_level'], 'moderately_active');
      expect(back['gender'], 'female');
      expect(back['current_weight_kg'], 61.5);
    });

    test('access rules match the database is_approved() function', () {
      AccountInfo acc(String status, {bool admin = false, DateTime? until}) => AccountInfo.fromRow({
            'id': 'u',
            'email': 'x@y.z',
            'full_name': 'X',
            'status': status,
            'is_admin': admin,
            'access_until': until?.toUtc().toIso8601String(),
          });
      expect(acc('pending').hasAccess, isFalse);
      expect(acc('approved').hasAccess, isTrue);
      expect(acc('revoked').hasAccess, isFalse);
      expect(acc('approved', until: DateTime.now().subtract(const Duration(days: 1))).hasAccess, isFalse);
      expect(acc('approved', until: DateTime.now().add(const Duration(days: 1))).hasAccess, isTrue);
      expect(acc('pending', admin: true).hasAccess, isTrue);
    });
  });

  group('Photo type detection', () {
    Uint8List bytes(List<int> head) => Uint8List.fromList([...head, ...List.filled(16, 0)]);

    test('recognises JPEG, PNG, WebP and HEIC', () {
      expect(detectImageMime(bytes([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(detectImageMime(bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'image/png');
      expect(detectImageMime(bytes([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])), 'image/webp');
      expect(detectImageMime(bytes([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])), 'image/heic');
      expect(isSupportedUploadMime('image/heic'), isFalse);
      expect(isSupportedUploadMime('image/jpeg'), isTrue);
    });
  });

  group('AI response parsing', () {
    test('builds items with nutrition per 100 g and source labels', () {
      final result = AIFoodService.parseResult({
        'items': [
          {
            'name': 'White rice',
            'estimated_weight_grams': 200,
            'confidence': 0.9,
            'source': 'usda',
            'source_label': 'USDA FoodData Central',
            'fdc_id': 168878,
            'per_100g': {'calories': 130, 'protein': 2.7, 'carbs': 28.2, 'fat': 0.3, 'fiber': 0.4, 'sugar': 0.1},
          },
          {
            'name': 'Lablabi',
            'estimated_weight_grams': 350,
            'confidence': 0.8,
            'source': 'tunisian_table',
            'source_label': 'NutriAI Tunisian dishes table',
            'per_100g': {'calories': 135, 'protein': 6.8, 'carbs': 22, 'fat': 2.8, 'fiber': 4.5, 'sugar': 1.5},
          },
        ],
        'notes': 'Rice and lablabi',
      });
      expect(result.detectedItems.length, 2);
      expect(result.detectedItems.first.matchedFood.id, 'usda_168878');
      expect(result.detectedItems.first.calories, closeTo(260, 0.01));
      expect(result.detectedItems.last.sourceLabel, 'NutriAI Tunisian dishes table');
      expect(result.totalCalories, closeTo(260 + 472.5, 0.01));
    });

    test('empty answer means no food detected', () {
      final result = AIFoodService.parseResult({'items': [], 'notes': ''});
      expect(result.detectedItems, isEmpty);
      expect(result.analysisNotes, 'No food detected.');
    });
  });
}
