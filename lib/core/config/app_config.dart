/// Build-time configuration.
///
/// The Supabase project URL and the publishable key are PUBLIC by design
/// (the database security rules protect the data), so they are built in as
/// defaults: the app starts correctly with VS Code's Run button, plain
/// `flutter run`, or the .bat scripts.
/// `config.json` (via --dart-define-from-file) can still override them.
/// Never put AI keys or the secret / service role key here.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hkrtrompsrelhhwgqcfl.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_uMnaAChinZeoIIpeyqaeKg_v7vTT-Kw',
  );

  /// Name of the Supabase Edge Function that analyses meal photos.
  static const String analyzeFoodFunction = 'analyze-food';

  /// Storage bucket for profile photos.
  static const String avatarsBucket = 'avatars';

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('YOUR_') &&
      supabaseAnonKey.length > 20 &&
      !supabaseAnonKey.contains('YOUR_');
}
