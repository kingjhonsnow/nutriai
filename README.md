# NutriAI: private AI nutrition and fitness tracker

Flutter app delivered as a **web app that installs on the iPhone home screen** (and runs in
any browser). Access is private: people sign up with your link and can only use the app
after you approve them in the in-app Admin screen.

**Start here: [SETUP.md](SETUP.md)** (step by step, all free, no card).
What changed compared to the previous version: [CHANGES.md](CHANGES.md).

## Features

* Accounts with Supabase Auth (sessions stay signed in until you sign out)
* Admin approval: approve, reject, revoke, access end date, temporary password, delete user
* Profile photo: camera or gallery, change, remove (stored in Supabase Storage)
* AI meal scanner: live camera, phone camera app or gallery, all through one pipeline:
  Groq vision AI recognises every food and portion, nutrition per 100 g from USDA
  FoodData Central or the built-in Tunisian dishes table, manual corrections
* Food diary, water, weight and body measurements, goals and nutrition targets,
  meal plan: all stored per user in Supabase PostgreSQL with row level security

## Architecture

```
Flutter app (web / iOS)
  ├─ Supabase Auth ........ sign up, sign in, sessions
  ├─ Supabase Postgres .... profiles, food_logs, weight_history, ... (RLS: own rows + approved)
  ├─ Supabase Storage ..... avatars/<user id>/avatar_<time>.jpg
  └─ Edge Function analyze-food (keys stay on the server)
        ├─ Groq vision model (default) or Gemini (optional)
        └─ USDA FoodData Central + Tunisian dishes table
```

## Folders

* `lib/` app code (`core/services` = data layer, `features/*` = screens and state)
* `supabase/SETUP_DATABASE.sql` complete database setup (paste into the SQL editor)
* `supabase/migrations/` the same SQL as three migrations (for the Supabase CLI)
* `supabase/tests/rls_check.sql` security self-test (16 checks)
* `supabase/functions/analyze-food/index.ts` AI server function
* `web/` web app shell, icons, manifest
* `*.bat` Windows helpers: `check_code`, `run_web`, `build_web`, `deploy_web`
