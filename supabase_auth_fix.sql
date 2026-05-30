-- ============================================================
-- JIRETA LOANS & CREDIT CORP. 1996
-- SUPABASE AUTH SYNC FIX
-- 
-- PROBLEMA: Kapag nag-signup ang user sa Supabase Auth,
-- nila-lagay lang sa auth.users pero WALA sa public.users.
-- Kaya hindi ma-login — app naghahanap sa public.users
-- gamit ang auth_id pero wala doon.
--
-- SOLUSYON: 
--   1. Trigger na auto-insert sa public.users pagka-signup
--   2. RLS policies para ma-access ng bagong user ang sarili nila
-- ============================================================

-- ============================================================
-- STEP 1: Seed roles kung wala pa
-- ============================================================
INSERT INTO public.roles (name, display_name, description)
VALUES
  ('head_manager', 'Head Manager',  'Full system access'),
  ('employee',     'Employee',      'Loan processing and CI review'),
  ('rider',        'Rider',         'Collection and CI field agent'),
  ('lender',       'Lender',        'Borrower / loan applicant')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- STEP 2: Trigger function — runs AFTER INSERT on auth.users
--         Gumagawa ng public.users row gamit ang metadata
--         na pinasa sa signUp() call ng Flutter app.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- bypasses RLS, needed for auth schema access
SET search_path = public
AS $$
DECLARE
  v_role_id      UUID;
  v_role_name    TEXT;
  v_first_name   TEXT;
  v_last_name    TEXT;
  v_middle_name  TEXT;
  v_phone        TEXT;
  v_gender       TEXT;
  v_civil        TEXT;
  v_dob          TEXT;
BEGIN
  -- Pull metadata passed from Flutter signUp() call
  v_first_name  := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'),  ''), 'Unknown');
  v_last_name   := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'),   ''), 'Unknown');
  v_middle_name := NULLIF(TRIM(NEW.raw_user_meta_data->>'middle_name'), '');
  v_phone       := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'phone_number'), ''), '09000000000');
  v_gender      := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'gender'),       ''), 'prefer_not_to_say');
  v_civil       := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'civil_status'), ''), 'single');
  v_dob         := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'date_of_birth'),''), '2000-01-01');
  v_role_name   := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data->>'role'),         ''), 'lender');

  -- Get the matching role_id
  SELECT id INTO v_role_id
  FROM public.roles
  WHERE name::TEXT = v_role_name
  LIMIT 1;

  -- Fallback to 'lender' if role not found
  IF v_role_id IS NULL THEN
    SELECT id INTO v_role_id FROM public.roles WHERE name = 'lender' LIMIT 1;
  END IF;

  -- Insert the public.users row (ON CONFLICT = safe to re-run)
  INSERT INTO public.users (
    auth_id,
    role_id,
    email,
    first_name,
    middle_name,
    last_name,
    phone_number,
    gender,
    civil_status,
    date_of_birth,
    account_status,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    v_role_id,
    NEW.email,
    v_first_name,
    v_middle_name,
    v_last_name,
    v_phone,
    v_gender::gender_enum,
    v_civil::civil_status_enum,
    v_dob::DATE,
    'pending_verification',
    NOW(),
    NOW()
  )
  ON CONFLICT (auth_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists, then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

-- ============================================================
-- STEP 3: RLS POLICIES FIX
-- Allow INSERT for authenticated users (for registration flow)
-- ============================================================

-- Drop duplicate / conflicting policies first
DROP POLICY IF EXISTS "users_insert_own"       ON public.users;
DROP POLICY IF EXISTS "service_role_all_users" ON public.users;

-- Allow users to insert their own row (used as fallback in Flutter)
CREATE POLICY "users_insert_own"
  ON public.users
  FOR INSERT
  WITH CHECK (auth_id = auth.uid());

-- Allow service_role full access (Edge Functions, admin tasks)
CREATE POLICY "service_role_all_users"
  ON public.users
  FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================================
-- STEP 4: Helper function — called by Flutter after login
--         Returns the full user profile + role name in one call
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_current_user_profile()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT row_to_json(t) INTO result
  FROM (
    SELECT
      u.id,
      u.auth_id,
      u.email,
      u.first_name,
      u.middle_name,
      u.last_name,
      u.suffix,
      u.phone_number,
      u.gender,
      u.civil_status,
      u.date_of_birth,
      u.profile_picture_url,
      u.account_status,
      u.email_verified_at,
      u.last_login_at,
      u.created_at,
      r.name::TEXT   AS role_name,
      r.display_name AS role_display
    FROM public.users u
    JOIN public.roles r ON r.id = u.role_id
    WHERE u.auth_id = auth.uid()
    LIMIT 1
  ) t;

  RETURN result;
END;
$$;

-- ============================================================
-- STEP 5: update last_login_at on session
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_last_login()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET last_login_at = NOW(), updated_at = NOW()
  WHERE auth_id = auth.uid();
END;
$$;

-- ============================================================
-- STEP 6: Backfill — sync existing auth users that are missing
--         in public.users (run once for existing orphaned accounts)
-- ============================================================
-- NOTE: Run this manually if you already have accounts in Supabase Auth
-- that don't exist in public.users yet.
--
-- INSERT INTO public.users (auth_id, role_id, email, first_name, last_name,
--   phone_number, gender, civil_status, date_of_birth, account_status)
-- SELECT
--   au.id,
--   (SELECT id FROM public.roles WHERE name = 'lender' LIMIT 1),
--   au.email,
--   COALESCE(au.raw_user_meta_data->>'first_name', 'Unknown'),
--   COALESCE(au.raw_user_meta_data->>'last_name',  'Unknown'),
--   '09000000000',
--   'prefer_not_to_say',
--   'single',
--   '2000-01-01',
--   'pending_verification'
-- FROM auth.users au
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.users pu WHERE pu.auth_id = au.id
-- )
-- ON CONFLICT (auth_id) DO NOTHING;