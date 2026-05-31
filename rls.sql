-- supabase/rls.sql

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE riders ENABLE ROW LEVEL SECURITY;
ALTER TABLE lenders ENABLE ROW LEVEL SECURITY;
ALTER TABLE lender_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE penalties ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE paymongo_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ci_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ci_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE ci_report_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE gas_estimations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE failed_login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_configs ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- ROLES
-- ============================================================

CREATE POLICY "roles_select_authenticated" ON roles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "roles_hm_all" ON roles
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

-- ============================================================
-- PERMISSIONS
-- ============================================================

CREATE POLICY "permissions_select_authenticated" ON permissions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "permissions_hm_all" ON permissions
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

-- ============================================================
-- ROLE_PERMISSIONS
-- ============================================================

CREATE POLICY "role_permissions_select_authenticated" ON role_permissions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "role_permissions_hm_all" ON role_permissions
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

-- ============================================================
-- USERS
-- ============================================================

CREATE POLICY "users_hm_all" ON users
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "users_emp_select" ON users
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "users_emp_update" ON users
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "users_own_select" ON users
  FOR SELECT TO authenticated
  USING (auth_id = auth.uid());

CREATE POLICY "users_own_update" ON users
  FOR UPDATE TO authenticated
  USING (auth_id = auth.uid())
  WITH CHECK (auth_id = auth.uid());

-- ============================================================
-- USER_ROLES
-- ============================================================

CREATE POLICY "user_roles_hm_all" ON user_roles
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "user_roles_emp_select" ON user_roles
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "user_roles_own_select" ON user_roles
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

-- ============================================================
-- ADDRESSES
-- ============================================================

CREATE POLICY "addresses_hm_all" ON addresses
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "addresses_emp_select" ON addresses
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "addresses_emp_insert" ON addresses
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "addresses_emp_update" ON addresses
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "addresses_own_select" ON addresses
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

CREATE POLICY "addresses_own_insert" ON addresses
  FOR INSERT TO authenticated
  WITH CHECK (user_id = get_user_id());

CREATE POLICY "addresses_own_update" ON addresses
  FOR UPDATE TO authenticated
  USING (user_id = get_user_id())
  WITH CHECK (user_id = get_user_id());

-- ============================================================
-- EMPLOYEES
-- ============================================================

CREATE POLICY "employees_hm_all" ON employees
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "employees_emp_select" ON employees
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "employees_own_select" ON employees
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

-- ============================================================
-- RIDERS
-- ============================================================

CREATE POLICY "riders_hm_all" ON riders
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "riders_emp_select" ON riders
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "riders_emp_update" ON riders
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "riders_own_select" ON riders
  FOR SELECT TO authenticated
  USING (get_user_role() = 'rider' AND user_id = get_user_id());

CREATE POLICY "riders_own_update" ON riders
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'rider' AND user_id = get_user_id())
  WITH CHECK (get_user_role() = 'rider' AND user_id = get_user_id());

-- ============================================================
-- LENDERS
-- ============================================================

CREATE POLICY "lenders_hm_all" ON lenders
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "lenders_emp_select" ON lenders
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "lenders_emp_update" ON lenders
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "lenders_rider_select_assigned" ON lenders
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    id IN (
      SELECT l.lender_id
      FROM ci_assignments ca
      JOIN loans l ON l.id = ca.loan_id
      WHERE ca.rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
      UNION
      SELECT c.lender_id FROM collections c
      WHERE c.rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "lenders_own_select" ON lenders
  FOR SELECT TO authenticated
  USING (get_user_role() = 'lender' AND user_id = get_user_id());

CREATE POLICY "lenders_own_update" ON lenders
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'lender' AND user_id = get_user_id())
  WITH CHECK (get_user_role() = 'lender' AND user_id = get_user_id());

-- ============================================================
-- LENDER_DOCUMENTS
-- ============================================================

