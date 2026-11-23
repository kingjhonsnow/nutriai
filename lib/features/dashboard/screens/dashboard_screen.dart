import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/calorie_ring.dart';
import 'package:nutri_ai/core/widgets/macro_progress_bar.dart';
import 'package:nutri_ai/core/widgets/section_header.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/dashboard/providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    ref.listen<DashboardState>(dashboardProvider, (prev, next) {
      final msg = next.errorMessage;
      if (msg != null && msg != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    });
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    final goal = ref.watch(goalProvider);

    final userName = profile?.name ?? auth.userName ?? 'Athlete';
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(dashboardProvider.notifier).refreshDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header with greeting and profile badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName 👋',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          now.toReadableDate(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.surfaceLight,
                          backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty
                              ? NetworkImage(auth.avatarUrl!)
                              : null,
                          child: (auth.avatarUrl == null || auth.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Goal status badge
                GestureDetector(
                  onTap: () => context.push('/nutrition-plan'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.track_changes_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              goal?.displayName ?? 'Muscle Gain / Bulking',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${dashboard.targetCalories} kcal',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textTertiary, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Central Calorie Ring Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CalorieRing(
                        consumedCalories: dashboard.consumedCalories,
                        targetCalories: dashboard.targetCalories,
                        size: 210,
                      ),
                      const SizedBox(height: 20),
                      // Three Macro Circles (Protein, Carbs, Fat)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          MacroCircularIndicator(
                            label: 'Protein',
                            consumed: dashboard.consumedProtein,
                            target: dashboard.targetProtein.toDouble(),
                            color: AppColors.protein,
                          ),
                          MacroCircularIndicator(
                            label: 'Carbs',
                            consumed: dashboard.consumedCarbs,
                            target: dashboard.targetCarbs.toDouble(),
                            color: AppColors.carbs,
                          ),
                          MacroCircularIndicator(
                            label: 'Fat',
                            consumed: dashboard.consumedFat,
                            target: dashboard.targetFat.toDouble(),
                            color: AppColors.fat,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Quick Actions
                SectionHeader(title: 'Quick Actions'),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionCard(
                        title: 'Scan Meal',
                        subtitle: 'AI Camera',
                        icon: Icons.camera_alt_rounded,
                        color: AppColors.primary,
                        onTap: () => context.push('/food-scanner'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionCard(
                        title: 'Search Food',
                        subtitle: 'Database',
                        icon: Icons.search_rounded,
                        color: AppColors.accent,
                        onTap: () => context.push('/food-search'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Water Consumption Tracker
                SectionHeader(
                  title: 'Water Hydration',
                  actionText: '${dashboard.todayLog.waterIntakeMl} / ${dashboard.targetWaterMl} ml',
                  onAction: () {},
                ),
                _buildWaterTracker(context, ref, dashboard.todayLog.waterIntakeMl),
                const SizedBox(height: 24),

                // 6. Today's Meals Summary
                SectionHeader(
                  title: "Today's Meals",
                  actionText: 'Full Diary',
                  onAction: () => context.go('/diary'),
                ),
                _buildMealCard(
                  context: context,
                  type: MealType.breakfast,
                  title: 'Breakfast',
                  meal: dashboard.todayLog.getMeal(MealType.breakfast),
                  icon: Icons.wb_twilight_rounded,
                ),
                const SizedBox(height: 12),
                _buildMealCard(
                  context: context,
                  type: MealType.lunch,
                  title: 'Lunch',
                  meal: dashboard.todayLog.getMeal(MealType.lunch),
                  icon: Icons.wb_sunny_rounded,
                ),
                const SizedBox(height: 12),
                _buildMealCard(
                  context: context,
                  type: MealType.dinner,
                  title: 'Dinner',
                  meal: dashboard.todayLog.getMeal(MealType.dinner),
                  icon: Icons.nightlight_round,
                ),
                const SizedBox(height: 12),
                _buildMealCard(
                  context: context,
                  type: MealType.snack,
                  title: 'Snacks',
                  meal: dashboard.todayLog.getMeal(MealType.snack),
                  icon: Icons.apple_rounded,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTracker(BuildContext context, WidgetRef ref, int waterMl) {
    final glasses = (waterMl / 250).clamp(0, 8).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(8, (index) {
              final isFilled = index < glasses;
              return GestureDetector(
                onTap: () {
                  if (isFilled && index == glasses - 1) {
                    ref.read(dashboardProvider.notifier).removeWaterGlass();
                  } else {
                    ref.read(dashboardProvider.notifier).addWaterGlass();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isFilled
                        ? AppColors.water
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: isFilled ? Colors.white : AppColors.textDisabled,
                    size: 18,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$glasses of 8 cups logged (250ml each)',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(dashboardProvider.notifier).addWaterGlass();
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add, size: 16, color: AppColors.water),
                label: Text(
                  'Add Cup',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.water,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required BuildContext context,
    required MealType type,
    required String title,
    required Meal? meal,
    required IconData icon,
  }) {
    final items = meal?.items ?? [];
    final cals = meal?.totalCalories.round() ?? 0;

    return Container(
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
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
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
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/food-search'),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.food.name} (${item.weightGrams.round()}g)',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'No food logged yet',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
