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
