import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_ai/core/services/account_repository.dart';
import 'package:nutri_ai/core/services/ai_food_service.dart';
import 'package:nutri_ai/core/services/database_service.dart';
import 'package:nutri_ai/core/services/preferences_service.dart';
import 'package:nutri_ai/features/auth/providers/auth_provider.dart';

/// Overridden in main() with the real SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(ref.watch(sharedPreferencesProvider));
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(supabaseClientProvider));
});

final aiFoodServiceProvider = Provider<AIFoodService>((ref) {
  return AIFoodService(ref.watch(supabaseClientProvider));
});

/// A new instance per signed-in user, so nothing (like cached favourites) can
/// leak from one account to the next on the same device.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  return DatabaseService(ref.watch(supabaseClientProvider), userId);
});
