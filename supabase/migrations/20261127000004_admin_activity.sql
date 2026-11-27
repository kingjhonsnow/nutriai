-- ============================================================================
-- NutriAI: admin activity tracking and read-only access to users' data
-- Migration: 20261127000004_admin_activity.sql
--
-- WHAT IT DOES:
--   1. app_sessions: one row each time a user opens the app (a "session").
--      A session continues while the app keeps pinging at least every
--      15 minutes; after a longer break the next open counts as a new one.
--   2. profiles.last_seen_at: when each user was last active.
--   3. track_app_activity(): the only way the app writes sessions.
--   4. The admin can READ (never change) every user's food logs, water,
--      weight, measurements, goals, targets, meal plan and AI scans.
--   5. admin_users_overview() and admin_user_daily_activity(): today's and
--      per-day usage numbers for the admin screen.
--
-- Safe to run more than once. Changes no existing data.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SESSIONS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_sessions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    platform TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_user_started
    ON public.app_sessions(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_sessions_user_last_seen
    ON public.app_sessions(user_id, last_seen_at DESC);

ALTER TABLE public.app_sessions ENABLE ROW LEVEL SECURITY;

-- Users may see their own sessions, the admin sees everyone's.
-- Nobody writes directly: only through track_app_activity().
DROP POLICY IF EXISTS app_sessions_select_own_or_admin ON public.app_sessions;
CREATE POLICY app_sessions_select_own_or_admin ON public.app_sessions
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

REVOKE ALL ON public.app_sessions FROM anon, authenticated;
GRANT SELECT ON public.app_sessions TO authenticated;
GRANT ALL ON public.app_sessions TO service_role;

-- ----------------------------------------------------------------------------
-- 2. LAST SEEN
-- ----------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- ----------------------------------------------------------------------------
-- 3. TRACKING FUNCTION (called by the app on open, on return, every 5 minutes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.track_app_activity(p_platform TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_session BIGINT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_uid) THEN
        RETURN;
    END IF;

    SELECT s.id INTO v_session
    FROM public.app_sessions s
    WHERE s.user_id = v_uid
      AND s.last_seen_at > NOW() - INTERVAL '15 minutes'
    ORDER BY s.last_seen_at DESC
    LIMIT 1;

    IF v_session IS NULL THEN
        INSERT INTO public.app_sessions (user_id, platform)
        VALUES (v_uid, LEFT(NULLIF(TRIM(p_platform), ''), 40));
    ELSE
        UPDATE public.app_sessions SET last_seen_at = NOW() WHERE id = v_session;
    END IF;

    UPDATE public.profiles SET last_seen_at = NOW() WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.track_app_activity(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.track_app_activity(TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. ADMIN CAN READ USERS' DATA (read only: the existing "_own_approved"
--    policies still allow changes only by the owner)
-- ----------------------------------------------------------------------------
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
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_admin_read', t);
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_admin())',
            t || '_admin_read', t
        );
    END LOOP;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. ADMIN NUMBERS
--    p_today: the admin's local date. p_utc_offset_minutes: the admin's
--    time zone offset (Tunisia = 60). Days are counted in that time zone.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_users_overview(
    p_today DATE,
    p_utc_offset_minutes INT DEFAULT 60
)
RETURNS TABLE (
    user_id UUID,
    opens_today INT,
    minutes_today INT,
    opens_7_days INT,
    active_days_7 INT,
    last_seen_at TIMESTAMPTZ,
    meals_today INT,
    calories_today NUMERIC,
    scans_today INT,
    water_today_ml INT,
    last_weight_kg NUMERIC,
    last_weight_date DATE
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_start TIMESTAMPTZ;
    v_end TIMESTAMPTZ;
    v_week_start TIMESTAMPTZ;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only the admin can see this.' USING ERRCODE = '42501';
    END IF;

    v_start := (p_today::TIMESTAMP - make_interval(mins => p_utc_offset_minutes)) AT TIME ZONE 'UTC';
    v_end := v_start + INTERVAL '1 day';
    v_week_start := v_start - INTERVAL '6 days';

    RETURN QUERY
    SELECT
        p.id,
        (SELECT COUNT(*)::INT FROM public.app_sessions s
          WHERE s.user_id = p.id AND s.started_at >= v_start AND s.started_at < v_end),
        (SELECT COALESCE(SUM(GREATEST(1, CEIL(EXTRACT(EPOCH FROM (s.last_seen_at - s.started_at)) / 60.0))), 0)::INT
           FROM public.app_sessions s
          WHERE s.user_id = p.id AND s.started_at >= v_start AND s.started_at < v_end),
        (SELECT COUNT(*)::INT FROM public.app_sessions s
          WHERE s.user_id = p.id AND s.started_at >= v_week_start AND s.started_at < v_end),
        (SELECT COUNT(DISTINCT ((s.started_at AT TIME ZONE 'UTC') + make_interval(mins => p_utc_offset_minutes))::DATE)::INT
           FROM public.app_sessions s
          WHERE s.user_id = p.id AND s.started_at >= v_week_start AND s.started_at < v_end),
        p.last_seen_at,
        (SELECT COUNT(*)::INT FROM public.food_logs f
          WHERE f.user_id = p.id AND f.log_date = p_today),
        (SELECT COALESCE(SUM(f.calories), 0)::NUMERIC FROM public.food_logs f
          WHERE f.user_id = p.id AND f.log_date = p_today),
        (SELECT COUNT(*)::INT FROM public.ai_scan_history a
          WHERE a.user_id = p.id AND a.scanned_at >= v_start AND a.scanned_at < v_end),
        (SELECT COALESCE(MAX(w.amount_ml), 0)::INT FROM public.daily_water w
          WHERE w.user_id = p.id AND w.log_date = p_today),
        lw.weight_kg::NUMERIC,
        lw.recorded_date
    FROM public.profiles p
    LEFT JOIN LATERAL (
        SELECT wh.weight_kg, wh.recorded_date
        FROM public.weight_history wh
        WHERE wh.user_id = p.id
        ORDER BY wh.recorded_date DESC
        LIMIT 1
    ) lw ON TRUE
    ORDER BY p.last_seen_at DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_user_daily_activity(
    p_user UUID,
    p_today DATE,
    p_utc_offset_minutes INT DEFAULT 60,
    p_days INT DEFAULT 14
)
RETURNS TABLE (
    day DATE,
    opens INT,
    minutes INT,
    meals INT,
    calories NUMERIC,
    water_ml INT,
    scans INT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only the admin can see this.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    WITH days AS (
        SELECT d::DATE AS day,
               (d::TIMESTAMP - make_interval(mins => p_utc_offset_minutes)) AT TIME ZONE 'UTC' AS day_start
        FROM generate_series(
            (p_today - (LEAST(GREATEST(p_days, 1), 90) - 1))::TIMESTAMP,
            p_today::TIMESTAMP,
            INTERVAL '1 day'
        ) AS d
    )
    SELECT
        dd.day,
        (SELECT COUNT(*)::INT FROM public.app_sessions s
          WHERE s.user_id = p_user AND s.started_at >= dd.day_start
            AND s.started_at < dd.day_start + INTERVAL '1 day'),
        (SELECT COALESCE(SUM(GREATEST(1, CEIL(EXTRACT(EPOCH FROM (s.last_seen_at - s.started_at)) / 60.0))), 0)::INT
           FROM public.app_sessions s
          WHERE s.user_id = p_user AND s.started_at >= dd.day_start
            AND s.started_at < dd.day_start + INTERVAL '1 day'),
        (SELECT COUNT(*)::INT FROM public.food_logs f
          WHERE f.user_id = p_user AND f.log_date = dd.day),
        (SELECT COALESCE(SUM(f.calories), 0)::NUMERIC FROM public.food_logs f
          WHERE f.user_id = p_user AND f.log_date = dd.day),
        (SELECT COALESCE(MAX(w.amount_ml), 0)::INT FROM public.daily_water w
          WHERE w.user_id = p_user AND w.log_date = dd.day),
        (SELECT COUNT(*)::INT FROM public.ai_scan_history a
          WHERE a.user_id = p_user AND a.scanned_at >= dd.day_start
            AND a.scanned_at < dd.day_start + INTERVAL '1 day')
    FROM days dd
    ORDER BY dd.day DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_users_overview(DATE, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_users_overview(DATE, INT) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_user_daily_activity(UUID, DATE, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_user_daily_activity(UUID, DATE, INT, INT) TO authenticated;