CREATE POLICY "lender_docs_hm_all" ON lender_documents
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "lender_docs_emp_select" ON lender_documents
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "lender_docs_emp_update" ON lender_documents
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "lender_docs_rider_select" ON lender_documents
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    lender_id IN (
      SELECT l.lender_id FROM loans l
      JOIN ci_assignments ca ON ca.loan_id = l.id
      WHERE ca.rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "lender_docs_own_select" ON lender_documents
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "lender_docs_own_insert" ON lender_documents
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- LOAN_SETTINGS
-- ============================================================

CREATE POLICY "loan_settings_hm_all" ON loan_settings
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "loan_settings_select_authenticated" ON loan_settings
  FOR SELECT TO authenticated
  USING (get_user_role() IN ('employee', 'rider', 'lender'));

-- ============================================================
-- LOAN_PRODUCTS
-- ============================================================

CREATE POLICY "loan_products_hm_all" ON loan_products
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "loan_products_emp_write" ON loan_products
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loan_products_emp_update" ON loan_products
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loan_products_select_all" ON loan_products
  FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- LOANS
-- ============================================================

CREATE POLICY "loans_hm_all" ON loans
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "loans_emp_select" ON loans
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "loans_emp_insert" ON loans
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loans_emp_update" ON loans
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loans_rider_select_assigned" ON loans
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    id IN (
      SELECT loan_id FROM ci_assignments
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
      UNION
      SELECT loan_id FROM collections
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "loans_lender_select" ON loans
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "loans_lender_apply" ON loans
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- LOAN_SCHEDULES
-- ============================================================

CREATE POLICY "loan_schedules_hm_all" ON loan_schedules
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "loan_schedules_emp_select" ON loan_schedules
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "loan_schedules_emp_update" ON loan_schedules
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loan_schedules_rider_select" ON loan_schedules
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    loan_id IN (
      SELECT loan_id FROM collections
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "loan_schedules_lender_select" ON loan_schedules
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    loan_id IN (
      SELECT id FROM loans
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- LOAN_CHARGES
-- ============================================================

CREATE POLICY "loan_charges_hm_all" ON loan_charges
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "loan_charges_emp_select" ON loan_charges
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "loan_charges_emp_insert" ON loan_charges
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "loan_charges_lender_select" ON loan_charges
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    loan_id IN (
      SELECT id FROM loans
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- PENALTIES
-- ============================================================

CREATE POLICY "penalties_hm_all" ON penalties
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "penalties_emp_select" ON penalties
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "penalties_emp_insert" ON penalties
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "penalties_emp_update" ON penalties
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "penalties_lender_select" ON penalties
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    loan_id IN (
      SELECT id FROM loans
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- PAYMENTS
-- ============================================================

CREATE POLICY "payments_hm_all" ON payments
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "payments_emp_select" ON payments
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "payments_emp_insert" ON payments
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "payments_emp_update" ON payments
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "payments_rider_select" ON payments
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    collected_by = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "payments_rider_insert" ON payments
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    collected_by = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "payments_rider_update" ON payments
  FOR UPDATE TO authenticated
  USING (
    get_user_role() = 'rider' AND
    collected_by = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  )
  WITH CHECK (
    get_user_role() = 'rider' AND
    collected_by = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "payments_lender_select" ON payments
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "payments_lender_insert" ON payments
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- PAYMONGO_TRANSACTIONS
-- ============================================================

CREATE POLICY "paymongo_hm_all" ON paymongo_transactions
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "paymongo_emp_select" ON paymongo_transactions
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "paymongo_lender_select" ON paymongo_transactions
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    payment_id IN (
      SELECT id FROM payments
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- CI_ASSIGNMENTS
-- ============================================================

CREATE POLICY "ci_assignments_hm_all" ON ci_assignments
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "ci_assignments_emp_select" ON ci_assignments
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "ci_assignments_emp_insert" ON ci_assignments
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "ci_assignments_emp_update" ON ci_assignments
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "ci_assignments_rider_select" ON ci_assignments
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "ci_assignments_rider_update" ON ci_assignments
  FOR UPDATE TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  )
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- CI_REPORTS
-- ============================================================

CREATE POLICY "ci_reports_hm_all" ON ci_reports
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "ci_reports_emp_select" ON ci_reports
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "ci_reports_emp_update" ON ci_reports
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "ci_reports_rider_select" ON ci_reports
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "ci_reports_rider_insert" ON ci_reports
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "ci_reports_rider_update" ON ci_reports
  FOR UPDATE TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  )
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- CI_REPORT_PHOTOS
-- ============================================================

CREATE POLICY "ci_report_photos_hm_all" ON ci_report_photos
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "ci_report_photos_emp_select" ON ci_report_photos
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "ci_report_photos_rider_select" ON ci_report_photos
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    ci_report_id IN (
      SELECT id FROM ci_reports
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "ci_report_photos_rider_insert" ON ci_report_photos
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    ci_report_id IN (
      SELECT id FROM ci_reports
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- COLLECTIONS
-- ============================================================

CREATE POLICY "collections_hm_all" ON collections
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "collections_emp_select" ON collections
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "collections_emp_insert" ON collections
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "collections_emp_update" ON collections
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "collections_rider_select" ON collections
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "collections_rider_update" ON collections
  FOR UPDATE TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  )
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "collections_lender_select" ON collections
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- COLLECTION_LOGS
-- ============================================================

CREATE POLICY "collection_logs_hm_all" ON collection_logs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "collection_logs_emp_select" ON collection_logs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "collection_logs_rider_select" ON collection_logs
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    collection_id IN (
      SELECT id FROM collections
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "collection_logs_rider_insert" ON collection_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    collection_id IN (
      SELECT id FROM collections
      WHERE rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "collection_logs_lender_select" ON collection_logs
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    collection_id IN (
      SELECT id FROM collections
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- ROUTE_LOGS
-- ============================================================

CREATE POLICY "route_logs_hm_all" ON route_logs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "route_logs_emp_select" ON route_logs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "route_logs_rider_select" ON route_logs
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "route_logs_rider_insert" ON route_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- GAS_ESTIMATIONS
-- ============================================================

CREATE POLICY "gas_estimations_hm_all" ON gas_estimations
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "gas_estimations_emp_select" ON gas_estimations
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "gas_estimations_rider_select" ON gas_estimations
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

CREATE POLICY "gas_estimations_rider_insert" ON gas_estimations
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'rider' AND
    rider_id = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
  );

-- ============================================================
-- PAYMENT_RECEIPTS
-- ============================================================

CREATE POLICY "payment_receipts_hm_all" ON payment_receipts
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "payment_receipts_emp_select" ON payment_receipts
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "payment_receipts_emp_insert" ON payment_receipts
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "payment_receipts_rider_select" ON payment_receipts
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'rider' AND
    payment_id IN (
      SELECT id FROM payments
      WHERE collected_by = (SELECT id FROM riders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

CREATE POLICY "payment_receipts_lender_select" ON payment_receipts
  FOR SELECT TO authenticated
  USING (
    get_user_role() = 'lender' AND
    payment_id IN (
      SELECT id FROM payments
      WHERE lender_id = (SELECT id FROM lenders WHERE user_id = get_user_id() LIMIT 1)
    )
  );

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

CREATE POLICY "notifications_hm_all" ON notifications
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "notifications_emp_insert" ON notifications
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "notifications_own_select" ON notifications
  FOR SELECT TO authenticated
  USING (recipient_id = get_user_id());

CREATE POLICY "notifications_own_update" ON notifications
  FOR UPDATE TO authenticated
  USING (recipient_id = get_user_id())
  WITH CHECK (recipient_id = get_user_id());

-- ============================================================
-- SESSIONS
-- ============================================================

CREATE POLICY "sessions_hm_all" ON sessions
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "sessions_own_select" ON sessions
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

CREATE POLICY "sessions_own_insert" ON sessions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = get_user_id());

CREATE POLICY "sessions_own_update" ON sessions
  FOR UPDATE TO authenticated
  USING (user_id = get_user_id())
  WITH CHECK (user_id = get_user_id());

CREATE POLICY "sessions_own_delete" ON sessions
  FOR DELETE TO authenticated
  USING (user_id = get_user_id());

-- ============================================================
-- DEVICES
-- ============================================================

CREATE POLICY "devices_hm_all" ON devices
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "devices_own_select" ON devices
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

CREATE POLICY "devices_own_insert" ON devices
  FOR INSERT TO authenticated
  WITH CHECK (user_id = get_user_id());

CREATE POLICY "devices_own_update" ON devices
  FOR UPDATE TO authenticated
  USING (user_id = get_user_id())
  WITH CHECK (user_id = get_user_id());

CREATE POLICY "devices_own_delete" ON devices
  FOR DELETE TO authenticated
  USING (user_id = get_user_id());

-- ============================================================
-- FAILED_LOGIN_ATTEMPTS
-- ============================================================

CREATE POLICY "failed_login_hm_all" ON failed_login_attempts
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "failed_login_emp_select" ON failed_login_attempts
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "failed_login_insert_authenticated" ON failed_login_attempts
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- ============================================================
-- PASSWORD_RESET_LOGS
-- ============================================================

CREATE POLICY "pwd_reset_hm_all" ON password_reset_logs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "pwd_reset_emp_select" ON password_reset_logs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "pwd_reset_emp_insert" ON password_reset_logs
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "pwd_reset_own_select" ON password_reset_logs
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

-- ============================================================
-- AUDIT_LOGS
-- ============================================================

CREATE POLICY "audit_logs_hm_all" ON audit_logs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "audit_logs_emp_select" ON audit_logs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "audit_logs_own_select" ON audit_logs
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

CREATE POLICY "audit_logs_insert_authenticated" ON audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- ============================================================
-- ACTIVITY_LOGS
-- ============================================================

CREATE POLICY "activity_logs_hm_all" ON activity_logs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "activity_logs_emp_select" ON activity_logs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "activity_logs_own_select" ON activity_logs
  FOR SELECT TO authenticated
  USING (user_id = get_user_id());

CREATE POLICY "activity_logs_own_insert" ON activity_logs
  FOR INSERT TO authenticated
  WITH CHECK (user_id = get_user_id());

-- ============================================================
-- FRAUD_FLAGS
-- ============================================================

CREATE POLICY "fraud_flags_hm_all" ON fraud_flags
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "fraud_flags_emp_select" ON fraud_flags
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "fraud_flags_emp_insert" ON fraud_flags
  FOR INSERT TO authenticated
  WITH CHECK (get_user_role() = 'employee');

CREATE POLICY "fraud_flags_emp_update" ON fraud_flags
  FOR UPDATE TO authenticated
  USING (get_user_role() = 'employee')
  WITH CHECK (get_user_role() = 'employee');

-- ============================================================
-- SYSTEM_CONFIGS
-- ============================================================

CREATE POLICY "system_configs_hm_all" ON system_configs
  FOR ALL TO authenticated
  USING (get_user_role() = 'head_manager')
  WITH CHECK (get_user_role() = 'head_manager');

CREATE POLICY "system_configs_emp_select" ON system_configs
  FOR SELECT TO authenticated
  USING (get_user_role() = 'employee');

CREATE POLICY "system_configs_select_all" ON system_configs
  FOR SELECT TO authenticated
  USING (
    get_user_role() IN ('rider', 'lender') AND
    config_key IN ('company_name', 'company_address', 'company_phone', 'company_email', 'app_version')
  );