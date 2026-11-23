import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/features/food_diary/providers/food_diary_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_button.dart';
import 'package:nutri_ai/core/widgets/macro_progress_bar.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/dashboard/providers/dashboard_provider.dart';
import 'package:nutri_ai/features/food_search/providers/food_search_provider.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  final String foodId;

  const FoodDetailsScreen({super.key, required this.foodId});

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  bool _saving = false;
  double _grams = 100.0;
  MealType _selectedMeal = MealType.lunch;
  final TextEditingController _gramsController = TextEditingController(text: '100');

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  void _updateGrams(double grams) {
    setState(() {
      _grams = grams;
      _gramsController.text = grams.round().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    ref.watch(foodSearchProvider); // rebuild when a favourite changes
    final food = db.getFoodById(widget.foodId);

    if (food == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(title: const Text('Food Details')),
        body: const Center(child: Text('Food not found')),
      );
    }

    final currentCalories = food.getCaloriesFor(_grams);
    final currentProtein = food.getProteinFor(_grams);
    final currentCarbs = food.getCarbsFor(_grams);
    final currentFat = food.getFatFor(_grams);
    final currentFiber = food.getFiberFor(_grams);
    final currentSugar = food.getSugarFor(_grams);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(food.name),
        actions: [
          IconButton(
            icon: Icon(
              food.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: food.isFavorite ? AppColors.error : Colors.white,
            ),
            onPressed: () {
              ref.read(foodSearchProvider.notifier).toggleFavorite(food.id);
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        food.category,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      food.name,
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Calorie & Nutrients Display Box
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Energy Value',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${currentCalories.round()} kcal',
                                style: AppTextStyles.displaySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          MacroLinearProgressBar(
                            label: 'Protein',
                            consumed: currentProtein,
                            target: currentProtein,
                            color: AppColors.protein,
                          ),
                          const SizedBox(height: 12),
                          MacroLinearProgressBar(
                            label: 'Carbohydrates',
                            consumed: currentCarbs,
                            target: currentCarbs,
                            color: AppColors.carbs,
                          ),
                          const SizedBox(height: 12),
                          MacroLinearProgressBar(
                            label: 'Fats',
                            consumed: currentFat,
                            target: currentFat,
                            color: AppColors.fat,
                          ),
                          if (currentFiber > 0 || currentSugar > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                if (currentFiber > 0)
                                  _buildMinorNutrient('Fiber', '${currentFiber.toStringAsFixed(1)}g', AppColors.fiber),
                                if (currentSugar > 0)
                                  _buildMinorNutrient('Sugar', '${currentSugar.toStringAsFixed(1)}g', AppColors.sugar),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Portion Size Gram Selector
                    Text(
                      'Portion Weight (Grams)',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.surfaceLight,
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: _grams.clamp(10.0, 500.0),
                              min: 10.0,
                              max: 500.0,
                              divisions: 98,
                              onChanged: (val) => _updateGrams(val),
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Text(
                            '${_grams.round()} g',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Gram Pills
                    Wrap(
                      spacing: 8,
                      children: [50.0, 100.0, 150.0, 200.0, 250.0].map((preset) {
                        final isSelected = _grams.round() == preset.round();
                        return ActionChip(
                          label: Text('${preset.round()}g'),
                          backgroundColor:
                              isSelected ? AppColors.primary : AppColors.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          onPressed: () => _updateGrams(preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Log to Meal Type Selector
                    Text(
                      'Add To Meal',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: MealType.values.map((type) {
                        final isSelected = _selectedMeal == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMeal = type),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
              child: CustomButton(
                text: 'Add to ${_selectedMeal.name.toUpperCase()} (${currentCalories.round()} kcal)',
                icon: Icons.add_circle_outline_rounded,
                isLoading: _saving,
                onPressed: () async {
                  setState(() => _saving = true);
                  try {
                    await db.addFoodToMeal(
                      date: DateTime.now(),
                      mealType: _selectedMeal,
                      food: food,
                      weightGrams: _grams,
                      source: 'food_list',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  ref.read(dashboardProvider.notifier).refreshDashboard();
                  ref.read(foodDiaryProvider.notifier).reload();
                  if (!mounted) return;
                  setState(() => _saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${food.name} to ${_selectedMeal.name}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinorNutrient(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
