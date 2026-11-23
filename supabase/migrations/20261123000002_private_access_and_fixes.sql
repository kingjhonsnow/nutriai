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
