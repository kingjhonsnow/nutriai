-- ============================================================================
-- NutriAI: COMPLETE DATABASE SETUP (paste this whole file into Supabase > SQL Editor > Run)
-- = the 3 files in supabase/migrations, in order:
--   20261122000001_production_schema.sql
--   20261123000002_private_access_and_fixes.sql
--   20261123000003_api_grants.sql
-- Safe to run again later; it does not delete data.
-- ============================================================================

-- ============================================================================
-- NutriAI Production PostgreSQL Schema
-- Migration: 20261122000001_production_schema.sql
-- Description: Complete 14-table schema with RLS, foreign keys, and indexes
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. PROFILES (Extends Supabase auth.users)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    age INT CHECK (age >= 10 AND age <= 120),
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    height_cm NUMERIC(5, 2) CHECK (height_cm > 50 AND height_cm < 300),
    current_weight_kg NUMERIC(5, 2) CHECK (current_weight_kg > 20 AND current_weight_kg < 500),
    target_weight_kg NUMERIC(5, 2),
    activity_level TEXT CHECK (activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extra_active')),
    training_frequency INT DEFAULT 3,
    body_fat_percentage NUMERIC(4, 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. FITNESS GOALS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fitness_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL CHECK (goal_type IN ('bulk', 'cut', 'maintain')),
    target_weight_rate_kg_week NUMERIC(4, 2) DEFAULT 0.25,
    surplus_deficit_calories INT DEFAULT 0,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 3. NUTRITION TARGETS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nutrition_targets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    daily_calories NUMERIC(6, 1) NOT NULL,
    protein_grams NUMERIC(5, 1) NOT NULL,
    carbs_grams NUMERIC(5, 1) NOT NULL,
    fat_grams NUMERIC(5, 1) NOT NULL,
    fiber_grams NUMERIC(5, 1) DEFAULT 30.0 NOT NULL,
    water_ml INT DEFAULT 2500 NOT NULL,
    bmr NUMERIC(6, 1),
    tdee NUMERIC(6, 1),
    bmi NUMERIC(4, 1),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 4. FOOD CATEGORIES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    icon TEXT,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 5. FOODS (Global Catalog + User Custom Foods)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.foods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    brand TEXT,
    category_id UUID REFERENCES public.food_categories(id) ON DELETE SET NULL,
    serving_size_g NUMERIC(6, 1) DEFAULT 100.0 NOT NULL,
    calories_per_100g NUMERIC(6, 1) NOT NULL,
    protein_per_100g NUMERIC(5, 2) NOT NULL,
    carbs_per_100g NUMERIC(5, 2) NOT NULL,
    fat_per_100g NUMERIC(5, 2) NOT NULL,
    fiber_per_100g NUMERIC(5, 2) DEFAULT 0.0 NOT NULL,
    sugar_per_100g NUMERIC(5, 2) DEFAULT 0.0 NOT NULL,
    is_tunisian BOOLEAN DEFAULT FALSE NOT NULL,
    is_custom BOOLEAN DEFAULT FALSE NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 6. RECIPES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    prep_time_min INT,
    cook_time_min INT,
    servings INT DEFAULT 1 NOT NULL,
    instructions TEXT,
    image_url TEXT,
    total_calories NUMERIC(6, 1) DEFAULT 0.0 NOT NULL,
    total_protein NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    total_carbs NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    total_fat NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    is_public BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 7. RECIPE INGREDIENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES public.foods(id) ON DELETE RESTRICT,
    amount_g NUMERIC(6, 1) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 8. FOOD LOGS (User Food Entries)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES public.foods(id) ON DELETE RESTRICT,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    serving_amount_g NUMERIC(6, 1) NOT NULL,
    -- Historical snapshot of nutritional values at log time
    calories NUMERIC(6, 1) NOT NULL,
    protein NUMERIC(5, 1) NOT NULL,
    carbs NUMERIC(5, 1) NOT NULL,
    fat NUMERIC(5, 1) NOT NULL,
    fiber NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 9. DAILY SUMMARIES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    total_calories NUMERIC(6, 1) DEFAULT 0.0 NOT NULL,
    total_protein NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    total_carbs NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    total_fat NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    total_fiber NUMERIC(5, 1) DEFAULT 0.0 NOT NULL,
    target_calories NUMERIC(6, 1) NOT NULL,
    water_consumed_ml INT DEFAULT 0 NOT NULL,
    is_completed BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id, log_date)
);

