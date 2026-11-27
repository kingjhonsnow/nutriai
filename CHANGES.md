# What changed (version 1.1.0)

## Update 2026-11-27: packaged products and counting by pieces

* The AI recognises packaged products (biscuits, chips, chocolate, yogurt...) and reads the
  brand, net weight, number of pieces and, when readable, the nutrition table on the pack
  (used before USDA). Countable foods get the weight of one piece.
* Results screen: "Packaged product: how much did you eat?" card with pack weight, pieces in
  the pack, pieces eaten (minus/plus) and quick shares (quarter, half, three quarters, whole
  pack). Only the eaten amount goes into the diary, named for example
  "Saida Tom Pouce biscuits (3 of 12 pieces)".
* Portion dialog: Grams or Pieces (pieces eaten x weight of one piece) for any food.
* Files: `supabase/functions/analyze-food/index.ts`, `lib/core/services/ai_food_service.dart`,
  `lib/features/food_scanner/providers/food_scanner_provider.dart`,
  `lib/features/food_scanner/screens/food_recognition_results_screen.dart`,
  `test/pack_portion_test.dart`.

## Update 2026-11-27: admin activity view, iPhone display fix, form messages

* Admin activity view: today's usage on every user card (opens, minutes, foods logged,
  scans, water, last seen), a "Used today" filter, a "Today" summary, and a detail screen
  per user with Activity (last 14 days, recent visits), Food (any day, by meal, vs targets),
  Progress (profile, goal, targets, weight, measurements) and Scans tabs. The admin can
  read users' data but never change it. New files: `lib/features/admin/data/admin_activity_repository.dart`,
  `lib/features/admin/screens/admin_user_detail_screen.dart`, `lib/core/services/activity_tracker.dart`.
* Database: `supabase/migrations/20261127000004_admin_activity.sql` (sessions table, tracking
  function, admin read access, usage numbers). Self-test: `supabase/tests/activity_check.sql`.
* iPhone: the page is locked at 100% zoom (Flutter 3.50 allowed zoom up to 5x, so Safari
  zoomed in on text fields and stayed zoomed, cutting the app off on the right).
* Forms show errors only after the first submit, then update live while typing; old messages
  are cleared on every submit.

## Update 2026-11-23: credit line and automatic publishing

* "Powered by Ahmed Ben Hassen" at the bottom of the launch screen (web loading screen and
  app splash), the sign in screen and the registration screen
  (`lib/core/widgets/powered_by.dart`, `web/index.html`, `splash_screen.dart`,
  `login_screen.dart`, `register_screen.dart`).
* `.github/workflows/build-web.yml`: GitHub builds the web app on every push to `main` and
  publishes it to the `web-build` branch for Cloudflare Pages (SETUP.md, step 7, option A).
* Removed the outdated `pubspec.lock` (it still listed old Firebase packages); a fresh one is
  created by `flutter pub get`.

## Fix 2026-11-23: "permission denied for table profiles"

New Supabase projects (since May 2026) no longer give the app automatic access to
tables. Added `supabase/migrations/20261123000003_api_grants.sql`, which grants signed-in
users access to the app tables (Row Level Security still limits each person to their own
rows), gives nothing to logged-out visitors, and creates any missing profile rows.
`supabase/SETUP_DATABASE.sql` now includes it.

Extract this archive into a **new, empty folder**. Do not copy it over the old project:
several old files were deleted on purpose (they would cause errors if they stayed).

## Fixed problems (from the audit)

