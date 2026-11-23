import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/food_item.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

class FoodSearchState {
  final List<FoodItem> searchResults;
  final String searchQuery;
  final String selectedCategory;
  final List<FoodItem> favorites;
  final bool isOnlyFavorites;
  final String? errorMessage;

  const FoodSearchState({
    required this.searchResults,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.favorites = const [],
    this.isOnlyFavorites = false,
    this.errorMessage,
  });

  FoodSearchState copyWith({
    List<FoodItem>? searchResults,
    String? searchQuery,
    String? selectedCategory,
    List<FoodItem>? favorites,
    bool? isOnlyFavorites,
    String? errorMessage,
  }) {
    return FoodSearchState(
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      favorites: favorites ?? this.favorites,
      isOnlyFavorites: isOnlyFavorites ?? this.isOnlyFavorites,
      errorMessage: errorMessage,
    );
  }
}

class FoodSearchNotifier extends StateNotifier<FoodSearchState> {
  final Ref _ref;

  FoodSearchNotifier(this._ref) : super(const FoodSearchState(searchResults: [])) {
    loadAllFoods();
  }

  /// Shows the full list (also used to leave the favourites view).
  Future<void> loadAllFoods() async {
    final db = _ref.read(databaseServiceProvider);
    state = state.copyWith(
      searchResults: db.getAllFoods(),
      isOnlyFavorites: false,
      selectedCategory: 'All',
      searchQuery: '',
    );
    if (!_ref.read(authProvider).isApproved) return;
    try {
      await db.loadFavorites();
      if (!mounted) return;
      state = state.copyWith(searchResults: _currentResults(), favorites: db.getFavoriteFoods());
    } catch (e) {
      if (mounted) state = state.copyWith(errorMessage: friendlyError(e));
    }
  }

  List<FoodItem> _currentResults() {
    final db = _ref.read(databaseServiceProvider);
    if (state.isOnlyFavorites) return db.getFavoriteFoods();
    return db.searchFoods(
      state.searchQuery,
      category: state.selectedCategory == 'All' ? null : state.selectedCategory,
    );
  }

  void search(String query) {
    final db = _ref.read(databaseServiceProvider);
    final category = state.selectedCategory;
    final results = db.searchFoods(
      query,
      category: (category == 'All' || category == 'Favorites') ? null : category,
    );
    state = state.copyWith(
      searchQuery: query,
      searchResults: results,
      isOnlyFavorites: false,
      selectedCategory: category == 'Favorites' ? 'All' : category,
    );
  }

  void selectCategory(String category) {
    final db = _ref.read(databaseServiceProvider);
    final results = db.searchFoods(
      state.searchQuery,
      category: category == 'All' ? null : category,
    );
    state = state.copyWith(
      selectedCategory: category,
      searchResults: results,
      isOnlyFavorites: false,
    );
  }

  Future<void> toggleFavorite(String foodId) async {
    final db = _ref.read(databaseServiceProvider);
    try {
      await db.toggleFavoriteFood(foodId);
      if (!mounted) return;
      state = state.copyWith(searchResults: _currentResults(), favorites: db.getFavoriteFoods());
    } catch (e) {
      if (mounted) state = state.copyWith(errorMessage: friendlyError(e));
    }
  }

  void showFavoritesOnly() {
    final db = _ref.read(databaseServiceProvider);
    state = state.copyWith(
      searchResults: db.getFavoriteFoods(),
      isOnlyFavorites: true,
      selectedCategory: 'Favorites',
    );
  }
}

final foodSearchProvider = StateNotifierProvider<FoodSearchNotifier, FoodSearchState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  return FoodSearchNotifier(ref);
});
