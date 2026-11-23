-- ============================================================================
-- NutriAI: Data API access grants
-- Migration: 20261123000003_api_grants.sql
--
-- WHY: Supabase projects created since May 2026 no longer give the app roles
-- automatic access to new tables ("Automatically expose new tables" is off).
-- Without these grants the app gets:
--   permission denied for table profiles (code 42501)
--
-- WHAT IT DOES:
--   1. Lets signed-in users (role "authenticated") reach the app tables.
--      Row Level Security still decides WHICH rows each person can see:
--      only their own, and only after the admin approves them.
--   2. Gives nothing to "anon" (not signed in), so nobody can read data
--      without an account.
--   3. Creates the missing profile row for any account that signed up before
--      the database setup was run.
--
-- Safe to run more than once. It does not delete or change existing data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SCHEMA ACCESS
-- ----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. TABLES used by the app (all have Row Level Security enabled)
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.profiles,
    public.fitness_goals,
    public.nutrition_targets,
    public.food_categories,
    public.foods,
    public.recipes,
    public.recipe_ingredients,
    public.food_logs,
    public.daily_summaries,
    public.weight_history,
    public.body_measurements,
    public.water_logs,
    public.favorite_foods,
    public.ai_scan_history,
    public.daily_water,
    public.user_meal_plans,
    public.user_favorite_foods
TO authenticated, service_role;

-- Sequences (only matters for tables with SERIAL ids; harmless otherwise)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;

-- Not signed in = no table access at all
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- ----------------------------------------------------------------------------
-- 3. FUNCTIONS the app calls (repeated here so this file alone is enough)
-- ----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_approved() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_my_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_access(UUID, TEXT, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_password(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. BACKFILL: profile row for accounts created before the setup script ran
-- ----------------------------------------------------------------------------
INSERT INTO public.profiles (id, email, full_name, status)
SELECT
    u.id,
    COALESCE(u.email, ''),
    COALESCE(
        NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
        SPLIT_PART(COALESCE(u.email, ''), '@', 1)
    ),
    'pending'
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT DO NOTHING;
