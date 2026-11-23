import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/core/utils/extensions.dart';
import 'package:nutri_ai/data/models/daily_log.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class DashboardState {
  final DailyLog todayLog;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;
  final int targetWaterMl;
  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    required this.todayLog,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    this.targetWaterMl = 2500,
    this.isLoading = false,
    this.errorMessage,
  });

  int get consumedCalories => todayLog.totalCalories.round();
  int get remainingCalories => (targetCalories - consumedCalories).clamp(0, 99999);
  double get consumedProtein => todayLog.totalProtein;
  double get consumedCarbs => todayLog.totalCarbs;
  double get consumedFat => todayLog.totalFat;

  DashboardState copyWith({
    DailyLog? todayLog,
    int? targetCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFat,
    int? targetWaterMl,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      todayLog: todayLog ?? this.todayLog,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;

  DashboardNotifier(this._ref, DashboardState initial) : super(initial) {
    if (_ref.read(authProvider).isApproved) refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    state = state.copyWith(isLoading: true);
    try {
      final log = await _ref.read(databaseServiceProvider).getDailyLog(DateTime.now());
      if (!mounted) return;
      state = state.copyWith(todayLog: log, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
    }
  }

  Future<void> addWaterGlass() => _changeWater(250);

  Future<void> removeWaterGlass() => _changeWater(-250);

  Future<void> _changeWater(int delta) async {
    try {
      final amount = await _ref.read(databaseServiceProvider).updateWaterIntake(DateTime.now(), delta);
      if (!mounted) return;
      state = state.copyWith(todayLog: state.todayLog.copyWith(waterIntakeMl: amount));
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: friendlyError(e));
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  final goal = ref.watch(goalProvider);
  final profile = ref.read(profileProvider);
  return DashboardNotifier(
    ref,
    DashboardState(
      todayLog: DailyLog.empty(DateTime.now().toDateString()),
      targetCalories: goal?.targetCalories ?? 2000,
      targetProtein: goal?.targetProtein ?? 120,
      targetCarbs: goal?.targetCarbs ?? 220,
      targetFat: goal?.targetFat ?? 65,
      targetWaterMl: profile != null ? NutritionCalculator.calculateWaterIntakeMl(profile.weightKg) : 2500,
    ),
  );
});
