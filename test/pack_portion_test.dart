import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_ai/core/services/ai_food_service.dart';

void main() {
  Map<String, dynamic> scan(Map<String, dynamic> item) => {
        'items': [item],
        'notes': 'test',
      };

  test('a scanned pack starts as the whole pack, with all pieces eaten', () {
    final result = AIFoodService.parseResult(scan({
      'name': 'Saida Tom Pouce biscuits',
      'estimated_weight_grams': 220,
      'confidence': 0.9,
      'source': 'package_label',
      'source_label': 'Nutrition label on the pack',
      'per_100g': {'calories': 470, 'protein': 6, 'carbs': 68, 'fat': 19, 'fiber': 2, 'sugar': 30},
      'is_packaged': true,
      'brand': 'Saida',
      'package_weight_g': 220,
      'pieces_per_package': 12,
      'piece_weight_g': 18.3,
    }));
    final item = result.detectedItems.single;

    expect(item.isPackaged, isTrue);
    expect(item.brand, 'Saida');
    expect(item.packageWeightG, 220);
    expect(item.piecesPerPackage, 12);
    expect(item.pieceCount, 12);
    expect(item.portionNote, '12 of 12 pieces');
    expect(item.effectivePieceWeightG, closeTo(18.33, 0.01));
    expect(item.calories, closeTo(1034, 1));
  });

  test('eating 3 of 12 pieces counts only those 3 pieces', () {
    final item = AIFoodService.parseResult(scan({
      'name': 'Saida Tom Pouce biscuits',
      'estimated_weight_grams': 220,
      'per_100g': {'calories': 470, 'protein': 6, 'carbs': 68, 'fat': 19},
      'is_packaged': true,
      'package_weight_g': 220,
      'pieces_per_package': 12,
    })).detectedItems.single;

    final three = item.copyWith(estimatedWeightGrams: 220 / 12 * 3, pieceCount: 3);
    expect(three.calories, closeTo(258.5, 0.5));
    expect(three.diaryName, 'Saida Tom Pouce biscuits (3 of 12 pieces)');

    final half = item.copyWith(estimatedWeightGrams: 110, clearPieceCount: true);
    expect(half.pieceCount, isNull);
    expect(half.portionNote, 'half a pack');
    expect(half.diaryName, 'Saida Tom Pouce biscuits (half a pack)');
  });

  test('a normal food keeps its name and the weight of one piece', () {
    final item = AIFoodService.parseResult(scan({
      'name': 'Dates',
      'estimated_weight_grams': 40,
      'per_100g': {'calories': 280},
      'piece_weight_g': 8,
    })).detectedItems.single;

    expect(item.isPackaged, isFalse);
    expect(item.pieceCount, isNull);
    expect(item.diaryName, 'Dates');
    expect(item.effectivePieceWeightG, 8);

    final five = item.copyWith(estimatedWeightGrams: 40, pieceCount: 5);
    expect(five.diaryName, 'Dates (5 pieces)');
  });

  test('a pack without known pieces does not invent a piece count', () {
    final item = AIFoodService.parseResult(scan({
      'name': 'Chips',
      'estimated_weight_grams': 45,
      'per_100g': {'calories': 536},
      'is_packaged': true,
      'package_weight_g': 45,
    })).detectedItems.single;

    expect(item.pieceCount, isNull);
    expect(item.effectivePieceWeightG, isNull);
    expect(item.portionNote, 'whole pack');
  });
}