-- ----------------------------------------------------------------------------
-- 10. WEIGHT HISTORY
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.weight_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    weight_kg NUMERIC(5, 2) NOT NULL,
    recorded_date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id, recorded_date)
);

-- ----------------------------------------------------------------------------
-- 11. BODY MEASUREMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.body_measurements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    recorded_date DATE NOT NULL,
    chest_cm NUMERIC(5, 1),
    waist_cm NUMERIC(5, 1),
    hips_cm NUMERIC(5, 1),
    thighs_cm NUMERIC(5, 1),
    arms_cm NUMERIC(5, 1),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 12. WATER LOGS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.water_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount_ml INT NOT NULL CHECK (amount_ml > 0),
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 13. FAVORITE FOODS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.favorite_foods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE(user_id, food_id)
);

-- ----------------------------------------------------------------------------
-- 14. AI SCAN HISTORY
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_scan_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    image_url TEXT,
    detected_items JSONB NOT NULL,
    total_calories NUMERIC(6, 1) NOT NULL,
    total_protein NUMERIC(5, 1) NOT NULL,
    total_carbs NUMERIC(5, 1) NOT NULL,
    total_fat NUMERIC(5, 1) NOT NULL,
    confidence_score NUMERIC(4, 2),
    notes TEXT,
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- ============================================================================
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_food_logs_user_date ON public.food_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_daily_summaries_user_date ON public.daily_summaries(user_id, log_date);
CREATE INDEX IF NOT EXISTS idx_weight_history_user_date ON public.weight_history(user_id, recorded_date);
CREATE INDEX IF NOT EXISTS idx_water_logs_user_date ON public.water_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_foods_name ON public.foods(name);
CREATE INDEX IF NOT EXISTS idx_foods_category ON public.foods(category_id);
CREATE INDEX IF NOT EXISTS idx_foods_is_tunisian ON public.foods(is_tunisian);
CREATE INDEX IF NOT EXISTS idx_ai_scan_user_date ON public.ai_scan_history(user_id, scanned_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fitness_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.body_measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_scan_history ENABLE ROW LEVEL SECURITY;

-- 1. Profiles: Users can view and update their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. Fitness Goals
DROP POLICY IF EXISTS "Users can manage own fitness goals" ON public.fitness_goals;
CREATE POLICY "Users can manage own fitness goals" ON public.fitness_goals
    FOR ALL USING (auth.uid() = user_id);

-- 3. Nutrition Targets
DROP POLICY IF EXISTS "Users can manage own nutrition targets" ON public.nutrition_targets;
CREATE POLICY "Users can manage own nutrition targets" ON public.nutrition_targets
    FOR ALL USING (auth.uid() = user_id);

-- 4. Food Categories: Read-only for all users
DROP POLICY IF EXISTS "Anyone can view food categories" ON public.food_categories;
CREATE POLICY "Anyone can view food categories" ON public.food_categories
    FOR SELECT USING (true);

-- 5. Foods: Anyone can view public foods, users can create custom foods
DROP POLICY IF EXISTS "Anyone can view global and own custom foods" ON public.foods;
CREATE POLICY "Anyone can view global and own custom foods" ON public.foods
    FOR SELECT USING (is_custom = FALSE OR created_by = auth.uid());

DROP POLICY IF EXISTS "Users can create custom foods" ON public.foods;
CREATE POLICY "Users can create custom foods" ON public.foods
    FOR INSERT WITH CHECK (auth.uid() = created_by AND is_custom = TRUE);

DROP POLICY IF EXISTS "Users can update own custom foods" ON public.foods;
CREATE POLICY "Users can update own custom foods" ON public.foods
    FOR UPDATE USING (auth.uid() = created_by AND is_custom = TRUE);

DROP POLICY IF EXISTS "Users can delete own custom foods" ON public.foods;
CREATE POLICY "Users can delete own custom foods" ON public.foods
    FOR DELETE USING (auth.uid() = created_by AND is_custom = TRUE);

-- 6. Recipes
DROP POLICY IF EXISTS "Users can view own and public recipes" ON public.recipes;
CREATE POLICY "Users can view own and public recipes" ON public.recipes
    FOR SELECT USING (user_id = auth.uid() OR is_public = TRUE);

DROP POLICY IF EXISTS "Users can manage own recipes" ON public.recipes;
CREATE POLICY "Users can manage own recipes" ON public.recipes
    FOR ALL USING (auth.uid() = user_id);

-- 7. Recipe Ingredients
DROP POLICY IF EXISTS "Users can view recipe ingredients" ON public.recipe_ingredients;
CREATE POLICY "Users can view recipe ingredients" ON public.recipe_ingredients
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.recipes r
            WHERE r.id = recipe_id AND (r.user_id = auth.uid() OR r.is_public = TRUE)
        )
    );

