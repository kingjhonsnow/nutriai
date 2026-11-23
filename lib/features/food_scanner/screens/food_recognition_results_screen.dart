import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/loading_indicator.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/core/services/ai_food_service.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/food_item.dart';
import 'package:nutri_ai/features/food_scanner/providers/food_scanner_provider.dart';

class FoodRecognitionResultsScreen extends ConsumerStatefulWidget {
  const FoodRecognitionResultsScreen({super.key});

  @override
  ConsumerState<FoodRecognitionResultsScreen> createState() =>
      _FoodRecognitionResultsScreenState();
}

class _FoodRecognitionResultsScreenState
    extends ConsumerState<FoodRecognitionResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(foodScannerProvider);

    if (scannerState.isScanning) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoadingIndicator(size: 50),
              const SizedBox(height: 24),
              Text(
                'AI Analyzing Meal...',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Detecting ingredients, volumetric portions & macros',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (scannerState.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(title: const Text('Analysis Failed')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Recognition Error',
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  scannerState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Try Again',
                  width: 160,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = scannerState.result;
    if (result == null || result.detectedItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(title: const Text('Analysis Results')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 60, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('No foods detected. Try another photo.'),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Try Again',
                width: 160,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('AI Meal Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Captured Image Display
                    if (scannerState.capturedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.memory(
                              scannerState.capturedImageBytes!,
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AI Analyzed',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Meal Type Selector Pills
                    Text(
                      'Log to Meal Type',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: MealType.values.map((type) {
                        final isSelected = scannerState.selectedMealType == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref.read(foodScannerProvider.notifier).setMealType(type);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceBorder,
                                ),
                              ),
                              child: Text(
                                type.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Total Computed Macro Banner
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Estimated Calories',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${result.totalCalories.round()} kcal',
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNutrientBadge('Protein', '${result.totalProtein.round()}g', AppColors.protein),
                              _buildNutrientBadge('Carbs', '${result.totalCarbs.round()}g', AppColors.carbs),
                              _buildNutrientBadge('Fat', '${result.totalFat.round()}g', AppColors.fat),
                              _buildNutrientBadge('Fiber', '${result.totalFiber.round()}g', AppColors.fiber),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (result.analysisNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                result.analysisNotes,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Detected Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detected Items (${result.detectedItems.length})',
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tap slider to adjust grams',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of editable detected foods
                    ...result.detectedItems.map((item) {
                      return _buildDetectedFoodCard(item);
                    }),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showFoodPicker(),
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                        label: const Text('Add a missing food'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Confirm & Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: CustomButton(
                text: 'Save Meal to Diary',
                icon: Icons.check_circle_rounded,
                isLoading: scannerState.isSaving,
                onPressed: () async {
                  final error = await ref.read(foodScannerProvider.notifier).saveMealToDiary();
                  if (!mounted) return;
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Meal saved to your diary.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.go('/diary');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Not saved: $error'), backgroundColor: AppColors.error),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedFoodCard(DetectedFoodItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(item.confidence * 100).round()}% match',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.calories.round()} kcal  •  P: ${item.protein.round()}g  C: ${item.carbs.round()}g  F: ${item.fat.round()}g',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _showFoodPicker(replaceItemId: item.id),
                      child: Text(
                        'Source: ${item.sourceLabel}  ·  Wrong food? Tap to change',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: item.source == 'ai_estimate' ? AppColors.warning : AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 20),
                onPressed: () {
                  ref.read(foodScannerProvider.notifier).removeItem(item.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Weight Gram Slider + Value Display
          Row(
            children: [
              Text(
                'Portion: ',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textTertiary),
              ),
              GestureDetector(
                onTap: () => _editGrams(item),
                child: Text(
                  '${item.estimatedWeightGrams.round()} g ✎',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceLight,
                    thumbColor: AppColors.primary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: item.estimatedWeightGrams.clamp(5.0, 1000.0),
                    min: 5.0,
                    max: 1000.0,
                    divisions: 199,
                    onChanged: (val) {
                      ref.read(foodScannerProvider.notifier).updateItemPortion(item.id, val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editGrams(DetectedFoodItem item) async {
    final controller = TextEditingController(text: item.estimatedWeightGrams.round().toString());
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Portion of ${item.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Grams', suffixText: 'g'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.').trim())),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value <= 0 || value > 5000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a portion between 1 and 5000 g.'), backgroundColor: AppColors.error),
      );
      return;
    }
    ref.read(foodScannerProvider.notifier).updateItemPortion(item.id, value);
  }

  /// Manual correction: pick a food from the built-in list to add it, or to
  /// replace a wrongly recognised item.
  void _showFoodPicker({String? replaceItemId}) {
    final db = ref.read(databaseServiceProvider);
    var query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final List<FoodItem> results = db.searchFoods(query).take(40).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: replaceItemId == null ? 'Search a food to add' : 'Search the correct food',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text('No food found'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final food = results[i];
                              return ListTile(
                                title: Text(food.name),
                                subtitle: Text('${food.caloriesPer100g.round()} kcal / 100 g · ${food.category}'),
                                onTap: () {
                                  final notifier = ref.read(foodScannerProvider.notifier);
                                  if (replaceItemId != null) {
                                    notifier.replaceItemFood(replaceItemId, food);
                                  } else {
                                    notifier.addManualFoodItem(food, food.defaultServingGrams);
                                  }
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
