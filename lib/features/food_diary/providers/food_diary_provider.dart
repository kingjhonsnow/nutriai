import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/data/models/daily_log.dart';
import 'package:nutri_ai/data/models/meal.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/dashboard/providers/dashboard_provider.dart';

class FoodDiaryState {
  final DateTime selectedDate;
  final DailyLog dailyLog;
  final bool isLoading;
  final String? errorMessage;

  const FoodDiaryState({
    required this.selectedDate,
    required this.dailyLog,
    this.isLoading = false,
    this.errorMessage,
  });

  FoodDiaryState copyWith({
    DateTime? selectedDate,
    DailyLog? dailyLog,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FoodDiaryState(
      selectedDate: selectedDate ?? this.selectedDate,
      dailyLog: dailyLog ?? this.dailyLog,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class FoodDiaryNotifier extends StateNotifier<FoodDiaryState> {
  final Ref _ref;
  int _requestId = 0;

  FoodDiaryNotifier(this._ref)
      : super(
          FoodDiaryState(
            selectedDate: DateTime.now(),
            dailyLog: DailyLog.empty(DateTime.now().toDateString()),
          ),
        ) {
    if (_ref.read(authProvider).isApproved) loadLogForDate(DateTime.now());
  }

  Future<void> loadLogForDate(DateTime date) async {
    final request = ++_requestId;
    state = state.copyWith(
      selectedDate: date,
      dailyLog: date.isSameDay(state.selectedDate) ? state.dailyLog : DailyLog.empty(date.toDateString()),
      isLoading: true,
    );
    try {
      final log = await _ref.read(databaseServiceProvider).getDailyLog(date);
      if (!mounted || request != _requestId) return;
      state = state.copyWith(dailyLog: log, isLoading: false);
    } catch (e) {
      if (!mounted || request != _requestId) return;
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
    }
  }

  Future<void> reload() => loadLogForDate(state.selectedDate);

  void nextDay() => loadLogForDate(state.selectedDate.add(const Duration(days: 1)));

  void previousDay() => loadLogForDate(state.selectedDate.subtract(const Duration(days: 1)));

  Future<void> removeFoodEntry(MealType type, String entryId) async {
    try {
      await _ref.read(databaseServiceProvider).removeFoodFromMeal(entryId);
    } catch (e) {
      if (mounted) state = state.copyWith(errorMessage: friendlyError(e));
      return;
    }
    await reload();
    _ref.read(dashboardProvider.notifier).refreshDashboard();
  }
}

final foodDiaryProvider = StateNotifierProvider<FoodDiaryNotifier, FoodDiaryState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  return FoodDiaryNotifier(ref);
});