DROP POLICY IF EXISTS "Users can manage own recipe ingredients" ON public.recipe_ingredients;
CREATE POLICY "Users can manage own recipe ingredients" ON public.recipe_ingredients
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.recipes r
            WHERE r.id = recipe_id AND r.user_id = auth.uid()
        )
    );

-- 8. Food Logs
DROP POLICY IF EXISTS "Users can manage own food logs" ON public.food_logs;
CREATE POLICY "Users can manage own food logs" ON public.food_logs
    FOR ALL USING (auth.uid() = user_id);

-- 9. Daily Summaries
DROP POLICY IF EXISTS "Users can manage own daily summaries" ON public.daily_summaries;
CREATE POLICY "Users can manage own daily summaries" ON public.daily_summaries
    FOR ALL USING (auth.uid() = user_id);

-- 10. Weight History
DROP POLICY IF EXISTS "Users can manage own weight history" ON public.weight_history;
CREATE POLICY "Users can manage own weight history" ON public.weight_history
    FOR ALL USING (auth.uid() = user_id);

-- 11. Body Measurements
DROP POLICY IF EXISTS "Users can manage own body measurements" ON public.body_measurements;
CREATE POLICY "Users can manage own body measurements" ON public.body_measurements
    FOR ALL USING (auth.uid() = user_id);

-- 12. Water Logs
DROP POLICY IF EXISTS "Users can manage own water logs" ON public.water_logs;
CREATE POLICY "Users can manage own water logs" ON public.water_logs
    FOR ALL USING (auth.uid() = user_id);

-- 13. Favorite Foods
DROP POLICY IF EXISTS "Users can manage own favorite foods" ON public.favorite_foods;
CREATE POLICY "Users can manage own favorite foods" ON public.favorite_foods
    FOR ALL USING (auth.uid() = user_id);

-- 14. AI Scan History
DROP POLICY IF EXISTS "Users can manage own AI scan history" ON public.ai_scan_history;
CREATE POLICY "Users can manage own AI scan history" ON public.ai_scan_history
    FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- AUTOMATIC PROFILE TRIGGER ON SUPABASE SIGNUP
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================================
-- INITIAL SEED DATA FOR FOOD CATEGORIES
-- ============================================================================
INSERT INTO public.food_categories (name, icon, display_order)
VALUES
    ('Fruits', 'apple', 1),
    ('Vegetables', 'carrot', 2),
    ('Meat & Poultry', 'drumstick', 3),
    ('Fish & Seafood', 'fish', 4),
    ('Dairy & Eggs', 'egg', 5),
    ('Grains & Cereals', 'wheat', 6),
    ('Tunisian Traditional', 'bowl-rice', 7),
    ('Snacks & Healthy Fats', 'cookie', 8)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- NutriAI migration 2: private access (admin approval), storage, data fixes
-- Safe to run more than once.
--
-- What it does
--   1. Adds account status (pending / approved / rejected / revoked), admin flag
--      and optional access end date to profiles. New sign-ups start as pending.
--   2. Only approved users (or the admin) can read or write any personal data.
--      This is enforced in the database (RLS), not only in the app.
--   3. Admin tools as database functions: approve / reject / revoke, set a
--      temporary password, delete a user.
--   4. Fixes food_logs so diary entries can actually be saved (food_id was
--      required but the app never had one) and stores the food name, macros
--      per 100 g and the local calendar date of each entry.
--   5. Adds tables for water intake, the saved meal plan and favourite foods.
--   6. Creates the "avatars" storage bucket with per-user folder permissions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PROFILES: access control columns
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS access_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS admin_note TEXT,
    ADD COLUMN IF NOT EXISTS avatar_path TEXT,
    ADD COLUMN IF NOT EXISTS training_experience TEXT;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_check;
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'revoked'));

CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

-- ----------------------------------------------------------------------------
-- 2. HELPER FUNCTIONS used by the security policies
--    SECURITY DEFINER so they can read profiles without recursive RLS checks.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.is_admin
    );
$$;

