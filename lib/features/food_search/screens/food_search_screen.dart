import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nutri_ai/core/constants/app_colors.dart';
import 'package:nutri_ai/core/constants/app_text_styles.dart';
import 'package:nutri_ai/core/widgets/custom_text_field.dart';
import 'package:nutri_ai/features/food_search/providers/food_search_provider.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Traditional Dishes',
    'Meat & Poultry',
    'Fish & Seafood',
    'Eggs & Dairy',
    'Grains & Carbs',
    'Fruits',
    'Vegetables',
    'Bread & Bakery',
    'Nuts & Seeds',
    'Fast Food',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(foodSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Food Database & Search'),
        actions: [
          IconButton(
            icon: Icon(
              searchState.isOnlyFavorites
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: searchState.isOnlyFavorites ? AppColors.error : Colors.white,
            ),
            tooltip: 'Favorites',
            onPressed: () {
              if (searchState.isOnlyFavorites) {
                ref.read(foodSearchProvider.notifier).loadAllFoods();
              } else {
                ref.read(foodSearchProvider.notifier).showFavoritesOnly();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: CustomTextField(
                controller: _searchController,
                hint: 'Search foods (e.g. Chicken, Couscous, Oats)...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(foodSearchProvider.notifier).search('');
                        },
                      )
                    : null,
                onChanged: (val) {
                  ref.read(foodSearchProvider.notifier).search(val);
                },
              ),
            ),

            // Horizontal Category Chips
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = searchState.selectedCategory == cat &&
                      !searchState.isOnlyFavorites;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(foodSearchProvider.notifier).selectCategory(cat);
                        }
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${searchState.searchResults.length} foods found',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    'Values per 100g',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Search Results List
            Expanded(
              child: searchState.searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 56, color: AppColors.textDisabled),
                          const SizedBox(height: 12),
                          Text(
                            'No foods found matching your query',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      itemCount: searchState.searchResults.length,
                      itemBuilder: (context, index) {
                        final food = searchState.searchResults[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(food.category).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(food.category),
                                color: _getCategoryColor(food.category),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              food.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${food.caloriesPer100g.round()} kcal  •  P: ${food.proteinPer100g}g  C: ${food.carbsPer100g}g  F: ${food.fatPer100g}g',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    food.isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: food.isFavorite
                                        ? AppColors.error
                                        : AppColors.textTertiary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    ref.read(foodSearchProvider.notifier).toggleFavorite(food.id);
                                  },
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: AppColors.textTertiary, size: 14),
                              ],
                            ),
                            onTap: () {
                              context.push('/food-details/${food.id}');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Meat & Poultry':
        return AppColors.protein;
      case 'Fish & Seafood':
        return AppColors.accent;
      case 'Traditional Dishes':
        return Colors.orange;
      case 'Fruits':
        return Colors.pinkAccent;
      case 'Vegetables':
        return AppColors.primary;
      case 'Grains & Carbs':
      case 'Bread & Bakery':
        return AppColors.carbs;
      case 'Eggs & Dairy':
        return Colors.amber;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Meat & Poultry':
        return Icons.kebab_dining_rounded;
      case 'Fish & Seafood':
        return Icons.set_meal_rounded;
      case 'Traditional Dishes':
        return Icons.soup_kitchen_rounded;
      case 'Fruits':
        return Icons.apple_rounded;
      case 'Vegetables':
        return Icons.eco_rounded;
      case 'Grains & Carbs':
      case 'Bread & Bakery':
        return Icons.bakery_dining_rounded;
      case 'Eggs & Dairy':
        return Icons.egg_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }
}
