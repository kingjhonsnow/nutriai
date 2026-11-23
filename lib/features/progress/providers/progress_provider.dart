import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/progress_entry.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/goals/providers/goal_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

class ProgressState {
  final List<ProgressEntry> entries;
  final double currentWeight;
  final double startWeight;
  final double weightChange;
  final String timeFrame; // '1W', '1M', '3M', 'All'

  /// Plain summary computed from the logged entries (not AI generated).
  final String? aiInsight;
  final bool isLoading;
  final String? errorMessage;

  const ProgressState({
    required this.entries,
    required this.currentWeight,
    required this.startWeight,
    required this.weightChange,
    this.timeFrame = '1M',
    this.aiInsight,
    this.isLoading = false,
    this.errorMessage,
  });

  ProgressState copyWith({
    List<ProgressEntry>? entries,
    double? currentWeight,
    double? startWeight,
    double? weightChange,
    String? timeFrame,
    String? aiInsight,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProgressState(
      entries: entries ?? this.entries,
      currentWeight: currentWeight ?? this.currentWeight,
      startWeight: startWeight ?? this.startWeight,
      weightChange: weightChange ?? this.weightChange,
      timeFrame: timeFrame ?? this.timeFrame,
      aiInsight: aiInsight ?? this.aiInsight,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProgressNotifier extends StateNotifier<ProgressState> {
  final Ref _ref;

  ProgressNotifier(this._ref, double profileWeight)
      : super(ProgressState(
          entries: const [],
          currentWeight: profileWeight,
          startWeight: profileWeight,
          weightChange: 0.0,
        )) {
    if (_ref.read(authProvider).isApproved) loadProgress();
  }

  Future<void> loadProgress() async {
    state = state.copyWith(isLoading: true);
    try {
      final entries = await _ref.read(databaseServiceProvider).getProgressEntries();
      if (!mounted) return;
      _apply(entries);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: friendlyError(e));
    }
  }

  void _apply(List<ProgressEntry> entries) {
    final profileWeight = _ref.read(profileProvider)?.weightKg ?? state.currentWeight;
    if (entries.isEmpty) {
      state = ProgressState(
        entries: const [],
        currentWeight: profileWeight,
        startWeight: profileWeight,
        weightChange: 0.0,
        timeFrame: state.timeFrame,
        aiInsight: 'Log your weight regularly (for example once a week) to see your trend here.',
      );
      return;
    }
    final start = entries.first.weightKg;
    final current = entries.last.weightKg;
    state = ProgressState(
      entries: entries,
      currentWeight: current,
      startWeight: start,
      weightChange: current - start,
      timeFrame: state.timeFrame,
      aiInsight: _summary(entries),
    );
  }

  /// Honest summary of the real data: average weekly change and how it
  /// compares with the goal's recommended rate.
  String _summary(List<ProgressEntry> entries) {
    if (entries.length < 2) {
      return 'First entry saved. Add another one in a few days to see your trend.';
    }
    final first = entries.first;
    final last = entries.last;
    final days = last.date.difference(first.date).inDays;
    if (days < 1) return 'Add entries on different days to see your weekly trend.';
    final perWeek = (last.weightKg - first.weightKg) / days * 7;
    final rate = perWeek.abs() < 0.05
        ? 'stable'
        : '${perWeek > 0 ? '+' : ''}${perWeek.toStringAsFixed(2)} kg per week';
    final goal = _ref.read(goalProvider);
    final target = goal?.weeklyWeightChangeKg;
    final targetText = target == null
        ? ''
        : ' Your goal (${goal!.displayName}) aims for about '
            '${target > 0 ? '+' : ''}${target.toStringAsFixed(2)} kg per week.';
    return 'Trend over the last $days days: $rate.$targetText';
  }

  void setTimeFrame(String tf) {
    state = state.copyWith(timeFrame: tf);
  }

  /// Saves an entry. Throws an [AppException] with a readable message on error.
  Future<void> addEntry(ProgressEntry entry) async {
    try {
      await _ref.read(databaseServiceProvider).addProgressEntry(entry);
    } catch (e) {
      throw AppException(friendlyError(e));
    }
    await loadProgress();
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  ref.watch(authProvider.select((s) => s.sessionKey));
  final weight = ref.read(profileProvider)?.weightKg ?? 0.0;
  return ProgressNotifier(ref, weight);
});
