-- ============================================================================
-- NutriAI security self-test (multi-user isolation + admin approval)
--
-- HOW TO USE: paste the whole file into Supabase > SQL Editor and click Run,
-- AFTER both migrations have been applied.
--
-- It creates 4 temporary test accounts, runs 16 checks and then ALWAYS ends
-- with an error message so that everything is rolled back (nothing is saved).
--
--   Success looks like:  "RLS SELF-TEST: ALL 16 CHECKS PASSED ..."
--   A problem looks like: "RLS SELF-TEST FAILED at check N: ..."
-- ============================================================================
DO $$
DECLARE
    admin_id  UUID := '00000000-0000-4000-8000-00000000a001';
    alice_id  UUID := '00000000-0000-4000-8000-00000000a002';
    bob_id    UUID := '00000000-0000-4000-8000-00000000a003';
    eve_id    UUID := '00000000-0000-4000-8000-00000000a004';
    n         INT;
    s         TEXT;
    passed    INT := 0;
BEGIN
    -- ---------- setup (as database owner) ----------
    INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
    VALUES
        (admin_id, 'rls.admin@nutriai.test', '{"full_name":"Test Admin"}', 'authenticated', 'authenticated'),
        (alice_id, 'rls.alice@nutriai.test', '{"full_name":"Alice"}', 'authenticated', 'authenticated'),
        (bob_id,   'rls.bob@nutriai.test',   '{"full_name":"Bob"}',   'authenticated', 'authenticated'),
        (eve_id,   'rls.eve@nutriai.test',   '{"full_name":"Eve"}',   'authenticated', 'authenticated');

    -- check 1: sign-up trigger created pending profiles
    SELECT COUNT(*) INTO n FROM public.profiles
    WHERE id IN (admin_id, alice_id, bob_id, eve_id) AND status = 'pending' AND NOT is_admin;
    IF n <> 4 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 1: expected 4 pending profiles, got %', n; END IF;
    passed := passed + 1;

    PERFORM set_config('request.jwt.claims', '', TRUE);
    UPDATE public.profiles SET is_admin = TRUE, status = 'approved' WHERE id = admin_id;

    -- ---------- act as Eve (pending) ----------
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', eve_id, 'role', 'authenticated')::TEXT, TRUE);

    -- check 2: pending user cannot write diary data
    BEGIN
        INSERT INTO public.food_logs (user_id, meal_type, serving_amount_g, calories, protein, carbs, fat, food_name)
        VALUES (eve_id, 'lunch', 100, 100, 1, 1, 1, 'test');
        RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 2: pending user could write food_logs';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    -- check 3: pending user cannot approve or promote herself
    UPDATE public.profiles SET status = 'approved', is_admin = TRUE, access_until = NULL WHERE id = eve_id;
    SELECT status INTO s FROM public.profiles WHERE id = eve_id;
    IF s <> 'pending' THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 3: user changed own status to %', s; END IF;
    passed := passed + 1;

    -- check 4: pending user cannot call admin functions
    BEGIN
        PERFORM public.admin_set_user_access(eve_id, 'approved');
        RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 4: non-admin could approve';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    -- check 5: pending user sees only her own profile
    SELECT COUNT(*) INTO n FROM public.profiles;
    IF n <> 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 5: pending user sees % profiles', n; END IF;
    passed := passed + 1;

    -- ---------- act as Admin ----------
    PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::TEXT, TRUE);

    -- check 6: admin sees all test profiles and approves Alice and Bob
    SELECT COUNT(*) INTO n FROM public.profiles WHERE id IN (admin_id, alice_id, bob_id, eve_id);
    IF n <> 4 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 6: admin sees % of 4 profiles', n; END IF;
    PERFORM public.admin_set_user_access(alice_id, 'approved');
    PERFORM public.admin_set_user_access(bob_id, 'approved');
    passed := passed + 1;

    -- ---------- act as Alice (approved) ----------
    PERFORM set_config('request.jwt.claims', json_build_object('sub', alice_id, 'role', 'authenticated')::TEXT, TRUE);
    INSERT INTO public.food_logs (user_id, meal_type, serving_amount_g, calories, protein, carbs, fat, food_name, log_date)
    VALUES (alice_id, 'breakfast', 120, 150, 10, 20, 3, 'Alice oats', CURRENT_DATE);
    INSERT INTO public.weight_history (user_id, weight_kg, recorded_date) VALUES (alice_id, 61.5, CURRENT_DATE);
    INSERT INTO public.daily_water (user_id, log_date, amount_ml) VALUES (alice_id, CURRENT_DATE, 500);

    -- check 7: approved user can read her own data
    SELECT COUNT(*) INTO n FROM public.food_logs;
    IF n <> 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 7: Alice sees % food logs (expected 1)', n; END IF;
    passed := passed + 1;

    -- check 8: approved user cannot write rows for someone else
    BEGIN
        INSERT INTO public.food_logs (user_id, meal_type, serving_amount_g, calories, protein, carbs, fat, food_name)
        VALUES (bob_id, 'lunch', 100, 100, 1, 1, 1, 'spoofed');
        RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 8: Alice could write a row for Bob';
    EXCEPTION WHEN insufficient_privilege THEN
        passed := passed + 1;
    END;

    -- ---------- act as Bob (approved) ----------
    PERFORM set_config('request.jwt.claims', json_build_object('sub', bob_id, 'role', 'authenticated')::TEXT, TRUE);
    INSERT INTO public.food_logs (user_id, meal_type, serving_amount_g, calories, protein, carbs, fat, food_name)
    VALUES (bob_id, 'dinner', 300, 450, 30, 40, 12, 'Bob couscous');

    -- check 9: Bob sees only his own rows, not Alice's
    SELECT COUNT(*) INTO n FROM public.food_logs;
    IF n <> 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 9: Bob sees % food logs (expected 1)', n; END IF;
    SELECT COUNT(*) INTO n FROM public.weight_history;
    IF n <> 0 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 9: Bob sees Alice weight rows'; END IF;
    passed := passed + 1;

    -- check 10: Bob cannot change or delete Alice's rows
    UPDATE public.food_logs SET calories = 9999 WHERE user_id = alice_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    DELETE FROM public.food_logs WHERE user_id = alice_id;
    IF n <> 0 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 10: Bob updated Alice rows'; END IF;
    passed := passed + 1;

    -- check 11: admin can READ users' diaries (activity view, migration 4)
    --           but can never change them
    PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::TEXT, TRUE);
    SELECT COUNT(*) INTO n FROM public.food_logs;
    IF n < 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 11: admin cannot read users'' diaries (is migration 20261127000004 applied?)'; END IF;
    UPDATE public.food_logs SET calories = 1;
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n <> 0 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 11: admin changed % diary rows of others', n; END IF;
    passed := passed + 1;

    -- check 12: revoking access cuts Alice off immediately
    PERFORM public.admin_set_user_access(alice_id, 'revoked');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', alice_id, 'role', 'authenticated')::TEXT, TRUE);
    SELECT COUNT(*) INTO n FROM public.food_logs;
    IF n <> 0 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 12: revoked user still sees % rows', n; END IF;
    passed := passed + 1;

    -- check 13: an expired access date also cuts access
    PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.admin_set_user_access(alice_id, 'approved', NOW() - INTERVAL '1 day');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', alice_id, 'role', 'authenticated')::TEXT, TRUE);
    SELECT COUNT(*) INTO n FROM public.food_logs;
    IF n <> 0 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 13: expired user still sees % rows', n; END IF;
    passed := passed + 1;

    -- check 14: admin can set a temporary password
    PERFORM set_config('request.jwt.claims', json_build_object('sub', admin_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.admin_set_password(bob_id, 'TempPass123');
    EXECUTE 'RESET ROLE';
    SELECT COUNT(*) INTO n FROM auth.users
    WHERE id = bob_id AND encrypted_password = extensions.crypt('TempPass123', encrypted_password);
    IF n <> 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 14: temporary password not stored'; END IF;
    passed := passed + 1;

    -- check 15: a user can delete their own account and all of its data
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', bob_id, 'role', 'authenticated')::TEXT, TRUE);
    PERFORM public.delete_my_account();
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', TRUE);
    SELECT COUNT(*) INTO n FROM public.food_logs WHERE user_id = bob_id;
    IF n <> 0 OR EXISTS (SELECT 1 FROM public.profiles WHERE id = bob_id) THEN
        RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 15: deleted account left data behind';
    END IF;
    passed := passed + 1;

    -- check 16: Alice's own data survived everything above
    SELECT COUNT(*) INTO n FROM public.food_logs WHERE user_id = alice_id;
    IF n <> 1 THEN RAISE EXCEPTION 'RLS SELF-TEST FAILED at check 16: Alice data count is %', n; END IF;
    passed := passed + 1;

    RAISE EXCEPTION 'RLS SELF-TEST: ALL % CHECKS PASSED. (Shown as an error on purpose so the test accounts are rolled back.)', passed;
END;
$$;