| Problem | Fix |
|---|---|
| Supabase never connected; app silently used a fake local mode | Supabase is required; config comes from `config.json`; clear "Setup needed" screen otherwise |
| Any email/password logged in; all users shared id `local_user_1`; guest bypass | Real Supabase Auth only; fake login and guest button removed |
| All data stored on the phone under shared keys | Diary, water, weight, measurements, profile, goal, targets, favourites, meal plan stored per user in Supabase |
| Existing profiles recreated on a new device | Profile and goal loaded from Supabase after sign in |
| Diary inserts to Supabase always failed (`food_id` required) | `food_logs` fixed: food name, macros per 100 g, local calendar date; whole meal saved in one request |
| Logout kept the previous user's data in memory | Every data provider is rebuilt per user |
| Email confirmation ignored, reset password unfinished | Code-based verification and reset screens; admin can set temporary passwords |
| Account deletion could not work | `delete_my_account()` database function + "Delete my account" in Settings |
| Profile photos: no bucket, no permissions, fake "saved locally" message | `avatars` bucket with per-user folder rules; upload, change, remove; honest errors |
| Scanner needed your PC at 192.168.1.12; Gemini key in the source; AQ key rejected by Google endpoint | Supabase Edge Function `analyze-food`; keys are server secrets; Groq vision by default |
| Nutrition guessed by AI or loose name matching; invented default macros | USDA FoodData Central lookup + Tunisian dishes table; AI estimate only as clearly labelled fallback |
| Camera black after background; no fallback | Camera restarts on return; "Use camera app" and gallery fallback |
| Fake 4-week progress history and canned "AI analysis" | Removed; real entries only and an honest trend summary |
| Enum values did not match database rules | Mapping layer (`DbMapping`) + unit tests |
| Default Flutter icon, wrong names, no iOS permissions | New icon set (web + iOS), names, camera/photo permission texts, iOS 13 |
| Unused Firebase packages (would break iOS builds on Xcode 16) | Removed with other unused packages |
| Email check rejected valid addresses (`+`, long domains) | Validator fixed; password minimum 8 |

New: **private access with admin approval** (pending, approved, rejected, revoked,
access end date), enforced in the database.

## Files

**Added**
* `SETUP.md`, `CHANGES.md`, `config.example.json`
* `run_web.bat`, `build_web.bat`, `deploy_web.bat`, `check_code.bat`
* `lib/core/config/app_config.dart`
* `lib/core/services/account_repository.dart`, `lib/core/services/app_exception.dart`
* `lib/core/utils/image_utils.dart`
* `lib/data/models/account_info.dart`
* `lib/features/admin/providers/admin_provider.dart`, `lib/features/admin/screens/admin_screen.dart`
* `lib/features/auth/screens/pending_approval_screen.dart`, `lib/features/auth/screens/set_new_password_screen.dart`
* `supabase/SETUP_DATABASE.sql`, `supabase/migrations/20261123000002_private_access_and_fixes.sql`
* `supabase/tests/rls_check.sql`
* `supabase/functions/analyze-food/index.ts`
* `test/data_mapping_test.dart`
* `web/_headers`, `web/icons/apple-touch-icon.png`, `assets/icons/app_icon_1024.png`

**Rewritten or changed**
* App core: `lib/main.dart`, `lib/app/app.dart`, `lib/app/router.dart`, `pubspec.yaml`
* Services: `ai_food_service.dart`, `database_service.dart`, `preferences_service.dart`, `service_providers.dart`
* Auth: `auth_provider.dart`, `login_screen.dart`, `register_screen.dart`, `email_verification_screen.dart`, `forgot_password_screen.dart`
* State: dashboard, food diary, food search, goal, meal planner, profile, progress, food scanner providers
* Screens: dashboard, food details, food diary, scanner, scan results, goal selection, profile, profile setup, progress, add measurement, settings, splash
* `lib/features/food_scanner/camera/scanner_camera_web.dart`, `lib/core/utils/validators.dart`
* `supabase/migrations/20261122000001_production_schema.sql` (now safe to re-run)
* `web/index.html`, `web/manifest.json`, all web and iOS icons
* `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Flutter/AppFrameworkInfo.plist`
* `README.md`, `.gitignore`

**Removed**
* `server/` (old PC server, including the `.env` with the API key and the certificates)
* `lib/core/config/supabase_config.dart`, `lib/core/services/supabase_service.dart`
* `lib/features/auth/screens/auth_screen.dart` (unused screen with the guest bypass)
* Generated files (`.flutter-plugins*`, `ios/Flutter/Generated.xcconfig`, ...): Flutter recreates them
