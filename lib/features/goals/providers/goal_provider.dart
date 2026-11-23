import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/core/utils/calculations.dart';
import 'package:nutri_ai/data/models/fitness_goal.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';
import 'package:nutri_ai/features/profile/providers/profile_provider.dart';

/// The active fitness goal and nutrition targets, stored in Supabase
/// (`fitness_goals` and `nutrition_targets`).
class GoalNotifier extends StateNotifier<FitnessGoal?> {
  final Ref _ref;

  GoalNotifier(this._ref, FitnessGoal? initial) : super(initial);

  Future<void> selectGoal(FitnessGoalType type) async {
    final userId = _ref.read(authProvider).userId;
    if (userId == null) throw const AppException('Please sign in again.');
    final profile = _ref.read(profileProvider);
    if (profile == null) throw const AppException('Please complete your body profile first.');

    final goal = FitnessGoal.fromProfile(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      tdee: profile.tdee,
      weightKg: profile.weightKg,
    );
    await _ref.read(accountRepositoryProvider).saveGoal(userId, goal, profile);
    if (!mounted) return;
    state = goal;
    _ref.read(authProvider.notifier).cacheGoal(goal);
  }

  /// Recomputes the targets after weight, height or age changed.
  Future<void> recalculate() async {
    final current = state;
    if (current == null) return;
    await selectGoal(current.type);
  }
}

final goalProvider = StateNotifierProvider<GoalNotifier, FitnessGoal?>((ref) {
  final sessionKey = ref.watch(authProvider.select((s) => s.sessionKey));
  final initial = sessionKey == null ? null : ref.read(authProvider).goal;
  return GoalNotifier(ref, initial);
});
