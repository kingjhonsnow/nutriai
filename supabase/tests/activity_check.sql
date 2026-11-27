-- ============================================================================
-- NutriAI activity tracking self-test (run AFTER migration 20261127000004)
--
-- Paste into Supabase > SQL Editor and click Run. It creates temporary test
-- accounts, runs the checks and ALWAYS ends with an error message so that
-- everything is rolled back (nothing is saved).
--
--   Success looks like:  "ACTIVITY SELF-TEST: ALL 12 CHECKS PASSED ..."
--   A problem looks like: "ACTIVITY SELF-TEST FAILED at check N: ..."
-- ============================================================================
DO $$
DECLARE
    admin_id UUID := '00000000-0000-4000-8000-00000000b001';
    alice_id UUID := '00000000-0000-4000-8000-00000000b002';
    bob_id   UUID := '00000000-0000-4000-8000-00000000b003';
    v_today  DATE := ((NOW() AT TIME ZONE 'UTC') + INTERVAL '60 minutes')::DATE;
    n        INT;
    num      NUMERIC;
    passed   INT := 0;
BEGIN
    -- ---------- setup (as database owner) ----------
    INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
    VALUES
        (admin_id, 'act.admin@nutriai.test', '{"full_name":"Act Admin"}', 'authenticated', 'authenticated'),
        (alice_id, 'act.alice@nutriai.test', '{"full_name":"Act Alice"}', 'authenticated', 'authenticated'),
        (bob_id,   'act.bob@nutriai.test',   '{"full_name":"Act Bob"}',   'authenticated', 'authenticated');
    PERFORM set_config('request.jwt.claims', '', TRUE);
    UPDATE public.profiles SET is_admin = TRUE, status = 'approved' WHERE id = admin_id;
    UPDATE public.profiles SET status = 'approved' WHERE id IN (alice_id, bob_id);

    -- ---------- Alice opens the app ----------
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', alice_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.track_app_activity('web-iOS');

    -- check 1: first open creates one session
    SELECT COUNT(*) INTO n FROM public.app_sessions WHERE user_id = alice_id;
    IF n <> 1 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 1: expected 1 session, got %', n; END IF;
    passed := passed + 1;

    -- check 2: pings within 15 minutes extend the same session
    PERFORM public.track_app_activity('web-iOS');
    PERFORM public.track_app_activity('web-iOS');
    SELECT COUNT(*) INTO n FROM public.app_sessions WHERE user_id = alice_id;
    IF n <> 1 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 2: pings created % sessions', n; END IF;
    passed := passed + 1;

    -- check 3: users cannot write sessions directly
    BEGIN
        INSERT INTO public.app_sessions (user_id) VALUES (alice_id);
        RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 3: direct insert was allowed';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    -- Alice logs a meal
    INSERT INTO public.food_logs (user_id, meal_type, serving_amount_g, calories, protein, carbs, fat, food_name, log_date)
    VALUES (alice_id, 'lunch', 200, 420, 30, 40, 12, 'Act couscous', v_today);

    -- check 4: Alice cannot use the admin numbers
    BEGIN
        PERFORM * FROM public.admin_users_overview(v_today, 60);
        RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 4: non-admin could read the overview';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    -- ---------- a break of more than 15 minutes, then Alice opens again ----------
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', TRUE);
    UPDATE public.app_sessions
       SET started_at = NOW() - INTERVAL '40 minutes', last_seen_at = NOW() - INTERVAL '30 minutes'
     WHERE user_id = alice_id;

    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', alice_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.track_app_activity('web-iOS');

    -- check 5: the return after a break counts as a second open
    SELECT COUNT(*) INTO n FROM public.app_sessions WHERE user_id = alice_id;
    IF n <> 2 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 5: expected 2 sessions, got %', n; END IF;
    passed := passed + 1;

    -- ---------- Bob ----------
    PERFORM set_config('request.jwt.claims', json_build_object('sub', bob_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.track_app_activity('web-android');

    -- check 6: Bob sees only his own sessions
    SELECT COUNT(*) INTO n FROM public.app_sessions WHERE user_id = alice_id;
    IF n <> 0 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 6: Bob sees % of Alice''s sessions', n; END IF;
    passed := passed + 1;

    -- check 7: Bob cannot read Alice's meals
    SELECT COUNT(*) INTO n FROM public.food_logs WHERE user_id = alice_id;
    IF n <> 0 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 7: Bob sees Alice''s meals'; END IF;
    passed := passed + 1;

    -- ---------- admin ----------
    PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::TEXT, TRUE);

    -- check 8: overview shows Alice opened the app twice today, with her meal
    SELECT o.opens_today, o.calories_today INTO n, num
    FROM public.admin_users_overview(v_today, 60) o WHERE o.user_id = alice_id;
    IF n IS DISTINCT FROM 2 OR num IS DISTINCT FROM 420 THEN
        RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 8: opens_today=%, calories_today=%', n, num;
    END IF;
    passed := passed + 1;

    -- check 9: per-day history has 14 days and today's opens
    SELECT COUNT(*) INTO n FROM public.admin_user_daily_activity(alice_id, v_today, 60, 14);
    IF n <> 14 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 9: expected 14 days, got %', n; END IF;
    SELECT d.opens INTO n FROM public.admin_user_daily_activity(alice_id, v_today, 60, 14) d WHERE d.day = v_today;
    IF n IS DISTINCT FROM 2 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 9: today opens=%', n; END IF;
    passed := passed + 1;

    -- check 10: admin can read Alice's meals and sessions
    SELECT COUNT(*) INTO n FROM public.food_logs WHERE user_id = alice_id;
    IF n <> 1 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 10: admin sees % meals', n; END IF;
    SELECT COUNT(*) INTO n FROM public.app_sessions WHERE user_id = alice_id;
    IF n <> 2 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 10: admin sees % sessions', n; END IF;
    passed := passed + 1;

    -- check 11: admin access is read only
    UPDATE public.food_logs SET calories = 1 WHERE user_id = alice_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 11: admin changed % meals', n; END IF;
    DELETE FROM public.food_logs WHERE user_id = alice_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 11: admin deleted % meals', n; END IF;
    passed := passed + 1;

    -- check 12: not signed in = no tracking possible
    EXECUTE 'RESET ROLE';
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM set_config('request.jwt.claims', '', TRUE);
    BEGIN
        PERFORM public.track_app_activity('x');
        RAISE EXCEPTION 'ACTIVITY SELF-TEST FAILED at check 12: anon could call tracking';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    EXECUTE 'RESET ROLE';
    RAISE EXCEPTION 'ACTIVITY SELF-TEST: ALL % CHECKS PASSED. (Shown as an error on purpose so the test accounts are rolled back.)', passed;
END;
$$;
