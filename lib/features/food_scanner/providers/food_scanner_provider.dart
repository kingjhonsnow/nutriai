import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/ai_food_service.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/database_service.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/food_item.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/dashboard/providers/dashboard_provider.dart';
import 'package:nutri_ai/features/food_diary/providers/food_diary_provider.dart';

class FoodScannerState {
  final bool isScanning;
  final AIFoodRecognitionResult? result;
  final String? errorMessage;
  final MealType selectedMealType;

  /// Raw bytes of the captured or picked photo, shown on the results screen.
  final Uint8List? capturedImageBytes;
  final bool isSaving;

  const FoodScannerState({
    this.isScanning = false,
    this.result,
    this.errorMessage,
    this.selectedMealType = MealType.lunch,
    this.capturedImageBytes,
    this.isSaving = false,
  });

  FoodScannerState copyWith({
    bool? isScanning,
    AIFoodRecognitionResult? result,
    String? errorMessage,
    MealType? selectedMealType,
    Uint8List? capturedImageBytes,
    bool? isSaving,
  }) {
    return FoodScannerState(
      isScanning: isScanning ?? this.isScanning,
      result: result ?? this.result,
      errorMessage: errorMessage,
      selectedMealType: selectedMealType ?? this.selectedMealType,
      capturedImageBytes: capturedImageBytes ?? this.capturedImageBytes,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

MealType _mealTypeForNow() {
  final hour = DateTime.now().hour;
  if (hour < 11) return MealType.breakfast;
  if (hour < 16) return MealType.lunch;
  if (hour < 22) return MealType.dinner;
  return MealType.snack;
}

class FoodScannerNotifier extends StateNotifier<FoodScannerState> {
  final Ref _ref;

  FoodScannerNotifier(this._ref) : super(FoodScannerState(selectedMealType: _mealTypeForNow()));

  void setMealType(MealType type) {
    state = state.copyWith(selectedMealType: type);
  }

  /// The single analysis pipeline for camera AND gallery photos.
  Future<void> scanImageBytes(Uint8List imageBytes) async {
    // Fresh state: never show the previous photo's foods for a new scan.
    state = FoodScannerState(
      isScanning: true,
      selectedMealType: state.selectedMealType,
      capturedImageBytes: imageBytes,
    );
    try {
      final detection = await _ref.read(aiFoodServiceProvider).analyzeFoodImageBytes(imageBytes);
      if (!mounted) return;
      state = state.copyWith(isScanning: false, result: detection);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isScanning: false, errorMessage: friendlyError(e));
    }
  }

  void _setItems(List<DetectedFoodItem> items) {
    final current = state.result;
    if (current == null) return;
    state = state.copyWith(
      result: AIFoodRecognitionResult(
        imagePath: current.imagePath,
        detectedItems: items,
        analysisNotes: current.analysisNotes,
        analyzedAt: current.analyzedAt,
      ),
    );
  }

  void _updateItem(String itemId, DetectedFoodItem Function(DetectedFoodItem item) change) {
    final current = state.result;
    if (current == null) return;
    _setItems(current.detectedItems.map((item) => item.id == itemId ? change(item) : item).toList());
  }

  static double _validGrams(double grams) => grams.clamp(1.0, 5000.0).toDouble();

  /// Portion set in grams (slider or typed): no longer counted in pieces.
  void updateItemPortion(String itemId, double newWeightGrams) {
    _updateItem(
      itemId,
      (item) => item.copyWith(estimatedWeightGrams: _validGrams(newWeightGrams), clearPieceCount: true),
    );
  }

  /// Portion counted in pieces. [pieceWeightG] is needed when the weight of
  /// one piece is not known yet (typed by the user).
  void setItemPieces(String itemId, int count, {double? pieceWeightG}) {
    _updateItem(itemId, (item) {
      final usePack = item.isPackaged && item.piecesPerPackage != null && item.packageWeightG != null;
      final weight = usePack ? item.effectivePieceWeightG : (pieceWeightG ?? item.pieceWeightG);
      if (weight == null || weight <= 0 || count < 1) return item;
      return item.copyWith(
        estimatedWeightGrams: _validGrams(weight * count),
        pieceCount: count,
        pieceWeightG: usePack ? null : weight,
      );
    });
  }

  /// Quick portion for packs: a quarter, half, three quarters or the whole pack.
  void setPackFraction(String itemId, double fraction) {
    _updateItem(itemId, (item) {
      final weight = item.packageWeightG;
      if (weight == null || weight <= 0) return item;
      final pieces = item.piecesPerPackage;
      if (pieces != null && pieces > 0) {
        final count = (pieces * fraction).round().clamp(1, pieces * 5).toInt();
        if ((count - pieces * fraction).abs() < 0.01) {
          return item.copyWith(estimatedWeightGrams: _validGrams(weight / pieces * count), pieceCount: count);
        }
      }
      return item.copyWith(estimatedWeightGrams: _validGrams(weight * fraction), clearPieceCount: true);
    });
  }

  /// The user corrected the pack weight and/or the number of pieces in it.
  /// Keeps what was eaten: the same number of pieces, or the same share of the pack.
  void updatePackInfo(String itemId, {double? packageWeightG, int? piecesPerPackage}) {
    _updateItem(itemId, (item) {
      final oldWeight = item.packageWeightG;
      final newWeight = packageWeightG ?? oldWeight;
      final newPieces = piecesPerPackage ?? item.piecesPerPackage;
      var updated = item.copyWith(packageWeightG: newWeight, piecesPerPackage: newPieces);
      if (newWeight == null || newWeight <= 0) return updated;

      final count = item.pieceCount;
      if (count != null && newPieces != null && newPieces > 0) {
        final kept = count.clamp(1, newPieces * 5).toInt();
        return updated.copyWith(estimatedWeightGrams: _validGrams(newWeight / newPieces * kept), pieceCount: kept);
      }
      final share = (oldWeight != null && oldWeight > 0) ? item.estimatedWeightGrams / oldWeight : 1.0;
      updated = updated.copyWith(estimatedWeightGrams: _validGrams(newWeight * share));
      if (newPieces != null && newPieces > 0 && (share - 1).abs() < 0.02) {
        updated = updated.copyWith(pieceCount: newPieces); // whole pack = all pieces
      }
      return updated;
    });
  }

  void removeItem(String itemId) {
    final current = state.result;
    if (current == null) return;
    _setItems(current.detectedItems.where((i) => i.id != itemId).toList());
  }

  /// Manual correction: replace a detected item with a food from the list.
  void replaceItemFood(String itemId, FoodItem food) {
    final current = state.result;
    if (current == null) return;
    _setItems(current.detectedItems
        .map((item) => item.id == itemId
            ? item.copyWith(name: food.name, matchedFood: food, confidence: 1.0, source: 'manual')
            : item)
        .toList());
  }

  void addManualFoodItem(FoodItem food, double grams) {
    final current = state.result;
    if (current == null) return;
    _setItems([
      ...current.detectedItems,
      DetectedFoodItem(
        id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        name: food.name,
        estimatedWeightGrams: grams,
        confidence: 1.0,
        matchedFood: food,
        source: 'manual',
      ),
    ]);
  }

  /// Saves the whole meal in one request. Returns null on success, otherwise
  /// an error message for the user (nothing is saved in that case).
  Future<String?> saveMealToDiary() async {
    final result = state.result;
    if (result == null || result.detectedItems.isEmpty) return 'There is nothing to save.';
    state = state.copyWith(isSaving: true);

    final db = _ref.read(databaseServiceProvider);
    try {
      await db.addFoodsToMeal(
        date: DateTime.now(),
        mealType: state.selectedMealType,
        items: result.detectedItems
            .map((i) => FoodLogInput(i.matchedFood.copyWith(name: i.diaryName), i.estimatedWeightGrams, source: i.source))
            .toList(),
      );
    } catch (e) {
      if (mounted) state = state.copyWith(isSaving: false);
      return friendlyError(e);
    }

    // Scan history is a nice-to-have: a failure here must not fail the save.
    try {
      await db.saveScanHistory(
        detectedItems: result.detectedItems
            .map((i) => {
                  'name': i.diaryName,
                  'weight_g': i.estimatedWeightGrams,
                  'calories': i.calories,
                  'protein': i.protein,
                  'carbs': i.carbs,
                  'fat': i.fat,
                  'confidence': i.confidence,
                  'source': i.source,
                })
            .toList(),
        totalCalories: result.totalCalories,
        totalProtein: result.totalProtein,
        totalCarbs: result.totalCarbs,
        totalFat: result.totalFat,
        confidenceScore: result.detectedItems.map((i) => i.confidence).reduce((a, b) => a + b) /
            result.detectedItems.length,
        notes: result.analysisNotes,
      );
    } catch (e) {
      debugPrint('[Scanner] scan history not saved: $e');
    }

    if (mounted) state = state.copyWith(isSaving: false);
    _ref.read(dashboardProvider.notifier).refreshDashboard();
    _ref.read(foodDiaryProvider.notifier).reload();
    return null;
  }
}

final foodScannerProvider = StateNotifierProvider<FoodScannerNotifier, FoodScannerState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  return FoodScannerNotifier(ref);
});
