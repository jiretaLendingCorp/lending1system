-- Run this in your Supabase SQL Editor
-- Fixes: 42P17 infinite recursion detected in policy for relation "lenders"

-- Step 1: Helper functions that bypass RLS (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION get_my_user_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT r.name
  FROM users u
  JOIN roles r ON u.role_id = r.id
  WHERE u.auth_id = auth.uid()
  LIMIT 1;
$$;

-- Step 2: Drop ALL existing policies on lenders to start clean
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'lenders' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.lenders', pol.policyname);
  END LOOP;
END;
$$;

-- Step 3: Recreate lenders policies using SECURITY DEFINER helpers (no recursion)
CREATE POLICY "lenders_select" ON public.lenders
  FOR SELECT USING (
    user_id = get_my_user_id()
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "lenders_insert" ON public.lenders
  FOR INSERT WITH CHECK (
    user_id = get_my_user_id()
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "lenders_update" ON public.lenders
  FOR UPDATE USING (
    user_id = get_my_user_id()
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "lenders_delete" ON public.lenders
  FOR DELETE USING (
    get_my_role() IN ('head_manager', 'employee')
  );

-- Step 4: Also fix loans policies if they reference lenders in a way that recurses
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'loans' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.loans', pol.policyname);
  END LOOP;
END;
$$;

CREATE POLICY "loans_select" ON public.loans
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM lenders l
      WHERE l.id = loans.lender_id
        AND l.user_id = get_my_user_id()
    )
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "loans_insert" ON public.loans
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM lenders l
      WHERE l.id = loans.lender_id
        AND l.user_id = get_my_user_id()
    )
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "loans_update" ON public.loans
  FOR UPDATE USING (
    get_my_role() IN ('head_manager', 'employee')
  );

-- Step 5: Fix payments policies
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies WHERE tablename = 'payments' AND schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payments', pol.policyname);
  END LOOP;
END;
$$;

CREATE POLICY "payments_select" ON public.payments
  FOR SELECT USING (
    lender_id IN (SELECT id FROM lenders WHERE user_id = get_my_user_id())
    OR EXISTS (
      SELECT 1 FROM riders r WHERE r.id = payments.collected_by AND r.user_id = get_my_user_id()
    )
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "payments_insert" ON public.payments
  FOR INSERT WITH CHECK (
    lender_id IN (SELECT id FROM lenders WHERE user_id = get_my_user_id())
    OR get_my_role() IN ('head_manager', 'employee')
  );

CREATE POLICY "payments_update" ON public.payments
  FOR UPDATE USING (
    get_my_role() IN ('head_manager', 'employee')
    OR EXISTS (
      SELECT 1 FROM riders r WHERE r.id = payments.collected_by AND r.user_id = get_my_user_id()
    )
  );