CREATE OR REPLACE FUNCTION public.is_approved()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid()
          AND (
                p.is_admin
             OR (p.status = 'approved' AND (p.access_until IS NULL OR p.access_until > NOW()))
          )
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_approved() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_approved() TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. PROFILE PROTECTION: normal users cannot change their own status, admin
--    flag, access date or email. SQL editor / service role (no auth.uid()) and
--    admins can.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_admin_fields()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
        NEW.id := OLD.id;
        NEW.email := OLD.email;
        NEW.status := OLD.status;
        NEW.is_admin := OLD.is_admin;
        NEW.access_until := OLD.access_until;
        NEW.approved_at := OLD.approved_at;
        NEW.admin_note := OLD.admin_note;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_admin_fields ON public.profiles;
CREATE TRIGGER protect_profile_admin_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_admin_fields();

-- ----------------------------------------------------------------------------
-- 4. SIGN-UP TRIGGER: every new account starts as pending
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, status)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(
            NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
            SPLIT_PART(COALESCE(NEW.email, ''), '@', 1)
        ),
        'pending'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Creates the caller's profile row if it is missing (for example an account
-- that existed before the trigger). Never changes an existing row.
CREATE OR REPLACE FUNCTION public.ensure_my_profile()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email TEXT;
    v_meta JSONB;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in' USING ERRCODE = '42501';
    END IF;

    SELECT u.email, u.raw_user_meta_data INTO v_email, v_meta
    FROM auth.users u WHERE u.id = auth.uid();

    INSERT INTO public.profiles (id, email, full_name, status)
    VALUES (
        auth.uid(),
        COALESCE(v_email, ''),
        COALESCE(NULLIF(TRIM(v_meta->>'full_name'), ''), SPLIT_PART(COALESCE(v_email, ''), '@', 1)),
        'pending'
    )
    ON CONFLICT (id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_my_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_my_profile() TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. PROFILES POLICIES
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.profiles;

CREATE POLICY "profiles_select_own_or_admin" ON public.profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid() OR public.is_admin());

CREATE POLICY "profiles_update_own_or_admin" ON public.profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_admin())
    WITH CHECK (id = auth.uid() OR public.is_admin());

-- ----------------------------------------------------------------------------
-- 6. FOOD LOGS: make diary entries storable
-- ----------------------------------------------------------------------------
ALTER TABLE public.food_logs ALTER COLUMN food_id DROP NOT NULL;

