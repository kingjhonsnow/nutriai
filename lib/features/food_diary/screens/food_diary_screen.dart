import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/food_diary/providers/food_diary_provider.dart';

class FoodDiaryScreen extends ConsumerWidget {
  const FoodDiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(foodDiaryProvider);
    ref.listen<FoodDiaryState>(foodDiaryProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    });
    final log = diary.dailyLog;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Food Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: diary.selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                ref.read(foodDiaryProvider.notifier).loadLogForDate(picked);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Switcher Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.backgroundMedium,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () => ref.read(foodDiaryProvider.notifier).previousDay(),
                  ),
                  Text(
                    diary.selectedDate.isSameDay(DateTime.now())
                        ? 'Today, ${diary.selectedDate.toReadableDate()}'
                        : diary.selectedDate.toReadableDate(),
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () => ref.read(foodDiaryProvider.notifier).nextDay(),
                  ),
                ],
              ),
            ),

            // Daily Totals Sticky Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDailyTotalItem(
                    label: 'Calories',
                    value: '${log.totalCalories.round()} kcal',
                    color: AppColors.primary,
                  ),
                  _buildDailyTotalItem(
                    label: 'Protein',
                    value: '${log.totalProtein.round()}g',
                    color: AppColors.protein,
                  ),
                  _buildDailyTotalItem(
                    label: 'Carbs',
                    value: '${log.totalCarbs.round()}g',
                    color: AppColors.carbs,
                  ),
                  _buildDailyTotalItem(
                    label: 'Fat',
                    value: '${log.totalFat.round()}g',
                    color: AppColors.fat,
                  ),
                ],
              ),
            ),

            // Meal Sections List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  _buildDiaryMealSection(
                    context: context,
                    ref: ref,
                    type: MealType.breakfast,
                    title: 'Breakfast',
                    icon: Icons.wb_twilight_rounded,
                    meal: log.getMeal(MealType.breakfast),
                  ),
                  const SizedBox(height: 16),
                  _buildDiaryMealSection(
                    context: context,
                    ref: ref,
                    type: MealType.lunch,
                    title: 'Lunch',
                    icon: Icons.wb_sunny_rounded,
                    meal: log.getMeal(MealType.lunch),
                  ),
                  const SizedBox(height: 16),
                  _buildDiaryMealSection(
                    context: context,
                    ref: ref,
                    type: MealType.dinner,
                    title: 'Dinner',
                    icon: Icons.nightlight_round,
                    meal: log.getMeal(MealType.dinner),
                  ),
                  const SizedBox(height: 16),
                  _buildDiaryMealSection(
                    context: context,
                    ref: ref,
                    type: MealType.snack,
                    title: 'Snacks',
                    icon: Icons.apple_rounded,
                    meal: log.getMeal(MealType.snack),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Food', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => context.push('/food-search'),
      ),
    );
  }

  Widget _buildDailyTotalItem({
    required String label,
    required String value,
    required Color color,
  }) {
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

  Widget _buildDiaryMealSection({
    required BuildContext context,
    required WidgetRef ref,
    required MealType type,
    required String title,
    required IconData icon,
    required Meal? meal,
  }) {
    final items = meal?.items ?? [];
    final cals = meal?.totalCalories.round() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          // Meal Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '$cals kcal',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: AppColors.primary, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => context.push('/food-search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = items[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    entry.food.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.weightGrams.round()}g  •  P: ${entry.protein.round()}g  C: ${entry.carbs.round()}g  F: ${entry.fat.round()}g',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.calories.round()} kcal',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textTertiary),
                        onPressed: () {
                          ref
                              .read(foodDiaryProvider.notifier)
                              .removeFoodEntry(type, entry.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
