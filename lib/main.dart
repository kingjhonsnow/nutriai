import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutri_ai/app/app.dart';
import 'package:nutri_ai/core/config/app_config.dart';
import 'package:nutri_ai/core/services/service_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // The app needs its online backend; there is no hidden offline/demo mode.
  if (!AppConfig.isConfigured) {
    runApp(const ConfigErrorApp(
      message: 'The app is missing its Supabase settings.\n\n'
          'Run it with the provided scripts (run_web.bat / build_web.bat), which pass '
          'config.json with SUPABASE_URL and SUPABASE_ANON_KEY.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    runApp(ConfigErrorApp(message: 'Could not start the connection to the server.\n\n$e'));
    return;
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const NutriAIApp(),
    ),
  );
}
