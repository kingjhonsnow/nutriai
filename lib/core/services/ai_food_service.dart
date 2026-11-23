import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_ai/core/config/app_config.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/utils/image_utils.dart';
import 'package:nutri_ai/data/models/food_item.dart';

class DetectedFoodItem {
  final String id;
  String name;
  double estimatedWeightGrams;
  double confidence; // 0.0 - 1.0
  FoodItem matchedFood;

  /// Where the nutrition values come from: 'usda', 'tunisian_table',
  /// 'ai_estimate' or 'manual'.
  final String source;

  DetectedFoodItem({
    required this.id,
    required this.name,
    required this.estimatedWeightGrams,
    required this.confidence,
    required this.matchedFood,
    this.source = 'manual',
  });

  double get calories => matchedFood.getCaloriesFor(estimatedWeightGrams);
  double get protein => matchedFood.getProteinFor(estimatedWeightGrams);
  double get carbs => matchedFood.getCarbsFor(estimatedWeightGrams);
  double get fat => matchedFood.getFatFor(estimatedWeightGrams);
  double get fiber => matchedFood.getFiberFor(estimatedWeightGrams);
  double get sugar => matchedFood.getSugarFor(estimatedWeightGrams);

  /// Human readable nutrition source, shown under each item.
  String get sourceLabel => source == 'manual' ? 'NutriAI food list (your choice)' : matchedFood.category;

  DetectedFoodItem copyWith({
    String? name,
    double? estimatedWeightGrams,
    double? confidence,
    FoodItem? matchedFood,
    String? source,
  }) {
    return DetectedFoodItem(
      id: id,
      name: name ?? this.name,
      estimatedWeightGrams: estimatedWeightGrams ?? this.estimatedWeightGrams,
      confidence: confidence ?? this.confidence,
      matchedFood: matchedFood ?? this.matchedFood,
      source: source ?? this.source,
    );
  }
}

class AIFoodRecognitionResult {
  final String imagePath;
  final List<DetectedFoodItem> detectedItems;
  final String analysisNotes;
  final DateTime analyzedAt;

  const AIFoodRecognitionResult({
    required this.imagePath,
    required this.detectedItems,
    required this.analysisNotes,
    required this.analyzedAt,
  });

  double get totalCalories => detectedItems.fold(0.0, (sum, i) => sum + i.calories);
  double get totalProtein => detectedItems.fold(0.0, (sum, i) => sum + i.protein);
  double get totalCarbs => detectedItems.fold(0.0, (sum, i) => sum + i.carbs);
  double get totalFat => detectedItems.fold(0.0, (sum, i) => sum + i.fat);
  double get totalFiber => detectedItems.fold(0.0, (sum, i) => sum + i.fiber);
}

/// Sends a meal photo to the `analyze-food` Edge Function. The AI keys stay on
/// the server; the app only sends the photo with the user's login token.
/// Camera photos and gallery photos use exactly this same method.
class AIFoodService {
  final SupabaseClient _client;

  AIFoodService(this._client);

  static const int maxUploadBytes = 6 * 1024 * 1024;

  Future<AIFoodRecognitionResult> analyzeFoodImageBytes(Uint8List imageBytes) async {
    final mime = detectImageMime(imageBytes);
    if (!isSupportedUploadMime(mime)) {
      throw const AppException(unsupportedPhotoMessage);
    }
    if (imageBytes.length > maxUploadBytes) {
      throw const AppException('This photo is too large (max 6 MB). Try another photo.');
    }

    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke(
            AppConfig.analyzeFoodFunction,
            body: {'image': base64Encode(imageBytes), 'mime_type': mime},
          )
          .timeout(const Duration(seconds: 75));
    } on TimeoutException {
      throw const AppException('The analysis took too long. Check your connection and try again.');
    } catch (e) {
      throw AppException(friendlyError(e));
    }

    final body = response.data;
    if (body is! Map || body['status'] != 'success' || body['data'] is! Map) {
      final message = body is Map && body['message'] is String
          ? body['message'] as String
          : 'The AI service returned an unexpected answer.';
      throw AppException(message);
    }
    return parseResult(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Converts the Edge Function answer into the app's models.
  static AIFoodRecognitionResult parseResult(Map<String, dynamic> data) {
    final items = (data['items'] as List?) ?? const [];
    final now = DateTime.now();
    final detected = <DetectedFoodItem>[];

    for (var i = 0; i < items.length; i++) {
      final raw = items[i];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final per = item['per_100g'] is Map ? Map<String, dynamic>.from(item['per_100g'] as Map) : <String, dynamic>{};
      double n(Object? v) => (v is num) ? v.toDouble() : 0.0;

      final name = (item['name'] as String?)?.trim().isNotEmpty == true ? item['name'] as String : 'Food';
      final source = (item['source'] as String?) ?? 'ai_estimate';
      final fdcId = item['fdc_id'];
      final grams = n(item['estimated_weight_grams']).clamp(5.0, 2000.0).toDouble();

      final food = FoodItem(
        id: fdcId is num ? 'usda_${fdcId.toInt()}' : 'scan_${now.millisecondsSinceEpoch}_$i',
        name: name,
        category: (item['source_label'] as String?) ?? source,
        caloriesPer100g: n(per['calories']),
        proteinPer100g: n(per['protein']),
        carbsPer100g: n(per['carbs']),
        fatPer100g: n(per['fat']),
        fiberPer100g: n(per['fiber']),
        sugarPer100g: n(per['sugar']),
        defaultServingGrams: grams,
      );

      detected.add(DetectedFoodItem(
        id: 'detected_${now.millisecondsSinceEpoch}_$i',
        name: name,
        estimatedWeightGrams: grams,
        confidence: n(item['confidence']).clamp(0.0, 1.0).toDouble(),
        matchedFood: food,
        source: source,
      ));
    }

    return AIFoodRecognitionResult(
      imagePath: 'camera_or_gallery',
      detectedItems: detected,
      analysisNotes: (data['notes'] as String?)?.trim().isNotEmpty == true
          ? data['notes'] as String
          : (detected.isEmpty ? 'No food detected.' : 'Analysis complete.'),
      analyzedAt: now,
    );
  }
}
