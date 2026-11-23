import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutri_ai/core/services/app_exception.dart';
import 'package:nutri_ai/core/services/service_providers.dart';
import 'package:nutri_ai/data/models/user_profile.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// The signed-in user's body profile, stored in the Supabase `profiles` row.
class ProfileNotifier extends StateNotifier<UserProfile?> {
  final Ref _ref;

  ProfileNotifier(this._ref, UserProfile? initial) : super(initial);

  /// Saves to the cloud first; the local state only changes if that worked.
  Future<void> saveProfile(UserProfile profile) async {
    final auth = _ref.read(authProvider);
    final userId = auth.userId;
    if (userId == null) throw const AppException('Please sign in again.');

    final toSave = profile.copyWith(id: userId, email: auth.userEmail ?? profile.email);
    await _ref.read(accountRepositoryProvider).saveBodyProfile(userId, toSave);
    if (!mounted) return;
    state = toSave;
    _ref.read(authProvider.notifier).cacheBodyProfile(toSave);
  }

  Future<void> updateProfile({
    String? name,
    double? weightKg,
    double? heightCm,
    int? age,
    double? bodyFatPercentage,
    int? weeklyWorkoutFrequency,
  }) async {
    final current = state;
    if (current == null) return;
    await saveProfile(current.copyWith(
      name: name,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      bodyFatPercentage: bodyFatPercentage,
      weeklyWorkoutFrequency: weeklyWorkoutFrequency,
    ));
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) {
  final sessionKey = ref.watch(authProvider.select((s) => s.sessionKey));
  final initial = sessionKey == null ? null : ref.read(authProvider).bodyProfile;
  return ProfileNotifier(ref, initial);
});
