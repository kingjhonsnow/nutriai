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
  /// 'package_label', 'ai_estimate' or 'manual'.
  final String source;

  /// Packaged product (biscuits, chips, yogurt...): pack net weight and pieces,
  /// read from the pack by the AI when visible, editable by the user.
  final bool isPackaged;
  final String? brand;
  final double? packageWeightG;
  final int? piecesPerPackage;

  /// Weight of one piece for countable foods (eggs, dates, biscuits...).
  final double? pieceWeightG;

  /// Pieces eaten when the portion was set by pieces; null when set in grams.
  final int? pieceCount;

  DetectedFoodItem({
    required this.id,
    required this.name,
    required this.estimatedWeightGrams,
    required this.confidence,
    required this.matchedFood,
    this.source = 'manual',
    this.isPackaged = false,
    this.brand,
    this.packageWeightG,
    this.piecesPerPackage,
    this.pieceWeightG,
    this.pieceCount,
  });

  /// Weight of one piece: pack weight / pieces for packs, otherwise the estimate.
  double? get effectivePieceWeightG {
    final w = packageWeightG;
    final p = piecesPerPackage;
    if (isPackaged && w != null && p != null && p > 0) return w / p;
    return pieceWeightG;
  }

  /// How much was eaten, in words, e.g. "3 of 12 pieces" or "half a pack".
  String? get portionNote {
    final count = pieceCount;
    if (count != null) {
      if (isPackaged && piecesPerPackage != null) return '$count of $piecesPerPackage pieces';
      return count == 1 ? '1 piece' : '$count pieces';
    }
    final w = packageWeightG;
    if (isPackaged && w != null && w > 0) {
      final f = estimatedWeightGrams / w;
      if ((f - 1).abs() < 0.02) return 'whole pack';
      if ((f - 0.5).abs() < 0.02) return 'half a pack';
      if ((f - 0.25).abs() < 0.02) return 'a quarter of the pack';
      if ((f - 0.75).abs() < 0.02) return 'three quarters of the pack';
    }
    return null;
  }

  /// Name saved in the diary, with the portion when known.
  String get diaryName {
    final note = portionNote;
    return note == null ? name : '$name ($note)';
  }

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
    double? packageWeightG,
    int? piecesPerPackage,
    double? pieceWeightG,
    int? pieceCount,
    bool clearPieceCount = false,
  }) {
    return DetectedFoodItem(
      id: id,
      name: name ?? this.name,
      estimatedWeightGrams: estimatedWeightGrams ?? this.estimatedWeightGrams,
      confidence: confidence ?? this.confidence,
      matchedFood: matchedFood ?? this.matchedFood,
      source: source ?? this.source,
      isPackaged: isPackaged,
      brand: brand,
      packageWeightG: packageWeightG ?? this.packageWeightG,
      piecesPerPackage: piecesPerPackage ?? this.piecesPerPackage,
      pieceWeightG: pieceWeightG ?? this.pieceWeightG,
      pieceCount: clearPieceCount ? null : (pieceCount ?? this.pieceCount),
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
      final grams = n(item['estimated_weight_grams']).clamp(5.0, 5000.0).toDouble();
      double? optional(Object? v) => (v is num && v > 0) ? v.toDouble() : null;
      final isPackaged = item['is_packaged'] == true;
      final packWeight = isPackaged ? optional(item['package_weight_g']) : null;
      final packPieces = isPackaged ? optional(item['pieces_per_package'])?.round() : null;
      final brand = (item['brand'] as String?)?.trim();

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
        isPackaged: isPackaged,
        brand: (brand == null || brand.isEmpty) ? null : brand,
        packageWeightG: packWeight,
        piecesPerPackage: packPieces,
        pieceWeightG: optional(item['piece_weight_g']),
        // A pack starts as "whole pack": all pieces eaten.
        pieceCount: (packPieces != null && packWeight != null && (grams - packWeight).abs() < 1) ? packPieces : null,
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