ALTER TABLE public.food_logs
    ADD COLUMN IF NOT EXISTS food_name TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS food_key TEXT,
    ADD COLUMN IF NOT EXISTS category TEXT,
    ADD COLUMN IF NOT EXISTS source TEXT,
    ADD COLUMN IF NOT EXISTS log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS calories_per_100g NUMERIC(7, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS protein_per_100g NUMERIC(6, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS carbs_per_100g NUMERIC(6, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fat_per_100g NUMERIC(6, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fiber_per_100g NUMERIC(6, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sugar_per_100g NUMERIC(6, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS sugar NUMERIC(6, 1) NOT NULL DEFAULT 0;

ALTER TABLE public.food_logs DROP CONSTRAINT IF EXISTS food_logs_serving_range;
ALTER TABLE public.food_logs
    ADD CONSTRAINT food_logs_serving_range
    CHECK (serving_amount_g > 0 AND serving_amount_g <= 5000);

CREATE INDEX IF NOT EXISTS idx_food_logs_user_log_date ON public.food_logs(user_id, log_date);

-- ----------------------------------------------------------------------------
-- 7. GOALS, WEIGHT, MEASUREMENTS
-- ----------------------------------------------------------------------------
ALTER TABLE public.fitness_goals ADD COLUMN IF NOT EXISTS details JSONB;
ALTER TABLE public.weight_history ADD COLUMN IF NOT EXISTS body_fat_percentage NUMERIC(4, 1);
CREATE UNIQUE INDEX IF NOT EXISTS body_measurements_user_date_key
    ON public.body_measurements(user_id, recorded_date);
CREATE INDEX IF NOT EXISTS idx_fitness_goals_user_active ON public.fitness_goals(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_nutrition_targets_user_active ON public.nutrition_targets(user_id, is_active);

-- ----------------------------------------------------------------------------
-- 8. NEW TABLES: water per day, saved meal plan, favourite foods
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_water (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    amount_ml INT NOT NULL DEFAULT 0 CHECK (amount_ml BETWEEN 0 AND 20000),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, log_date)
);

CREATE TABLE IF NOT EXISTS public.user_meal_plans (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_favorite_foods (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    food_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, food_key)
);

ALTER TABLE public.daily_water ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_favorite_foods ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 9. PERSONAL DATA POLICIES: own rows only, and only while approved
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can manage own fitness goals" ON public.fitness_goals;
DROP POLICY IF EXISTS "Users can manage own nutrition targets" ON public.nutrition_targets;
DROP POLICY IF EXISTS "Users can manage own food logs" ON public.food_logs;
DROP POLICY IF EXISTS "Users can manage own daily summaries" ON public.daily_summaries;
DROP POLICY IF EXISTS "Users can manage own weight history" ON public.weight_history;
DROP POLICY IF EXISTS "Users can manage own body measurements" ON public.body_measurements;
DROP POLICY IF EXISTS "Users can manage own water logs" ON public.water_logs;
DROP POLICY IF EXISTS "Users can manage own favorite foods" ON public.favorite_foods;
DROP POLICY IF EXISTS "Users can manage own AI scan history" ON public.ai_scan_history;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'fitness_goals', 'nutrition_targets', 'food_logs', 'daily_summaries',
        'weight_history', 'body_measurements', 'water_logs', 'favorite_foods',
        'ai_scan_history', 'daily_water', 'user_meal_plans', 'user_favorite_foods'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_own_approved', t);
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR ALL TO authenticated '
            'USING (user_id = auth.uid() AND public.is_approved()) '
            'WITH CHECK (user_id = auth.uid() AND public.is_approved())',
            t || '_own_approved', t
        );
    END LOOP;
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. ADMIN FUNCTIONS (only work for the admin account)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_user_access(
    target_user UUID,
    new_status TEXT,
    new_access_until TIMESTAMPTZ DEFAULT NULL,
    note TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only the admin can change access' USING ERRCODE = '42501';
    END IF;
    IF new_status NOT IN ('pending', 'approved', 'rejected', 'revoked') THEN
        RAISE EXCEPTION 'Invalid status: %', new_status;
    END IF;
    IF target_user = auth.uid() AND new_status <> 'approved' THEN
        RAISE EXCEPTION 'You cannot remove your own access';
    END IF;

    UPDATE public.profiles
    SET status = new_status,
        access_until = new_access_until,
        approved_at = CASE WHEN new_status = 'approved' THEN NOW() ELSE approved_at END,
        admin_note = COALESCE(note, admin_note),
        updated_at = NOW()
    WHERE id = target_user;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_password(target_user UUID, new_password TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only the admin can set passwords' USING ERRCODE = '42501';
    END IF;
    IF new_password IS NULL OR LENGTH(new_password) < 8 THEN
        RAISE EXCEPTION 'Password must be at least 8 characters';
    END IF;

    UPDATE auth.users
    SET encrypted_password = extensions.crypt(new_password, extensions.gen_salt('bf')),
        updated_at = NOW()
    WHERE id = target_user;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only the admin can delete users' USING ERRCODE = '42501';
    END IF;
    IF target_user = auth.uid() THEN
        RAISE EXCEPTION 'Use "Delete my account" to delete your own account';
    END IF;
    DELETE FROM auth.users WHERE id = target_user;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
END;
$$;

-- Lets any signed-in user delete their own account and all their data
-- (profile and every personal table cascade from auth.users).
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not signed in' USING ERRCODE = '42501';
    END IF;
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_access(UUID, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_password(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_delete_user(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_user_access(UUID, TEXT, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_password(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

-- ----------------------------------------------------------------------------
-- 11. STORAGE: avatars bucket, files live under "<user id>/..."
--     Public read (so the picture loads anywhere), write only into your own
--     folder and only while approved.
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
SET public = TRUE,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "avatars_select_own" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;

CREATE POLICY "avatars_select_own" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid()::TEXT));

CREATE POLICY "avatars_insert_own" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = (SELECT auth.uid()::TEXT)
        AND public.is_approved()
    );

CREATE POLICY "avatars_update_own" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid()::TEXT))
    WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid()::TEXT));

CREATE POLICY "avatars_delete_own" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid()::TEXT));

-- ----------------------------------------------------------------------------
-- 12. TABLE PRIVILEGES for the new tables (Supabase grants these by default,
--     repeated here so the script also works on a project with changed defaults)
-- ----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.daily_water TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_meal_plans TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_favorite_foods TO authenticated;

-- ============================================================================
-- AFTER RUNNING: make your own account the admin (run once, with your email):
--
--   UPDATE public.profiles SET is_admin = TRUE, status = 'approved'
--   WHERE email = 'your.email@example.com';
-- ============================================================================

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
